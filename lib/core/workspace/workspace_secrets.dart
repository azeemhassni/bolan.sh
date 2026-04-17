import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores per-workspace secret environment variables in the OS keychain.
///
/// Unlike regular env vars (stored in plaintext in workspaces.toml),
/// secrets are encrypted at rest via FlutterSecureStorage. Both are
/// injected into the PTY environment identically at spawn time.
///
/// Secrets for each workspace are stored as a single JSON blob keyed
/// by `bolan_ws_secrets_<workspaceId>`. This avoids one keychain entry
/// per secret and keeps cleanup simple on workspace deletion.
class WorkspaceSecrets {
  static const _options =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static const _storage = FlutterSecureStorage(iOptions: _options);

  static String _key(String workspaceId) =>
      'bolan_ws_secrets_$workspaceId';

  /// Reads all secrets for [workspaceId] as a key-value map.
  static Future<Map<String, String>> load(String workspaceId) async {
    final raw = await _storage.read(key: _key(workspaceId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } on Exception {
      return {};
    }
  }

  /// Saves all secrets for [workspaceId], replacing any previous set.
  static Future<void> save(
      String workspaceId, Map<String, String> secrets) async {
    if (secrets.isEmpty) {
      await _storage.delete(key: _key(workspaceId));
      return;
    }
    await _storage.write(
        key: _key(workspaceId), value: jsonEncode(secrets));
  }

  /// Deletes all secrets for [workspaceId]. Called on workspace deletion.
  static Future<void> deleteAll(String workspaceId) async {
    await _storage.delete(key: _key(workspaceId));
  }
}
