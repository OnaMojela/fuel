import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models.dart';

/// One food the AI found in a photo or description.
class DetectedItem {
  const DetectedItem({required this.name, required this.grams, required this.confidence, required this.per100g});
  final String name;
  final double grams;
  final double confidence; // 0..1
  final Nutrients per100g;

  Food toFood() => Food(
        id: 'ai:${name.toLowerCase()}',
        name: name,
        source: FoodSource.ai,
        per100g: per100g,
      );
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum AiKind {
  gemini('Gemini', 'gemini-flash-latest', 'aistudio.google.com/apikey'),
  openai('OpenAI', 'gpt-5.4-mini', 'platform.openai.com/api-keys'),
  claude('Claude', 'claude-opus-5-5', 'console.anthropic.com/settings/keys');

  const AiKind(this.label, this.defaultModel, this.keyUrl);
  final String label, defaultModel, keyUrl;
}

/// Common interface for the three vision/text providers.
abstract class AiProvider {
  Future<List<DetectedItem>> analyzeMeal(Uint8List image, {String? note});
  Future<List<DetectedItem>> parseText(String text);
}

// ---------- Shared prompt + schema ----------

/// The user lives in South Africa: local dish names and portion norms matter.
const _saContext = '''
The user is in South Africa. Recognise South African foods by their local names (e.g. pap/mieliepap, phutu, samp and beans, boerewors, biltong, droëwors, chakalaka, morogo, vetkoek/amagwinya, kota, bunny chow, bobotie, sosatie, koeksister, melktert, rusks, mageu, amasi) and local brands (Woolworths, Checkers, Pick n Pay, Spar, Simba, Ouma, Iwisa, Tastic). Use South African portion norms and metric units.''';

const mealScanPrompt = '''
You are a nutrition assistant estimating a meal from a photo.
$_saContext
1. Identify every distinct food and drink that will be eaten. Split mixed plates into components (e.g. rice, chicken, sauce) unless it is a single standard dish.
2. Estimate the portion weight in grams for each item from visual cues: a dinner plate is ~26 cm across, a fork ~19 cm, a can 330 ml. Prefer realistic home portions over minimal ones.
3. Add likely hidden calories as separate items when typical for the dish (cooking oil, butter, dressing, sugar in drinks).
4. Give nutrition per 100 g for each item using typical reference values (USDA-style) for the food as prepared.
5. confidence is 0..1 for how sure you are about the identity and portion together.
If no food is visible, return an empty items list.
Return JSON only, matching the schema.''';

const textParsePrompt = '''
You are a nutrition assistant. Turn the user's description of what they ate into food items.
$_saContext
- Convert household measures (cup, slice, tbsp, "a bowl", "a handful") to grams using typical values.
- If no amount is given, assume one typical serving.
- Give nutrition per 100 g for each item using typical reference values (USDA-style) for the food as prepared.
- confidence is 0..1 for how sure you are about the identity and amount together.
Return JSON only, matching the schema.''';

/// JSON Schema for the response. Strict-friendly: every object closed, every field required.
const itemsSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['items'],
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['name', 'grams', 'confidence', 'per100g'],
        'properties': {
          'name': {'type': 'string'},
          'grams': {'type': 'number'},
          'confidence': {'type': 'number'},
          'per100g': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'saturated_fat', 'sodium_mg'],
            'properties': {
              'calories': {'type': 'number'},
              'protein': {'type': 'number'},
              'carbs': {'type': 'number'},
              'fat': {'type': 'number'},
              'fiber': {'type': 'number'},
              'sugar': {'type': 'number'},
              'saturated_fat': {'type': 'number'},
              'sodium_mg': {'type': 'number'},
            },
          },
        },
      },
    },
  },
};

/// Schema text appended to prompts for providers without strict schema support.
final schemaHint = '\nJSON schema:\n${jsonEncode(itemsSchema)}';

String userNote(String? note) =>
    (note == null || note.trim().isEmpty) ? '' : '\nExtra context from the user: ${note.trim()}';

/// Parses model output into items. Tolerates code fences and stray prose.
List<DetectedItem> parseItemsJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) throw AiException('The AI response was not valid JSON.');
  final Object? data;
  try {
    data = jsonDecode(raw.substring(start, end + 1));
  } on FormatException {
    throw AiException('The AI response was not valid JSON.');
  }
  final items = (data is Map ? data['items'] : null) as List? ?? const [];

  double n(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

  return [
    for (final it in items.whereType<Map>())
      if ((it['name'] as String?)?.trim().isNotEmpty ?? false)
        DetectedItem(
          name: (it['name'] as String).trim(),
          grams: n(it['grams']).clamp(0, 5000).toDouble(),
          confidence: n(it['confidence']).clamp(0, 1).toDouble(),
          per100g: () {
            final p = (it['per100g'] as Map?) ?? const {};
            return Nutrients(
              calories: n(p['calories']),
              protein: n(p['protein']),
              carbs: n(p['carbs']),
              fat: n(p['fat']),
              fiber: n(p['fiber']),
              sugar: n(p['sugar']),
              saturatedFat: n(p['saturated_fat']),
              sodium: n(p['sodium_mg']),
            );
          }(),
        ),
  ];
}

/// Best-effort image type sniffing (image_picker re-encodes most photos to JPEG).
String imageMime(Uint8List b) {
  if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57) return 'image/webp';
  return 'image/jpeg';
}
