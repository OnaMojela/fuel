import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models.dart';

/// Open Food Facts: crowd-sourced packaged foods, looked up by text or barcode.
/// OFF asks API clients to send a descriptive User-Agent. Browsers forbid
/// setting it (and it breaks CORS), so the web preview skips it.
class OpenFoodFactsApi {
  OpenFoodFactsApi(this._dio);
  final Dio _dio;

  static const _fields = 'code,product_name,brands,nutriments,serving_size,serving_quantity';
  static final _headers = kIsWeb ? <String, String>{} : {'User-Agent': 'Fuel/0.1 (personal Flutter app)'};

  /// Searches products sold in South Africa (the za. subdomain filters by country).
  /// Barcode lookups stay global, since imported products scan the same anywhere.
  Future<List<Food>> search(String query, {int pageSize = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://za.openfoodfacts.org/cgi/search.pl',
      queryParameters: {
        'search_terms': query,
        'search_simple': 1,
        'action': 'process',
        'json': 1,
        'page_size': pageSize,
        'fields': _fields,
      },
      options: Options(headers: _headers, receiveTimeout: const Duration(seconds: 8)),
    );
    final products = (res.data?['products'] as List?) ?? const [];
    return products.map((p) => parseProduct(p as Map<String, dynamic>)).whereType<Food>().toList();
  }

  /// Returns null when the barcode isn't in the database.
  Future<Food?> byBarcode(String code) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://world.openfoodfacts.org/api/v2/product/$code.json',
      queryParameters: {'fields': _fields},
      options: Options(headers: _headers, validateStatus: (s) => s != null && s < 500),
    );
    final data = res.data;
    if (data == null || data['status'] != 1) return null;
    return parseProduct(data['product'] as Map<String, dynamic>);
  }

  static Food? parseProduct(Map<String, dynamic> p) {
    final name = (p['product_name'] as String?)?.trim();
    final n = p['nutriments'] as Map<String, dynamic>?;
    if (name == null || name.isEmpty || n == null) return null;

    double? v(String k) {
      final x = n[k];
      if (x is num) return x.toDouble();
      if (x is String) return double.tryParse(x);
      return null;
    }

    var kcal = v('energy-kcal_100g');
    if (kcal == null) {
      final kj = v('energy_100g') ?? v('energy-kj_100g');
      if (kj != null) kcal = kj / 4.184;
    }
    if (kcal == null) return null;

    final servings = <Serving>[];
    final sq = p['serving_quantity'];
    final sqv = sq is num ? sq.toDouble() : (sq is String ? double.tryParse(sq) : null);
    if (sqv != null && sqv > 0) {
      final label = (p['serving_size'] as String?)?.trim();
      servings.add(Serving(label == null || label.isEmpty ? 'serving (${sqv.round()} g)' : 'serving · $label', sqv));
    }

    final brands = (p['brands'] as String?)?.split(',').first.trim();
    return Food(
      id: 'off:${p['code']}',
      name: name,
      brand: (brands == null || brands.isEmpty) ? null : brands,
      source: FoodSource.off,
      servings: servings,
      per100g: Nutrients(
        calories: kcal,
        protein: v('proteins_100g') ?? 0,
        carbs: v('carbohydrates_100g') ?? 0,
        fat: v('fat_100g') ?? 0,
        fiber: v('fiber_100g') ?? 0,
        sugar: v('sugars_100g') ?? 0,
        saturatedFat: v('saturated-fat_100g') ?? 0,
        // OFF reports these in grams; we store mg.
        sodium: (v('sodium_100g') ?? 0) * 1000,
        cholesterol: (v('cholesterol_100g') ?? 0) * 1000,
        potassium: (v('potassium_100g') ?? 0) * 1000,
      ),
    );
  }
}
