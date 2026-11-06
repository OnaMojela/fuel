import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_provider.dart';
import 'http_errors.dart';

/// Anthropic Messages API over raw HTTP (there is no official Dart SDK).
/// Structured outputs guarantee the response matches [itemsSchema].
class ClaudeProvider implements AiProvider {
  ClaudeProvider(this._dio, this._key, this._model);
  final Dio _dio;
  final String _key, _model;

  // Models that accept server-side refusal fallbacks ("default" routing).
  static const _fallbackModels = {'claude-opus-5-5', 'claude-opus-5', 'claude-sonnet-5-5', 'claude-fable-5-1'};

  Future<List<DetectedItem>> _call(String system, List<Map<String, Object>> content) async {
    final fallback = _fallbackModels.contains(_model);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://api.anthropic.com/v1/messages',
        options: Options(
          headers: {
            'x-api-key': _key,
            'anthropic-version': '2023-06-01',
            if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
            // Only needed for the PC web preview, where the call comes from a browser.
            if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
          },
          receiveTimeout: const Duration(seconds: 120),
        ),
        data: {
          'model': _model,
          'max_tokens': 16000,
          if (fallback) 'fallbacks': 'default',
          'system': system,
          'output_config': {
            'format': {'type': 'json_schema', 'schema': itemsSchema},
          },
          'messages': [
            {'role': 'user', 'content': content},
          ],
        },
      );
      final data = res.data ?? const {};
      if (data['stop_reason'] == 'refusal') {
        throw AiException('Claude declined this request. Try another photo or describe the meal.');
      }
      if (data['stop_reason'] == 'max_tokens') {
        throw AiException('Claude ran out of room answering. Try again.');
      }
      final text = (data['content'] as List? ?? const [])
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join();
      return parseItemsJson(text);
    } on DioException catch (e) {
      throw aiHttpError('Claude', e);
    }
  }

  @override
  Future<List<DetectedItem>> analyzeMeal(Uint8List image, {String? note}) => _call(mealScanPrompt, [
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': imageMime(image), 'data': base64Encode(image)},
        },
        {'type': 'text', 'text': 'Estimate this meal.${userNote(note)}'},
      ]);

  @override
  Future<List<DetectedItem>> parseText(String text) => _call(textParsePrompt, [
        {'type': 'text', 'text': 'What I ate: $text'},
      ]);
}
