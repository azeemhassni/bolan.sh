import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/terminal/session.dart';
import '../core/terminal/session_manager.dart';

/// Notifier that manages the terminal session lifecycle and active session state.
///
/// Listens to each session's ChangeNotifier so the tab bar updates when
/// commands start/finish (changing tab titles and status icons).
class SessionNotifier extends Notifier<SessionState> {
  late final SessionManager _manager;

  @override
  SessionState build() {
    _manager = SessionManager();
    _manager.history.load();
    final session = _manager.createSession();
    _attachListener(session);
    ref.onDispose(_manager.disposeAll);
    return _stateFromManager();
  }

  /// Creates a new tab / session.
  void createSession({String? workingDirectory}) {
    final session =
        _manager.createSession(workingDirectory: workingDirectory);
    _attachListener(session);
    state = _stateFromManager();
  }

  /// Switches focus to the session at [index].
  void switchTo(int index) {
    _manager.switchTo(index);
    state = _stateFromManager();
  }

  /// Closes the session at [index]. If it was the last session, creates a new one.
  void closeSession(int index) {
    final wasLast = _manager.closeSession(index);
    if (wasLast) {
      final session = _manager.createSession();
      _attachListener(session);
    }
    state = _stateFromManager();
  }

  void _attachListener(TerminalSession session) {
    session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    state = _stateFromManager();
  }

  SessionState _stateFromManager() => SessionState(
        sessions: _manager.sessions,
        activeIndex: _manager.activeIndex,
      );
}

/// Immutable snapshot of session manager state for the UI.
class SessionState {
  final List<TerminalSession> sessions;
  final int activeIndex;

  const SessionState({
    required this.sessions,
    required this.activeIndex,
  });

  TerminalSession? get activeSession {
    if (activeIndex < 0 || activeIndex >= sessions.length) return null;
    return sessions[activeIndex];
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
