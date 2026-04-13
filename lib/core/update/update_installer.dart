import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Handles verification, installation, and restart for updates.
///
/// macOS: mount DMG → verify codesign + team ID → atomic replace .app → restart
/// Linux: verify SHA256 → extract tar.gz → atomic replace bundle → restart
class UpdateInstaller {
  static const _expectedTeamId = 'SM26HBBKRL';
  static const _mountPoint = '/tmp/bolan-update';

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  /// Verifies the downloaded artifact is authentic.
  ///
  /// macOS: mounts the DMG and verifies codesign + team identity.
  /// Linux: downloads the checksums file and compares SHA256.
  static Future<bool> verify({
    required String filePath,
    String? checksumUrl,
  }) async {
    if (Platform.isMacOS) {
      return _verifyMacOS(filePath);
    } else {
      return _verifyLinux(filePath, checksumUrl);
    }
  }

  /// Mount DMG, verify codesign + team ID, unmount.
  static Future<bool> _verifyMacOS(String dmgPath) async {
    try {
      // Clean up stale mount
      await Process.run('hdiutil', ['detach', _mountPoint, '-force']);

      // Mount the DMG
      final mount = await Process.run('hdiutil', [
        'attach', dmgPath,
        '-nobrowse', '-noautoopen', '-mountpoint', _mountPoint,
      ]);
      if (mount.exitCode != 0) {
        debugPrint('DMG mount failed: ${mount.stderr}');
        return false;
      }

      const appPath = '$_mountPoint/Bolan.app';
      if (!Directory(appPath).existsSync()) {
        debugPrint('Bolan.app not found in mounted DMG');
        await _unmount();
        return false;
      }

      // Verify code signature
      final verify = await Process.run('codesign', [
        '--verify', '--deep', '--strict', '--verbose=0', appPath,
      ]);
      if (verify.exitCode != 0) {
        debugPrint('codesign verify failed: ${verify.stderr}');
        await _unmount();
        return false;
      }

      // Verify team identity
      final info = await Process.run('codesign', ['-dvv', appPath]);
      final stderr = info.stderr as String;
      final teamMatch =
          RegExp(r'TeamIdentifier=(\S+)').firstMatch(stderr);
      if (teamMatch == null || teamMatch.group(1) != _expectedTeamId) {
        debugPrint(
            'Team ID mismatch: expected $_expectedTeamId, '
            'got ${teamMatch?.group(1)}');
        await _unmount();
        return false;
      }

      // Leave mounted — install() will copy from here and unmount
      return true;
    } on Exception catch (e) {
      debugPrint('macOS verification error: $e');
      await _unmount();
      return false;
    }
  }

