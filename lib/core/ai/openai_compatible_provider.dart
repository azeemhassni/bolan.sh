import 'dart:convert';
import 'dart:io';

import 'ai_provider.dart';

/// Provider for any OpenAI-compatible chat completions API.
///
/// Works with OpenAI, Anthropic (via proxy), Ollama, and the local
/// Bolan LLM server — they all expose `/v1/chat/completions`.
class OpenAiCompatibleProvider implements AiProvider {
  final String _baseUrl;
  final String _model;
  final String? _apiKey;
  final String _name;
  final double _temperature;
  final int _maxTokens;
  final Duration _timeout;

  OpenAiCompatibleProvider({
    required String baseUrl,
    required String model,
    String? apiKey,
    String name = 'OpenAI',
    double temperature = 0.2,
    int maxTokens = 2048,
    Duration timeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _model = model,
        _apiKey = apiKey,
        _name = name,
        _temperature = temperature,
        _maxTokens = maxTokens,
        _timeout = timeout;

  @override
  String get displayName => _name;

  @override
  Future<bool> isAvailable() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('$_baseUrl/v1/models');
      final request = await client.getUrl(uri);
      if (_apiKey != null && _apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $_apiKey');
      }
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
      client.close();
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  @override
  Future<String> generateContent(String prompt) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/v1/chat/completions');
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      if (_apiKey != null && _apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $_apiKey');
      }

      final body = utf8.encode(jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': _temperature,
        'max_tokens': _maxTokens,
      }));

      request.add(body);
      final response = await request.close().timeout(_timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('$_name API error ${response.statusCode}: $responseBody');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in $_name response');
      }

      final firstChoice = choices[0] as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      return (message?['content'] as String?)?.trim() ?? '';
    } finally {
      client.close();
    }
  }
}
