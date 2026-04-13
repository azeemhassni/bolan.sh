import 'dart:io';

import 'package:dio/dio.dart';

import '../app_version.dart';
import '../config/config_loader.dart';
import 'version.dart';

/// Information about an available update.
class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String? checksumUrl;

  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    this.checksumUrl,
  });
}

/// Checks GitHub Releases for a newer version.
class UpdateChecker {
  static const _repoApi =
      'https://api.github.com/repos/azeemhassni/bolan.sh/releases/latest';

  final Dio _dio;

  UpdateChecker({Dio? dio}) : _dio = dio ?? Dio();

  /// Returns [UpdateInfo] if a newer version is available, `null` otherwise.
  ///
  /// When [force] is false, respects the 24-hour throttle and skipped version
  /// stored in [config]. When true, bypasses both.
  Future<UpdateInfo?> check(ConfigLoader configLoader,
      {bool force = false}) async {
    final config = configLoader.config;

    if (!force) {
      if (!config.update.autoCheck) return null;

      // 24-hour throttle
      if (config.update.lastCheckTime.isNotEmpty) {
        final last = DateTime.tryParse(config.update.lastCheckTime);
        if (last != null &&
            DateTime.now().difference(last) < const Duration(hours: 24)) {
          return null;
        }
      }
    }

    final response = await _dio.get<Map<String, dynamic>>(
      _repoApi,
      options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
    );
    final data = response.data!;

    // Persist check timestamp
    await configLoader.save(config.copyWith(
      update: config.update.copyWith(
        lastCheckTime: DateTime.now().toUtc().toIso8601String(),
      ),
    ));

    final tagName = data['tag_name'] as String? ?? '';
    if (!Version.isValid(tagName)) return null;

    final latest = Version.parse(tagName);
    final current = Version.parse(appVersion);
    if (latest <= current) return null;

    // Skip this version?
    if (!force && config.update.skippedVersion.isNotEmpty) {
      if (Version.isValid(config.update.skippedVersion) &&
          Version.parse(config.update.skippedVersion) == latest) {
        return null;
      }
    }

    // Find the right asset for this platform
    final assets = data['assets'] as List<dynamic>? ?? [];
    final downloadUrl = _findAssetUrl(assets);
    if (downloadUrl == null) return null;

    final checksumUrl = _findChecksumUrl(assets);

    return UpdateInfo(
      version: latest.toString(),
      releaseNotes: data['body'] as String? ?? '',
      downloadUrl: downloadUrl,
      checksumUrl: checksumUrl,
    );
  }

  String? _findAssetUrl(List<dynamic> assets) {
    final pattern = Platform.isMacOS
        ? RegExp(r'Bolan-v.*-macos\.dmg$')
        : RegExp(r'bolan-linux-' + _linuxArch + r'-v.*\.tar\.gz$');

    for (final asset in assets) {
      final a = asset as Map<String, dynamic>;
      final name = a['name'] as String? ?? '';
      if (pattern.hasMatch(name)) {
        return a['browser_download_url'] as String?;
      }
    }
    return null;
  }

  String? _findChecksumUrl(List<dynamic> assets) {
    for (final asset in assets) {
      final a = asset as Map<String, dynamic>;
      final name = a['name'] as String? ?? '';
      if (name.startsWith('checksums-') && name.endsWith('.sha256')) {
        return a['browser_download_url'] as String?;
      }
    }
    return null;
  }

  static String get _linuxArch {
    // Dart's Platform doesn't expose arch directly; use uname -m
    // This is only called on Linux so the fallback is safe.
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = (result.stdout as String).trim();
      if (arch == 'aarch64' || arch == 'arm64') return 'arm64';
    } on ProcessException {
      // ignore
    }
    return 'x64';
  }
}
