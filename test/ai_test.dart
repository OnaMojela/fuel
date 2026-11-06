import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_tracker/data/ai/ai_provider.dart';
import 'package:calorie_tracker/data/ai/claude.dart';
import 'package:calorie_tracker/data/ai/gemini.dart';
import 'package:calorie_tracker/data/ai/openai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the outgoing request and replies with a canned JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? request;
  Map<String, dynamic>? sentJson;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    sentJson = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter a) => Dio()..httpClientAdapter = a;

const _itemsJson = {
  'items': [
    {
      'name': 'Grilled chicken breast',
      'grams': 150,
      'confidence': 0.8,
      'per100g': {
        'calories': 165,
        'protein': 31,
        'carbs': 0,
        'fat': 3.6,
        'fiber': 0,
        'sugar': 0,
        'saturated_fat': 1,
        'sodium_mg': 74,
      },
    },
  ],
};

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

void main() {
  group('parseItemsJson', () {
    test('parses fenced JSON and clamps values', () {
      final items = parseItemsJson('```json\n{"items":[{"name":"Rice","grams":-5,"confidence":3,'
          '"per100g":{"calories":"130","protein":2.7}}]}\n```');
      expect(items.single.name, 'Rice');
      expect(items.single.grams, 0);
      expect(items.single.confidence, 1);
      expect(items.single.per100g.calories, 130);
    });

    test('drops nameless items, empty list ok', () {
      expect(parseItemsJson('{"items":[{"name":"  ","grams":10}]}'), isEmpty);
      expect(parseItemsJson('{"items":[]}'), isEmpty);
    });

    test('throws on non-JSON', () {
      expect(() => parseItemsJson('I cannot see any food'), throwsA(isA<AiException>()));
    });

    test('item → food scales correctly', () {
      final food = parseItemsJson(jsonEncode(_itemsJson)).single.toFood();
      expect(food.forGrams(150).calories, closeTo(247.5, 0.01));
    });
  });

  test('imageMime sniffs PNG and defaults to JPEG', () {
    expect(imageMime(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), 'image/png');
    expect(imageMime(_jpeg), 'image/jpeg');
  });

  test('Gemini: request shape + skips thought parts', () async {
    final a = _FakeAdapter(200, {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'thinking...', 'thought': true},
              {'text': jsonEncode(_itemsJson)},
            ],
          },
        },
      ],
    });
    final items = await GeminiProvider(_dio(a), 'KEY', 'gemini-flash-latest').analyzeMeal(_jpeg, note: 'fried');
    expect(items.single.name, 'Grilled chicken breast');
    expect(a.request!.uri.path, '/v1beta/models/gemini-flash-latest:generateContent');
    expect(a.request!.headers['x-goog-api-key'], 'KEY');
    final parts = (a.sentJson!['contents'] as List).first['parts'] as List;
    expect((parts[0]['text'] as String), contains('Extra context from the user: fried'));
    expect(parts[1]['inline_data']['mime_type'], 'image/jpeg');
  });

  test('OpenAI: request shape', () async {
    final a = _FakeAdapter(200, {
      'choices': [
        {
          'message': {'content': jsonEncode(_itemsJson)},
        },
      ],
    });
    final items = await OpenAiProvider(_dio(a), 'KEY', 'gpt-5.4-mini').parseText('chicken');
    expect(items, hasLength(1));
    expect(a.request!.headers['Authorization'], 'Bearer KEY');
    expect(a.sentJson!['response_format'], {'type': 'json_object'});
    expect(a.sentJson!['model'], 'gpt-5.4-mini');
  });

  test('Claude: structured output, fallbacks only on supported models', () async {
    final body = {
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'text', 'text': jsonEncode(_itemsJson)},
      ],
    };
    final a = _FakeAdapter(200, body);
    await ClaudeProvider(_dio(a), 'KEY', 'claude-opus-5-5').analyzeMeal(_jpeg);
    expect(a.request!.headers['x-api-key'], 'KEY');
    expect(a.request!.headers['anthropic-version'], '2023-06-01');
    expect(a.request!.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    expect(a.sentJson!['fallbacks'], 'default');
    expect(a.sentJson!['output_config']['format']['type'], 'json_schema');
    final content = (a.sentJson!['messages'] as List).first['content'] as List;
    expect(content.first['type'], 'image');

    final b = _FakeAdapter(200, body);
    await ClaudeProvider(_dio(b), 'KEY', 'claude-haiku-5-5').parseText('rice');
    expect(b.request!.headers.containsKey('anthropic-beta'), isFalse);
    expect(b.sentJson!.containsKey('fallbacks'), isFalse);
  });

  test('Claude: refusal surfaces as AiException', () async {
    final a = _FakeAdapter(200, {'stop_reason': 'refusal', 'content': []});
    expect(ClaudeProvider(_dio(a), 'KEY', 'claude-opus-5-5').parseText('x'), throwsA(isA<AiException>()));
  });

  test('HTTP errors map to friendly messages', () async {
    final a = _FakeAdapter(401, {
      'error': {'message': 'bad key'},
    });
    await expectLater(
      GeminiProvider(_dio(a), 'BAD', 'm').parseText('x'),
      throwsA(isA<AiException>().having((e) => e.message, 'message', contains('API key is invalid'))),
    );
    final r = _FakeAdapter(429, {});
    await expectLater(
      OpenAiProvider(_dio(r), 'K', 'm').parseText('x'),
      throwsA(isA<AiException>().having((e) => e.message, 'message', contains('rate limit'))),
    );
  });
}
