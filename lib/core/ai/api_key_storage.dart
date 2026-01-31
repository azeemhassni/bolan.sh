import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores and retrieves API keys using the OS keychain.
///
/// Keys are stored per provider (gemini, openai, anthropic).
/// Never exposed to widget state or logged.
///
/// Uses data protection keychain on macOS (useDataProtectionKeyChain: true)
/// which works without code signing or keychain-access-groups entitlement.
class ApiKeyStorage {
  static const _options = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static const _storage = FlutterSecureStorage(iOptions: _options);

  static Future<void> saveKey(String provider, String key) async {
    await _storage.write(key: 'bolan_api_key_$provider', value: key);
  }

  static Future<String?> readKey(String provider) async {
    return _storage.read(key: 'bolan_api_key_$provider');
  }

  static Future<void> deleteKey(String provider) async {
    await _storage.delete(key: 'bolan_api_key_$provider');
  }

  static Future<bool> hasKey(String provider) async {
    final key = await readKey(provider);
    return key != null && key.isNotEmpty;
  }
}
