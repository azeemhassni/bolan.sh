import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/terminal/session.dart';
import '../core/terminal/session_manager.dart';

/// Notifier that manages the terminal session lifecycle and active session state.
class SessionNotifier extends Notifier<SessionState> {
  late final SessionManager _manager;

  @override
  SessionState build() {
    _manager = SessionManager();
    // Create an initial session on startup.
    _manager.createSession();
    ref.onDispose(_manager.disposeAll);
    return _stateFromManager();
  }

  /// Creates a new tab / session.
  void createSession({String? workingDirectory}) {
    _manager.createSession(workingDirectory: workingDirectory);
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
      _manager.createSession();
    }
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
