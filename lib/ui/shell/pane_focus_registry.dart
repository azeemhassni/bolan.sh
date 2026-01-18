import '../../ui/prompt/prompt_input.dart';

/// Global registry mapping pane IDs to their prompt input states.
///
/// Used by TerminalShell's global key handler to focus the correct
/// pane's prompt when the user starts typing.
class PaneFocusRegistry {
  static final Map<String, PromptInputState> _registry = {};

  static void register(String paneId, PromptInputState state) {
    _registry[paneId] = state;
  }

  static void unregister(String paneId) {
    _registry.remove(paneId);
  }

  static PromptInputState? get(String paneId) {
    return _registry[paneId];
  }
}
