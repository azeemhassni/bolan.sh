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
    final bundled = ['JetBrains Mono'];
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

  /// Uses CoreText via Swift to list monospace fonts on macOS.
  ///
  /// Swift is guaranteed on macOS (ships with Xcode CLI tools).
  static Future<List<String>> _macOSMonospaceFonts() async {
    try {
      final result = await Process.run('swift', [
        '-e',
        '''
import CoreText
let attrs: [CFString: Any] = [
  kCTFontTraitsAttribute: [kCTFontSymbolicTrait: CTFontSymbolicTraits.traitMonoSpace.rawValue]
]
let desc = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
guard let matches = CTFontDescriptorCreateMatchingFontDescriptors(desc, nil) as? [CTFontDescriptor] else { exit(0) }
var seen = Set<String>()
for d in matches {
  guard let name = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String else { continue }
  if name.hasPrefix(".") { continue }
  if name.lowercased().contains("emoji") { continue }
  if seen.insert(name).inserted { print(name) }
}
''',
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        final fonts = (result.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (fonts.isNotEmpty) return fonts;
      }
    } on Exception {
      // Fall through to fallback list
    }

    return _fallbackFonts;
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
