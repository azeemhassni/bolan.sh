import 'package:bolan/core/terminal/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// A fake session that doesn't spawn a PTY process.
/// Used for unit-testing SessionManager logic without native FFI.
class FakeTerminalSession {
  final String id;
  final String title;
  final Terminal terminal;
  bool disposed = false;

  FakeTerminalSession({required this.id, required this.title})
      : terminal = Terminal();

  void dispose() => disposed = true;
}

void main() {
  group('SessionManager', () {
    late SessionManager manager;

    setUp(() {
      manager = SessionManager();
    });

    test('starts with no sessions', () {
      expect(manager.sessions, isEmpty);
      expect(manager.activeIndex, -1);
      expect(manager.activeSession, isNull);
    });

    test('switchTo ignores out-of-bounds index', () {
      manager.switchTo(5);
      expect(manager.activeIndex, -1);
      manager.switchTo(-1);
      expect(manager.activeIndex, -1);
    });

    test('closeSession on empty list returns true', () {
      final result = manager.closeSession(0);
      expect(result, isTrue);
    });
  });
}
