import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract class IAiClient {
  Future<String?> generateCompletion({
    required String systemPrompt,
    required String userPrompt,
  });
}

class GroqAiClient implements IAiClient {
  final Dio _dio;
  final String? _apiKey;

  static const String defaultModel = 'openai/gpt-oss-120b';
  static const String fallbackModel = 'openai/gpt-oss-20b';
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqAiClient({Dio? dio, String? apiKey})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 8),
              ),
            ),
        _apiKey = apiKey ??
            (const String.fromEnvironment('GROQ_API_KEY').isNotEmpty
                ? const String.fromEnvironment('GROQ_API_KEY')
                : null);

  bool get isConfigured => _apiKey != null && _apiKey.trim().isNotEmpty;

  @override
  Future<String?> generateCompletion({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    if (!isConfigured) {
      debugPrint('[GroqAiClient] No API key configured. Using local engine fallback.');
      return null;
    }

    try {
      final response = await _dio.post(
        _groqUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_apiKey!.trim()}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': defaultModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final choices = response.data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices.first['message'];
          if (message != null) {
            return message['content']?.toString();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[GroqAiClient] Request error: $e. Falling back to local engine.');
      return null;
    }
  }
}
