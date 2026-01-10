import 'package:uuid/uuid.dart';

import 'session.dart';

/// Manages the lifecycle of terminal sessions.
///
/// Handles creating, switching, and closing sessions. Maintains the list of
/// active sessions and tracks which session is currently focused.
class SessionManager {
  final List<TerminalSession> _sessions = [];
  int _activeIndex = -1;

  static const _uuid = Uuid();

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  int get activeIndex => _activeIndex;

  TerminalSession? get activeSession {
    if (_activeIndex < 0 || _activeIndex >= _sessions.length) return null;
    return _sessions[_activeIndex];
  }

  /// Creates a new terminal session and makes it active.
  TerminalSession createSession({String? workingDirectory}) {
    final session = TerminalSession.start(
      id: _uuid.v4(),
      workingDirectory: workingDirectory,
    );
    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    return session;
  }

  /// Switches the active session to the one at [index].
  void switchTo(int index) {
    if (index < 0 || index >= _sessions.length) return;
    _activeIndex = index;
  }

  /// Closes the session at [index] and disposes its resources.
  ///
  /// If the closed session was active, the active index shifts to the
  /// nearest remaining session. Returns true if the last session was closed.
  bool closeSession(int index) {
    if (index < 0 || index >= _sessions.length) return _sessions.isEmpty;
    _sessions[index].dispose();
    _sessions.removeAt(index);

    if (_sessions.isEmpty) {
      _activeIndex = -1;
      return true;
    }

    if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    } else if (_activeIndex > index) {
      _activeIndex--;
    }
    return false;
  }

  /// Disposes all sessions.
  void disposeAll() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    _activeIndex = -1;
  }
}
