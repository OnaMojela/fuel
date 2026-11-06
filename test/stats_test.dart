import 'package:calorie_tracker/domain/models.dart';
import 'package:calorie_tracker/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

Food _food(String name, double kcalPer100) =>
    Food(id: name, name: name, source: FoodSource.custom, per100g: Nutrients(calories: kcalPer100, protein: 10));

Entry _e(String date, String food, double kcal) => Entry(
      date: date,
      meal: Meal.lunch,
      food: _food(food, 100),
      servingLabel: 'g',
      servingGrams: 1,
      quantity: kcal, // 100 kcal/100 g → grams == kcal
      createdAt: DateTime(2026),
    );

void main() {
  test('dailyTotals includes empty days in order', () {
    final days = dailyTotals([_e('2026-10-02', 'a', 500), _e('2026-10-02', 'b', 300)], DateTime(2026, 10, 1), DateTime(2026, 10, 3));
    expect(days.map((d) => d.nutrients.calories), [0, 800, 0]);
    expect(days.map((d) => d.logged), [false, true, false]);
  });

  test('dailyTotals crosses month ends', () {
    expect(dailyTotals(const [], DateTime(2026, 9, 29), DateTime(2026, 10, 2)), hasLength(4));
  });

  group('loggingStreak', () {
    final today = DateTime(2026, 10, 9);
    test('counts back from today', () {
      expect(loggingStreak({'2026-10-09', '2026-10-08', '2026-10-07', '2026-10-05'}, today), 3);
    });
    test('today not logged yet keeps yesterday’s streak', () {
      expect(loggingStreak({'2026-10-08', '2026-10-07'}, today), 2);
    });
    test('broken streak is zero', () {
      expect(loggingStreak({'2026-10-06'}, today), 0);
    });
  });

  test('topFoods ranks by total calories and counts times', () {
    final top = topFoods([_e('d', 'pap', 300), _e('d', 'wors', 350), _e('d', 'pap', 300)]);
    expect(top.first.name, 'pap');
    expect(top.first.calories, 600);
    expect(top.first.times, 2);
  });

  test('averageOfLogged ignores empty days', () {
    final days = dailyTotals([_e('2026-10-01', 'a', 2000), _e('2026-10-03', 'a', 1000)], DateTime(2026, 10, 1), DateTime(2026, 10, 7));
    expect(averageOfLogged(days).calories, 1500);
  });

  test('weekly report: on-target days, best day, weight change', () {
    const goals = Goals(calories: 2000);
    final r = weeklyReport(
      entries: [
        _e('2026-10-03', 'a', 2050), // on target, best
        _e('2026-10-05', 'a', 2600), // over
        _e('2026-10-09', 'a', 1700), // under
        _e('2026-09-30', 'a', 9999), // before the week: excluded
      ],
      weights: const [WeightEntry('2026-10-01', 80.0), WeightEntry('2026-10-08', 79.2), WeightEntry('2026-09-25', 81.0)],
      goals: goals,
      end: DateTime(2026, 10, 9),
    );
    expect(r.days, hasLength(7));
    expect(r.daysLogged, 3);
    expect(r.daysOnTarget, 1);
    expect(r.bestDay!.date, DateTime(2026, 10, 3));
    expect(r.average.calories, closeTo((2050 + 2600 + 1700) / 3, 0.01));
    // Week is 3–9 Oct. Baseline = last weigh-in before it (1 Oct, 80.0); latest in it = 79.2.
    expect(r.weightChangeKg, closeTo(-0.8, 0.001));
    expect(r.calorieBalance, closeTo(50 + 600 - 300, 0.01));
  });

  test('weekly report with nothing logged', () {
    final r = weeklyReport(entries: const [], weights: const [], goals: const Goals(), end: DateTime(2026, 10, 9));
    expect(r.daysLogged, 0);
    expect(r.bestDay, isNull);
    expect(r.weightChangeKg, isNull);
  });

  group('Recipe', () {
    final recipe = Recipe(
      id: 7,
      name: 'Chakalaka',
      servings: 4,
      ingredients: [
        Ingredient(_food('beans', 100), 400), // 400 kcal
        Ingredient(_food('oil', 900), 40), // 360 kcal
      ],
    );

    test('per-serving nutrition', () {
      expect(recipe.total.calories, 760);
      expect(recipe.perServing.calories, 190);
    });

    test('as a food: per-100g of the finished dish, 1 serving default', () {
      final f = recipe.toFood();
      expect(f.id, 'recipe:7');
      expect(f.per100g.calories, closeTo(760 / 440 * 100, 0.01));
      expect(f.servings.single.grams, 110);
      expect(f.forGrams(110).calories, closeTo(190, 0.01));
    });

    test('encode/decode round-trip', () {
      final back = Recipe.decode(7, recipe.encode());
      expect(back.name, 'Chakalaka');
      expect(back.servings, 4);
      expect(back.ingredients.last.food.per100g.calories, 900);
    });
  });
}
