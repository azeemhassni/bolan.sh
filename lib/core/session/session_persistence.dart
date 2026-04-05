import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Persists and restores tab/pane layout across app restarts.
///
/// Saves to `~/.config/bolan/session_state.json`. Only stores the pane tree
/// structure and CWD per leaf — terminal scrollback and history are not
/// persisted here.
class SessionPersistence {
  SessionPersistence._();

  static File _stateFile() {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/bolan/session_state.json');
  }

  /// Saves the current layout to disk.
  static Future<void> save(SessionLayout layout) async {
    final file = _stateFile();
    await file.parent.create(recursive: true);
    final json = jsonEncode(layout.toJson());
    await file.writeAsString(json);
  }

  /// Loads a previously saved layout, or null if none exists.
  static SessionLayout? load() {
    final file = _stateFile();
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return SessionLayout.fromJson(json);
    } on Exception {
      return null;
    }
  }
}

/// Serializable snapshot of the tab/pane layout.
class SessionLayout {
  final List<TabLayout> tabs;
  final int activeTabIndex;

  const SessionLayout({
    required this.tabs,
    this.activeTabIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'tabs': tabs.map((t) => t.toJson()).toList(),
        'activeTabIndex': activeTabIndex,
      };

  factory SessionLayout.fromJson(Map<String, dynamic> json) {
    final tabs = (json['tabs'] as List<dynamic>?)
            ?.map((t) => TabLayout.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];
    return SessionLayout(
      tabs: tabs,
      activeTabIndex: json['activeTabIndex'] as int? ?? 0,
    );
  }
}

/// Layout of a single tab's pane tree.
class TabLayout {
  final PaneLayout rootPane;
  final String? focusedPaneId;

  const TabLayout({required this.rootPane, this.focusedPaneId});

  Map<String, dynamic> toJson() => {
        'rootPane': rootPane.toJson(),
        'focusedPaneId': focusedPaneId,
      };

  factory TabLayout.fromJson(Map<String, dynamic> json) {
    return TabLayout(
      rootPane:
          PaneLayout.fromJson(json['rootPane'] as Map<String, dynamic>),
      focusedPaneId: json['focusedPaneId'] as String?,
    );
  }
}

/// Serializable pane node — either a leaf with CWD or a split with children.
sealed class PaneLayout {
  const PaneLayout();

  Map<String, dynamic> toJson();

  factory PaneLayout.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type == 'leaf') return LeafLayout.fromJson(json);
    return SplitLayout.fromJson(json);
  }
}

class LeafLayout extends PaneLayout {
  final String cwd;

  LeafLayout({required this.cwd});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'leaf',
        'cwd': cwd,
      };

  factory LeafLayout.fromJson(Map<String, dynamic> json) {
    return LeafLayout(cwd: json['cwd'] as String? ?? '');
  }
}

class SplitLayout extends PaneLayout {
  final PaneLayout first;
  final PaneLayout second;
  final Axis axis;
  final double ratio;

  SplitLayout({
    required this.first,
    required this.second,
    required this.axis,
    this.ratio = 0.5,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'split',
        'axis': axis == Axis.horizontal ? 'horizontal' : 'vertical',
        'ratio': ratio,
        'first': first.toJson(),
        'second': second.toJson(),
      };

  factory SplitLayout.fromJson(Map<String, dynamic> json) {
    return SplitLayout(
      first: PaneLayout.fromJson(json['first'] as Map<String, dynamic>),
      second: PaneLayout.fromJson(json['second'] as Map<String, dynamic>),
      axis: json['axis'] == 'horizontal' ? Axis.horizontal : Axis.vertical,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
