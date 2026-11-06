import 'package:calorie_tracker/data/food_api/open_food_facts.dart';
import 'package:calorie_tracker/data/food_api/usda.dart';
import 'package:calorie_tracker/domain/models.dart';
import 'package:calorie_tracker/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

const _rice = Food(
  id: 'x',
  name: 'Rice',
  source: FoodSource.custom,
  per100g: Nutrients(calories: 130, carbs: 28, protein: 2.7, fat: 0.3, fiber: 0.4),
);

Entry _entry(double grams, {Meal meal = Meal.lunch}) => Entry(
      date: '2026-10-09',
      meal: meal,
      food: _rice,
      servingLabel: 'g',
      servingGrams: 1,
      quantity: grams,
      createdAt: DateTime(2026, 10, 9),
    );

void main() {
  test('scales per-100g nutrients to eaten grams', () {
    final n = _entry(250).nutrients;
    expect(n.calories, closeTo(325, 0.001));
    expect(n.carbs, closeTo(70, 0.001));
  });

  test('sums entries across meals', () {
    final total = sumEntries([_entry(100), _entry(50, meal: Meal.dinner)]);
    expect(total.calories, closeTo(195, 0.001));
    expect(total.netCarbs, closeTo(42 - 0.6, 0.001));
  });

  test('serving quantity multiplies serving grams', () {
    final e = Entry(
      date: '2026-10-09',
      meal: Meal.breakfast,
      food: _rice,
      servingLabel: 'cup (158 g)',
      servingGrams: 158,
      quantity: 1.5,
      createdAt: DateTime(2026, 10, 9),
    );
    expect(e.grams, 237);
    expect(e.amountLabel, '1.50 × cup (158 g)');
  });

  test('food JSON round-trips', () {
    final back = Food.decode(_rice.encode());
    expect(back.name, 'Rice');
    expect(back.per100g.protein, 2.7);
  });

  test('Mifflin-St Jeor + weekly change', () {
    const g = Goals(sex: 'male', age: 30, heightCm: 180, weightKg: 80, activity: 1.2, weeklyChangeKg: -0.5);
    // BMR = 800 + 1125 - 150 + 5 = 1780; TDEE = 2136; -550/day = 1586
    expect(recommendedCalories(g), 1586);
  });

  test('calorie floor applies', () {
    const g = Goals(sex: 'female', age: 60, heightCm: 150, weightKg: 45, activity: 1.2, weeklyChangeKg: -0.75);
    expect(recommendedCalories(g), 1200);
  });

  test('macro split by calories', () {
    final s = macroSplit(const Nutrients(carbs: 25, protein: 25, fat: 0));
    expect(s.carbs, 0.5);
    expect(s.protein, 0.5);
  });

  test('parses USDA search result', () {
    final f = UsdaApi.parseFood({
      'fdcId': 123,
      'description': 'GREEK YOGURT',
      'brandOwner': 'Fage',
      'servingSize': 170,
      'servingSizeUnit': 'g',
      'householdServingFullText': '1 container',
      'foodNutrients': [
        {'nutrientNumber': '208', 'unitName': 'KCAL', 'value': 59},
        {'nutrientNumber': '203', 'unitName': 'G', 'value': 10.3},
        {'nutrientNumber': '307', 'unitName': 'MG', 'value': 36},
      ],
    })!;
    expect(f.name, 'Greek Yogurt');
    expect(f.per100g.calories, 59);
    expect(f.per100g.protein, 10.3);
    expect(f.servings.single.grams, 170);
    expect(f.servings.single.label, '1 container (170 g)');
  });

  test('USDA foundation food falls back to Atwater energy', () {
    final f = UsdaApi.parseFood({
      'fdcId': 1,
      'description': 'Apple',
      'foodNutrients': [
        {'nutrientNumber': '958', 'unitName': 'KCAL', 'value': 64},
      ],
    });
    expect(f!.per100g.calories, 64);
  });

  test('parses Open Food Facts product (sodium g → mg, kJ fallback)', () {
    final f = OpenFoodFactsApi.parseProduct({
      'code': '123',
      'product_name': 'Oat Bar',
      'brands': 'Brand A, Brand B',
      'serving_quantity': '40',
      'serving_size': '1 bar (40 g)',
      'nutriments': {'energy_100g': 1674, 'proteins_100g': 8, 'sodium_100g': 0.2},
    })!;
    expect(f.brand, 'Brand A');
    expect(f.per100g.calories, closeTo(400, 0.1));
    expect(f.per100g.sodium, closeTo(200, 0.001));
    expect(f.servings.single.grams, 40);
  });
}
