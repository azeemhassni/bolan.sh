import 'dart:async';

/// Pub/sub channel for broadcasting keystrokes across panes.
///
/// The focused pane publishes text changes and submissions.
/// All other panes in the same tab subscribe and mirror the input.
/// Only active when broadcast mode is toggled on.
class InputBroadcast {
  InputBroadcast._();

  static final _textController = StreamController<String>.broadcast();
  static final _submitController = StreamController<String>.broadcast();

  /// Stream of text changes (real-time typing mirror).
  static Stream<String> get onTextChanged => _textController.stream;

  /// Stream of command submissions (Enter pressed).
  static Stream<String> get onSubmit => _submitController.stream;

  /// Publish a text change from the focused pane.
  static void publishText(String text) {
    _textController.add(text);
  }

  /// Publish a command submission from the focused pane.
  static void publishSubmit(String data) {
    _submitController.add(data);
  }
}
