import 'models.dart';

Nutrients sumEntries(Iterable<Entry> entries) =>
    entries.fold(Nutrients.zero, (acc, e) => acc + e.nutrients);

/// Mifflin-St Jeor BMR.
double bmr({required String sex, required int age, required double heightCm, required double weightKg}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex == 'male' ? base + 5 : base - 161;
}

/// Daily calorie target: TDEE adjusted by weekly weight change
/// (≈7700 kcal per kg), with a safety floor.
double recommendedCalories(Goals g) {
  final tdee = bmr(sex: g.sex, age: g.age, heightCm: g.heightCm, weightKg: g.weightKg) * g.activity;
  final adjusted = tdee + g.weeklyChangeKg * 7700 / 7;
  final floor = g.sex == 'male' ? 1500.0 : 1200.0;
  return (adjusted < floor ? floor : adjusted).roundToDouble();
}

/// Share of calories coming from each macro (0..1), for macro pie/bars.
({double carbs, double protein, double fat}) macroSplit(Nutrients n) {
  final c = n.carbs * 4, p = n.protein * 4, f = n.fat * 9;
  final total = c + p + f;
  if (total == 0) return (carbs: 0, protein: 0, fat: 0);
  return (carbs: c / total, protein: p / total, fat: f / total);
}
