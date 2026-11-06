import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_provider.dart';
import 'http_errors.dart';

/// Google Gemini via the generateContent REST endpoint.
class GeminiProvider implements AiProvider {
  GeminiProvider(this._dio, this._key, this._model);
  final Dio _dio;
  final String _key, _model;

  Future<List<DetectedItem>> _call(List<Map<String, Object>> parts) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
        options: Options(headers: {'x-goog-api-key': _key}, receiveTimeout: const Duration(seconds: 90)),
        data: {
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {'responseMimeType': 'application/json'},
        },
      );
      final cand = (res.data?['candidates'] as List?)?.firstOrNull as Map?;
      final textParts = ((cand?['content'] as Map?)?['parts'] as List? ?? const [])
          .whereType<Map>()
          .where((p) => p['thought'] != true && p['text'] is String)
          .map((p) => p['text'] as String);
      if (textParts.isEmpty) {
        throw AiException('Gemini returned no answer (${cand?['finishReason'] ?? 'blocked'}).');
      }
      return parseItemsJson(textParts.join());
    } on DioException catch (e) {
      throw aiHttpError('Gemini', e);
    }
  }

  @override
  Future<List<DetectedItem>> analyzeMeal(Uint8List image, {String? note}) => _call([
        {'text': mealScanPrompt + userNote(note) + schemaHint},
        {
          'inline_data': {'mime_type': imageMime(image), 'data': base64Encode(image)},
        },
      ]);

  @override
  Future<List<DetectedItem>> parseText(String text) => _call([
        {'text': '$textParsePrompt$schemaHint\n\nWhat I ate: $text'},
      ]);
}
