import 'package:dio/dio.dart';

/// HTTP client for Google's Gemini API (Google AI Studio).
///
/// Uses the free-tier `generativelanguage.googleapis.com` endpoint.
/// API key passed as a query parameter.
class GeminiProvider {
  final Dio _dio;
  final String _apiKey;
  final String _model;

  GeminiProvider({required String apiKey, required String model})
      : _apiKey = apiKey,
        _model = model,
        _dio = Dio(BaseOptions(
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Sends a prompt to Gemini and returns the text response.
  Future<String> generateContent(String prompt) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/models/$_model:generateContent',
      queryParameters: {'key': _apiKey},
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 2048,
        },
      },
    );

    final data = response.data;
    if (data == null) throw Exception('Empty response from Gemini');

    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('No content parts in Gemini response');
    }

    final firstPart = parts[0] as Map<String, dynamic>;
    return (firstPart['text'] as String?) ?? '';
  }
}
