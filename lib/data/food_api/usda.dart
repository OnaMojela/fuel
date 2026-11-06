import 'package:dio/dio.dart';

import '../../domain/models.dart';

/// USDA FoodData Central search, limited to generic (non-branded) foods —
/// branded search ranks poorly for plain foods, and Open Food Facts covers
/// packaged products. Nutrient values in search results are per 100 g.
class UsdaApi {
  UsdaApi(this._dio, this._key);
  final Dio _dio;
  final String Function() _key;

  Future<List<Food>> search(String query, {int pageSize = 25}) async {
    final key = _key().isEmpty ? 'DEMO_KEY' : _key();
    // Encode by hand: the default encoder turns spaces into '+', and USDA
    // answers 400 to "Survey+(FNDDS)". encodeComponent uses %20.
    final params = {
      'api_key': key,
      'query': query,
      'pageSize': '$pageSize',
      'dataType': 'Foundation,SR Legacy,Survey (FNDDS)',
    }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final res = await _dio.get<Map<String, dynamic>>('https://api.nal.usda.gov/fdc/v1/foods/search?$params');
    final foods = (res.data?['foods'] as List?) ?? const [];
    return foods.map((f) => parseFood(f as Map<String, dynamic>)).whereType<Food>().toList();
  }

  static Food? parseFood(Map<String, dynamic> f) {
    final values = <String, double>{};
    for (final n in (f['foodNutrients'] as List? ?? const [])) {
      final m = n as Map<String, dynamic>;
      final num_ = m['nutrientNumber']?.toString();
      final v = (m['value'] as num?)?.toDouble();
      if (num_ == null || v == null) continue;
      // Skip kJ energy rows, which share some ids with kcal in older data.
      if ((m['unitName'] as String?)?.toUpperCase() == 'KJ') continue;
      values.putIfAbsent(num_, () => v);
    }
    double g(String id) => values[id] ?? 0;
    // Energy: 208 (kcal), falling back to Atwater energy (957/958) for Foundation foods.
    final kcal = values['208'] ?? values['958'] ?? values['957'];
    if (kcal == null) return null;

    final servings = <Serving>[];
    final size = (f['servingSize'] as num?)?.toDouble();
    final unit = (f['servingSizeUnit'] as String?)?.toLowerCase();
    if (size != null && size > 0 && (unit == 'g' || unit == 'grm' || unit == 'ml' || unit == 'mlt')) {
      final household = (f['householdServingFullText'] as String?)?.trim();
      final label = (household != null && household.isNotEmpty)
          ? '$household (${size.round()} g)'
          : 'serving (${size.round()} g)';
      servings.add(Serving(label, size));
    }

    return Food(
      id: 'usda:${f['fdcId']}',
      name: _titleCase(f['description'] as String? ?? 'Unknown'),
      brand: (f['brandName'] ?? f['brandOwner']) as String?,
      source: FoodSource.usda,
      servings: servings,
      per100g: Nutrients(
        calories: kcal,
        protein: g('203'),
        fat: g('204'),
        carbs: g('205'),
        fiber: g('291'),
        sugar: values['269'] ?? values['269.3'] ?? 0,
        saturatedFat: g('606'),
        sodium: g('307'),
        cholesterol: g('601'),
        potassium: g('306'),
      ),
    );
  }

  static String _titleCase(String s) {
    // USDA branded names are often ALL CAPS.
    if (s != s.toUpperCase()) return s;
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
