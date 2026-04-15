import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../workspace/workspace_paths.dart';

/// Securely stores and retrieves API keys using the OS keychain.
///
/// Keys are scoped per workspace and per provider — Work and Personal
/// can hold different OpenAI keys without bleeding into each other.
/// Format: `bolan_api_key_<workspace_id>_<provider>`.
///
/// For the `default` workspace, reads also fall back to the legacy
/// unprefixed key (`bolan_api_key_<provider>`) so users upgrading from
/// pre-workspaces installs keep their keys with no migration step.
/// Writes always use the workspace-scoped form.
class ApiKeyStorage {
  static const _options =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static const _storage = FlutterSecureStorage(iOptions: _options);

  static String _scopedKey(String provider) {
    final id = WorkspacePaths.activeWorkspaceId ?? 'default';
    return 'bolan_api_key_${id}_$provider';
  }

  static String _legacyKey(String provider) => 'bolan_api_key_$provider';

  static Future<void> saveKey(String provider, String key) async {
    await _storage.write(key: _scopedKey(provider), value: key);
  }

  static Future<String?> readKey(String provider) async {
    final scoped = await _storage.read(key: _scopedKey(provider));
    if (scoped != null && scoped.isNotEmpty) return scoped;
    // Legacy fallback: only the default workspace inherits pre-workspaces
    // keys — other workspaces start empty so they don't accidentally
    // exfiltrate data through a stale key the user forgot about.
    if (WorkspacePaths.activeWorkspaceId == 'default' ||
        WorkspacePaths.activeWorkspaceId == null) {
      return _storage.read(key: _legacyKey(provider));
    }
    return null;
  }

  static Future<void> deleteKey(String provider) async {
    await _storage.delete(key: _scopedKey(provider));
  }

  static Future<bool> hasKey(String provider) async {
    final key = await readKey(provider);
    return key != null && key.isNotEmpty;
  }

  /// Removes all keys belonging to [workspaceId]. Called when a
  /// workspace is deleted so credentials don't linger in the keychain.
  /// Best-effort — failures (key not present) are silently ignored.
  static Future<void> deleteAllForWorkspace(String workspaceId) async {
    for (final provider in _knownProviders) {
      await _storage.delete(key: 'bolan_api_key_${workspaceId}_$provider');
    }
  }

  static const _knownProviders = ['anthropic', 'openai', 'gemini'];
}
