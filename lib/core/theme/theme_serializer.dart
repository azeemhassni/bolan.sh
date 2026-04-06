import 'dart:ui';

import 'package:toml/toml.dart';

import 'bolan_theme.dart';
import 'default_dark.dart';
import 'themes/default_light.dart';

/// Converts between [BolonTheme] and TOML format.
class ThemeSerializer {
  const ThemeSerializer._();

  /// Parses a TOML string into a [BolonTheme].
  /// Missing fields are filled from the appropriate default theme.
  static BolonTheme fromToml(String tomlString) {
    final doc = TomlDocument.parse(tomlString);
    final map = doc.toMap();

    final brightness = map['brightness'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final base = brightness == Brightness.light
        ? bolonDefaultLight
        : bolonDefaultDark;

    final window = map['window'] as Map<String, dynamic>? ?? {};
    final blocks = map['blocks'] as Map<String, dynamic>? ?? {};
    final status = map['status'] as Map<String, dynamic>? ?? {};
    final terminal = map['terminal'] as Map<String, dynamic>? ?? {};
    final ansi = map['ansi'] as Map<String, dynamic>? ?? {};

    return BolonTheme(
      name: _str(map, 'name', base.name),
      displayName: _str(map, 'display_name', base.displayName),
      brightness: brightness,
      isBuiltIn: false,

      background: _color(window, 'background', base.background),
      tabBarBackground: _color(window, 'tab_bar_background', base.tabBarBackground),
      statusBarBackground: _color(window, 'status_bar_background', base.statusBarBackground),
      promptBackground: _color(window, 'prompt_background', base.promptBackground),
      tabAccent: _colorOrNull(window, 'tab_accent'),

      blockBackground: _color(blocks, 'background', base.blockBackground),
      blockBorder: _color(blocks, 'border', base.blockBorder),
      blockHeaderFg: _color(blocks, 'header_fg', base.blockHeaderFg),
      exitSuccessFg: _color(blocks, 'exit_success_fg', base.exitSuccessFg),
      exitFailureFg: _color(blocks, 'exit_failure_fg', base.exitFailureFg),

      statusChipBg: _color(status, 'chip_bg', base.statusChipBg),
      statusCwdFg: _color(status, 'cwd_fg', base.statusCwdFg),
      statusGitFg: _color(status, 'git_fg', base.statusGitFg),
      statusShellFg: _color(status, 'shell_fg', base.statusShellFg),
      dimForeground: _color(status, 'dim_foreground', base.dimForeground),

      foreground: _color(terminal, 'foreground', base.foreground),
      cursor: _color(terminal, 'cursor', base.cursor),
      selectionColor: _color(terminal, 'selection', base.selectionColor),
      searchHitBackground: _color(terminal, 'search_hit_bg', base.searchHitBackground),
      searchHitBackgroundCurrent: _color(terminal, 'search_hit_bg_current', base.searchHitBackgroundCurrent),
      searchHitForeground: _color(terminal, 'search_hit_fg', base.searchHitForeground),

      ansiBlack: _color(ansi, 'black', base.ansiBlack),
      ansiRed: _color(ansi, 'red', base.ansiRed),
      ansiGreen: _color(ansi, 'green', base.ansiGreen),
      ansiYellow: _color(ansi, 'yellow', base.ansiYellow),
      ansiBlue: _color(ansi, 'blue', base.ansiBlue),
      ansiMagenta: _color(ansi, 'magenta', base.ansiMagenta),
      ansiCyan: _color(ansi, 'cyan', base.ansiCyan),
      ansiWhite: _color(ansi, 'white', base.ansiWhite),
      ansiBrightBlack: _color(ansi, 'bright_black', base.ansiBrightBlack),
      ansiBrightRed: _color(ansi, 'bright_red', base.ansiBrightRed),
      ansiBrightGreen: _color(ansi, 'bright_green', base.ansiBrightGreen),
      ansiBrightYellow: _color(ansi, 'bright_yellow', base.ansiBrightYellow),
      ansiBrightBlue: _color(ansi, 'bright_blue', base.ansiBrightBlue),
      ansiBrightMagenta: _color(ansi, 'bright_magenta', base.ansiBrightMagenta),
      ansiBrightCyan: _color(ansi, 'bright_cyan', base.ansiBrightCyan),
      ansiBrightWhite: _color(ansi, 'bright_white', base.ansiBrightWhite),
    );
  }

  /// Serializes a [BolonTheme] to TOML.
  static String toToml(BolonTheme t) {
    final sb = StringBuffer();
    sb.writeln('name = "${t.name}"');
    sb.writeln('display_name = "${t.displayName}"');
    sb.writeln('brightness = "${t.brightness == Brightness.light ? 'light' : 'dark'}"');
    sb.writeln();
    sb.writeln('[window]');
    sb.writeln('background = "${_hex(t.background)}"');
    sb.writeln('tab_bar_background = "${_hex(t.tabBarBackground)}"');
    sb.writeln('status_bar_background = "${_hex(t.statusBarBackground)}"');
    sb.writeln('prompt_background = "${_hex(t.promptBackground)}"');
    if (t.tabAccent != null) {
      sb.writeln('tab_accent = "${_hex(t.tabAccent!)}"');
    }
    sb.writeln();
    sb.writeln('[blocks]');
    sb.writeln('background = "${_hex(t.blockBackground)}"');
    sb.writeln('border = "${_hex(t.blockBorder)}"');
    sb.writeln('header_fg = "${_hex(t.blockHeaderFg)}"');
    sb.writeln('exit_success_fg = "${_hex(t.exitSuccessFg)}"');
    sb.writeln('exit_failure_fg = "${_hex(t.exitFailureFg)}"');
    sb.writeln();
    sb.writeln('[status]');
    sb.writeln('chip_bg = "${_hex(t.statusChipBg)}"');
    sb.writeln('cwd_fg = "${_hex(t.statusCwdFg)}"');
    sb.writeln('git_fg = "${_hex(t.statusGitFg)}"');
    sb.writeln('shell_fg = "${_hex(t.statusShellFg)}"');
    sb.writeln('dim_foreground = "${_hex(t.dimForeground)}"');
    sb.writeln();
    sb.writeln('[terminal]');
    sb.writeln('foreground = "${_hex(t.foreground)}"');
    sb.writeln('cursor = "${_hex(t.cursor)}"');
    sb.writeln('selection = "${_hex(t.selectionColor)}"');
    sb.writeln('search_hit_bg = "${_hex(t.searchHitBackground)}"');
    sb.writeln('search_hit_bg_current = "${_hex(t.searchHitBackgroundCurrent)}"');
    sb.writeln('search_hit_fg = "${_hex(t.searchHitForeground)}"');
    sb.writeln();
    sb.writeln('[ansi]');
    sb.writeln('black = "${_hex(t.ansiBlack)}"');
    sb.writeln('red = "${_hex(t.ansiRed)}"');
    sb.writeln('green = "${_hex(t.ansiGreen)}"');
    sb.writeln('yellow = "${_hex(t.ansiYellow)}"');
    sb.writeln('blue = "${_hex(t.ansiBlue)}"');
    sb.writeln('magenta = "${_hex(t.ansiMagenta)}"');
    sb.writeln('cyan = "${_hex(t.ansiCyan)}"');
    sb.writeln('white = "${_hex(t.ansiWhite)}"');
    sb.writeln('bright_black = "${_hex(t.ansiBrightBlack)}"');
    sb.writeln('bright_red = "${_hex(t.ansiBrightRed)}"');
    sb.writeln('bright_green = "${_hex(t.ansiBrightGreen)}"');
    sb.writeln('bright_yellow = "${_hex(t.ansiBrightYellow)}"');
    sb.writeln('bright_blue = "${_hex(t.ansiBrightBlue)}"');
    sb.writeln('bright_magenta = "${_hex(t.ansiBrightMagenta)}"');
    sb.writeln('bright_cyan = "${_hex(t.ansiBrightCyan)}"');
    sb.writeln('bright_white = "${_hex(t.ansiBrightWhite)}"');
    return sb.toString();
  }

  static String _hex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static Color _color(Map<String, dynamic> map, String key, Color fallback) {
    final value = map[key];
    if (value is! String) return fallback;
    return _parseHex(value) ?? fallback;
  }

  static Color? _colorOrNull(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) return null;
    return _parseHex(value);
  }

  static Color? _parseHex(String hex) {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }

  static String _str(Map<String, dynamic> map, String key, String fallback) {
    final value = map[key];
    return value is String ? value : fallback;
  }
}
