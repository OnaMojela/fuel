import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_provider.dart';
import 'http_errors.dart';

/// OpenAI Chat Completions with JSON mode.
class OpenAiProvider implements AiProvider {
  OpenAiProvider(this._dio, this._key, this._model);
  final Dio _dio;
  final String _key, _model;

  Future<List<DetectedItem>> _call(String system, Object userContent) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://api.openai.com/v1/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $_key'}, receiveTimeout: const Duration(seconds: 90)),
        data: {
          'model': _model,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': system + schemaHint},
            {'role': 'user', 'content': userContent},
          ],
        },
      );
      final msg = ((res.data?['choices'] as List?)?.firstOrNull as Map?)?['message'] as Map?;
      final content = msg?['content'] as String?;
      if (content == null) throw AiException('OpenAI returned no answer${msg?['refusal'] != null ? ': ${msg!['refusal']}' : '.'}');
      return parseItemsJson(content);
    } on DioException catch (e) {
      throw aiHttpError('OpenAI', e);
    }
  }

  @override
  Future<List<DetectedItem>> analyzeMeal(Uint8List image, {String? note}) => _call(mealScanPrompt, [
        {'type': 'text', 'text': 'Estimate this meal.${userNote(note)}'},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:${imageMime(image)};base64,${base64Encode(image)}'},
        },
      ]);

  @override
  Future<List<DetectedItem>> parseText(String text) => _call(textParsePrompt, 'What I ate: $text');
}