  /// Download checksums file and verify SHA256 of the tar.gz.
  static Future<bool> _verifyLinux(
      String tarPath, String? checksumUrl) async {
    if (checksumUrl == null) {
      debugPrint('No checksum URL — skipping verification');
      return false;
    }

    try {
      // Download the checksums file
      final dio = Dio();
      final response = await dio.get<String>(checksumUrl);
      final checksumContent = response.data ?? '';

      // Find the matching line: "<hash>  <filename>"
      final fileName = tarPath.split('/').last;
      String? expectedHash;
      for (final line in checksumContent.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts.last == fileName) {
          expectedHash = parts.first.toLowerCase();
          break;
        }
      }

      if (expectedHash == null) {
        debugPrint('No checksum found for $fileName');
        return false;
      }

      // Compute SHA256 of the downloaded file
      final file = File(tarPath);
      final digest = await sha256.bind(file.openRead()).first;
      final actualHash = digest.toString();

      if (actualHash != expectedHash) {
        debugPrint('SHA256 mismatch: expected $expectedHash, got $actualHash');
        return false;
      }

      return true;
    } on Exception catch (e) {
      debugPrint('Linux verification error: $e');
      return false;
    }
  }

  static Future<void> _unmount() async {
    await Process.run('hdiutil', ['detach', _mountPoint, '-force']);
  }

  // ---------------------------------------------------------------------------
  // Installation
  // ---------------------------------------------------------------------------

  /// Installs the verified update.
  ///
  /// macOS: copies .app from mounted DMG, atomic replace with .bak rollback.
  /// Linux: extracts tar.gz, atomic replace bundle dir with .bak rollback.
  static Future<void> install({required String filePath}) async {
    if (Platform.isMacOS) {
      await _installMacOS(filePath);
    } else {
      await _installLinux(filePath);
    }
  }

  static Future<void> _installMacOS(String dmgPath) async {
    // Resolve current .app location from the running executable
    // e.g. /Applications/Bolan.app/Contents/MacOS/Bolan
    final exe = Platform.resolvedExecutable;
    final appDir = exe.replaceAll('/Contents/MacOS/Bolan', '');
    final parentDir = File(appDir).parent.path;
    final appName = appDir.split('/').last; // "Bolan.app"
    final backupPath = '$parentDir/$appName.bak';

    // The DMG should already be mounted from verify()
    const sourceApp = '$_mountPoint/Bolan.app';
    if (!Directory(sourceApp).existsSync()) {
      throw Exception('Source Bolan.app not found at $sourceApp');
    }

    try {
      // Atomic replace: rename current → .bak
      final backup = Directory(backupPath);
      if (backup.existsSync()) {
        backup.deleteSync(recursive: true);
      }
      Directory(appDir).renameSync(backupPath);

      // Copy new .app in
      final cp = await Process.run('cp', ['-R', sourceApp, appDir]);
      if (cp.exitCode != 0) {
        // Rollback
        Directory(backupPath).renameSync(appDir);
        throw Exception('cp failed: ${cp.stderr}');
      }

      // Success — clean up
      Directory(backupPath).deleteSync(recursive: true);
      await _unmount();

      // Remove the downloaded DMG
      final dmg = File(dmgPath);
      if (dmg.existsSync()) dmg.deleteSync();
    } on FileSystemException catch (e) {
      // Try to rollback
      if (Directory(backupPath).existsSync() &&
          !Directory(appDir).existsSync()) {
        Directory(backupPath).renameSync(appDir);
      }
      await _unmount();

      if (e.osError?.errorCode == 1 || e.osError?.errorCode == 13) {
        throw Exception(
          'Bolan does not have permission to update itself in this '
          'location. Please download the update manually from '
          'https://github.com/azeemhassni/bolan.sh/releases',
        );
      }
      rethrow;
    }
  }

  static Future<void> _installLinux(String tarPath) async {
    // Resolve current bundle location
    // e.g. /opt/bolan/bundle/Bolan → bundle dir is parent
    final exe = Platform.resolvedExecutable;
    final bundleDir = File(exe).parent.path;
    final parentDir = Directory(bundleDir).parent.path;
    final bundleName = bundleDir.split('/').last;
    final backupPath = '$parentDir/$bundleName.bak';

    // Extract to temp directory
    final staging = await Directory.systemTemp.createTemp('bolan-update-');
    try {
      final extract = await Process.run('tar', [
        '-xzf', tarPath, '-C', staging.path,
      ]);
      if (extract.exitCode != 0) {
        throw Exception('tar extract failed: ${extract.stderr}');
      }

      // Find the extracted bundle directory
      final extracted = Directory(staging.path)
          .listSync()
          .whereType<Directory>()
          .firstWhere(
            (d) => d.path.endsWith('bundle') ||
                d.path.endsWith('bolan'),
            orElse: () => throw Exception(
                'Could not find bundle directory in archive'),
          );

      // Atomic replace
      final backup = Directory(backupPath);
      if (backup.existsSync()) {
        backup.deleteSync(recursive: true);
      }
      Directory(bundleDir).renameSync(backupPath);

      try {
        extracted.renameSync(bundleDir);
      } on FileSystemException {
        // Cross-device rename — fall back to cp
        final cp =
            await Process.run('cp', ['-R', extracted.path, bundleDir]);
        if (cp.exitCode != 0) {
          Directory(backupPath).renameSync(bundleDir);
          throw Exception('cp failed: ${cp.stderr}');
        }
      }

      // Make executable
      await Process.run('chmod', ['+x', '$bundleDir/Bolan']);

      // Success — clean up
      Directory(backupPath).deleteSync(recursive: true);
      staging.deleteSync(recursive: true);
      File(tarPath).deleteSync();
    } on FileSystemException catch (e) {
      // Try to rollback
      if (Directory(backupPath).existsSync() &&
          !Directory(bundleDir).existsSync()) {
        Directory(backupPath).renameSync(bundleDir);
      }
      staging.deleteSync(recursive: true);

      if (e.osError?.errorCode == 1 || e.osError?.errorCode == 13) {
        throw Exception(
          'Bolan does not have permission to update itself in this '
          'location. Please download the update manually from '
          'https://github.com/azeemhassni/bolan.sh/releases',
        );
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Restart
  // ---------------------------------------------------------------------------

  /// Launches the new binary and exits the current process.
  static Future<void> restart() async {
    if (Platform.isMacOS) {
      final exe = Platform.resolvedExecutable;
      final appPath = exe.replaceAll('/Contents/MacOS/Bolan', '');
      await Process.start('open', ['-n', appPath],
          mode: ProcessStartMode.detached);
    } else {
      await Process.start(Platform.resolvedExecutable, [],
          mode: ProcessStartMode.detached);
    }

    // Give the new process a moment to spawn
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(0);
  }
}
