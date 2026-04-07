import 'dart:io';

/// Host system memory information.
///
/// Used to warn the user before downloading or loading a local model
/// that may be too large for their machine.
class SystemMemory {
  SystemMemory._();

  /// Total physical RAM in bytes, or null if detection fails.
  static Future<int?> totalBytes() async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('sysctl', ['-n', 'hw.memsize']);
        return int.tryParse((r.stdout as String).trim());
      }
      if (Platform.isLinux) {
        final content = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(content);
        if (match != null) return int.parse(match.group(1)!) * 1024;
      }
      if (Platform.isWindows) {
        final r = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
        ]);
        return int.tryParse((r.stdout as String).trim());
      }
    } on Exception {
      // Fall through to null
    }
    return null;
  }

  /// Currently available (free + reclaimable) RAM in bytes, or null
  /// if detection fails. This approximates Linux's `MemAvailable`.
  static Future<int?> availableBytes() async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('vm_stat', const []);
        return _parseMacVmStat(r.stdout as String);
      }
      if (Platform.isLinux) {
        final content = await File('/proc/meminfo').readAsString();
        final match =
            RegExp(r'MemAvailable:\s+(\d+)\s+kB').firstMatch(content);
        if (match != null) return int.parse(match.group(1)!) * 1024;
      }
      if (Platform.isWindows) {
        final r = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory',
        ]);
        final kb = int.tryParse((r.stdout as String).trim());
        return kb != null ? kb * 1024 : null;
      }
    } on Exception {
      // Fall through to null
    }
    return null;
  }

  static int? _parseMacVmStat(String stdout) {
    final pageSizeMatch =
        RegExp(r'page size of (\d+) bytes').firstMatch(stdout);
    if (pageSizeMatch == null) return null;
    final pageSize = int.parse(pageSizeMatch.group(1)!);

    int pagesFor(String key) {
      final m = RegExp('$key:\\s+(\\d+)').firstMatch(stdout);
      return m == null ? 0 : int.parse(m.group(1)!);
    }

    // free + inactive + speculative + purgeable approximates what the
    // OS would hand out before resorting to swap or eviction pressure.
    final free = pagesFor('Pages free');
    final inactive = pagesFor('Pages inactive');
    final speculative = pagesFor('Pages speculative');
    final purgeable = pagesFor('Pages purgeable');
    return (free + inactive + speculative + purgeable) * pageSize;
  }

  /// Pretty-prints a byte count as GB / MB.
  static String format(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
