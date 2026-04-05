import 'dart:io';

/// Discovers monospace/fixed-width fonts installed on the system.
class SystemFonts {
  SystemFonts._();

  static List<String>? _cache;

  /// Returns a sorted list of monospace font family names.
  static Future<List<String>> getMonospaceFonts() async {
    if (_cache != null) return _cache!;

    List<String> fonts;
    if (Platform.isMacOS) {
      fonts = await _macOSMonospaceFonts();
    } else if (Platform.isLinux) {
      fonts = await _linuxMonospaceFonts();
    } else {
      fonts = _fallbackFonts;
    }

    // Always include bundled fonts at the top
    final bundled = ['JetBrains Mono', 'Operator Mono'];
    final allFonts = <String>{...bundled, ...fonts};
    final sorted = allFonts.toList()
      ..sort((a, b) {
        // Bundled fonts first
        final aBundle = bundled.contains(a) ? 0 : 1;
        final bBundle = bundled.contains(b) ? 0 : 1;
        if (aBundle != bBundle) return aBundle.compareTo(bBundle);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    _cache = sorted;
    return sorted;
  }

  /// Uses `system_profiler` on macOS to list monospace fonts.
  static Future<List<String>> _macOSMonospaceFonts() async {
    try {
      // Use CoreText via python to get monospace fonts
      final result = await Process.run('python3', [
        '-c',
        '''
import CoreText, CoreFoundation
desc = CoreText.CTFontDescriptorCreateWithAttributes(
    CoreFoundation.CFDictionaryCreate(None,
        [CoreText.kCTFontMonoSpaceTrait],
        [CoreFoundation.kCFBooleanTrue], 1,
        CoreFoundation.kCFTypeDictionaryKeyCallBacks,
        CoreFoundation.kCFTypeDictionaryValueCallBacks))
descs = CoreText.CTFontDescriptorCreateMatchingFontDescriptors(
    CoreText.CTFontDescriptorCreateWithAttributes(
        {CoreText.kCTFontTraitsAttribute: {CoreText.kCTFontSymbolicTrait: CoreText.kCTFontMonoSpaceTrait}}),
    None)
if descs:
    seen = set()
    for i in range(CoreFoundation.CFArrayGetCount(descs)):
        d = CoreFoundation.CFArrayGetValueAtIndex(descs, i)
        name = CoreText.CTFontDescriptorCopyAttribute(d, CoreText.kCTFontFamilyNameAttribute)
        if name and name not in seen:
            seen.add(name)
            print(name)
''',
      ]).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        final fonts = (result.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (fonts.isNotEmpty) return fonts;
      }
    } on Exception {
      // Fall through to fc-list
    }

    // Fallback: use fc-list if available
    return _fcListMonospace();
  }

  /// Uses `fc-list` on Linux to list monospace fonts.
  static Future<List<String>> _linuxMonospaceFonts() async {
    return _fcListMonospace();
  }

  static Future<List<String>> _fcListMonospace() async {
    try {
      final result = await Process.run('fc-list', [
        ':spacing=mono',
        'family',
      ]).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        final fonts = <String>{};
        for (final line in (result.stdout as String).split('\n')) {
          final name = line.trim().split(',').first.trim();
          if (name.isNotEmpty) fonts.add(name);
        }
        return fonts.toList();
      }
    } on Exception {
      // Fall through to fallbacks
    }
    return _fallbackFonts;
  }

  static const _fallbackFonts = [
    'JetBrains Mono',
    'Operator Mono',
    'Fira Code',
    'SF Mono',
    'Menlo',
    'Monaco',
    'Consolas',
    'Courier New',
    'Liberation Mono',
    'Source Code Pro',
    'IBM Plex Mono',
    'Inconsolata',
    'Hack',
    'Ubuntu Mono',
  ];
}
