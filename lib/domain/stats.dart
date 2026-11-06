import 'package:intl/intl.dart';

import 'models.dart';
import 'nutrition.dart';

final _key = DateFormat('yyyy-MM-dd');
String _k(DateTime d) => _key.format(d);
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class DayTotal {
  const DayTotal(this.date, this.nutrients, this.entryCount);
  final DateTime date;
  final Nutrients nutrients;
  final int entryCount;
  bool get logged => entryCount > 0;
}

/// One total per calendar day from [from] to [to] inclusive, including empty days.
List<DayTotal> dailyTotals(Iterable<Entry> entries, DateTime from, DateTime to) {
  final byDate = <String, List<Entry>>{};
  for (final e in entries) {
    (byDate[e.date] ??= []).add(e);
  }
  final out = <DayTotal>[];
  for (var d = _day(from); !d.isAfter(_day(to)); d = DateTime(d.year, d.month, d.day + 1)) {
    final list = byDate[_k(d)] ?? const <Entry>[];
    out.add(DayTotal(d, sumEntries(list), list.length));
  }
  return out;
}

/// Consecutive days with at least one food logged, ending today — or ending
/// yesterday if today has nothing yet (the streak isn't broken until tomorrow).
int loggingStreak(Set<String> loggedDates, DateTime today) {
  var d = _day(today);
  if (!loggedDates.contains(_k(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (loggedDates.contains(_k(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

class FoodTotal {
  const FoodTotal(this.name, this.calories, this.times);
  final String name;
  final double calories;
  final int times;
}

/// Foods ranked by total calories contributed.
List<FoodTotal> topFoods(Iterable<Entry> entries, {int limit = 5}) {
  final cal = <String, double>{};
  final times = <String, int>{};
  for (final e in entries) {
    cal[e.food.name] = (cal[e.food.name] ?? 0) + e.nutrients.calories;
    times[e.food.name] = (times[e.food.name] ?? 0) + 1;
  }
  final list = [for (final n in cal.keys) FoodTotal(n, cal[n]!, times[n]!)]
    ..sort((a, b) => b.calories.compareTo(a.calories));
  return list.take(limit).toList();
}

/// Averages over days that have food logged (empty days would drag averages to zero).
Nutrients averageOfLogged(List<DayTotal> days) {
  final logged = days.where((d) => d.logged).toList();
  if (logged.isEmpty) return Nutrients.zero;
  return logged.fold(Nutrients.zero, (a, d) => a + d.nutrients) * (1 / logged.length);
}

class WeeklyReport {
  const WeeklyReport({
    required this.days,
    required this.average,
    required this.daysLogged,
    required this.daysOnTarget,
    required this.goal,
    required this.topFoods,
    required this.weightChangeKg,
    required this.bestDay,
  });
  final List<DayTotal> days;
  final Nutrients average;
  final int daysLogged;
  final int daysOnTarget; // logged days within ±10% of the calorie goal
  final double goal;
  final List<FoodTotal> topFoods;
  final double? weightChangeKg; // last weigh-in in the window minus the one before it started
  final DayTotal? bestDay; // logged day closest to goal

  double get calorieBalance => days.where((d) => d.logged).fold(0.0, (a, d) => a + d.nutrients.calories - goal);
}

WeeklyReport weeklyReport({
  required Iterable<Entry> entries,
  required List<WeightEntry> weights,
  required Goals goals,
  required DateTime end,
}) {
  final start = DateTime(end.year, end.month, end.day - 6);
  final startKey = _k(start), endKey = _k(end);
  final inWeek = entries.where((e) => e.date.compareTo(startKey) >= 0 && e.date.compareTo(endKey) <= 0).toList();
  final days = dailyTotals(inWeek, start, end);
  final logged = days.where((d) => d.logged).toList();

  bool onTarget(DayTotal d) => (d.nutrients.calories - goals.calories).abs() <= goals.calories * 0.10;
  DayTotal? best;
  for (final d in logged) {
    if (best == null ||
        (d.nutrients.calories - goals.calories).abs() < (best.nutrients.calories - goals.calories).abs()) {
      best = d;
    }
  }

  // Weight change: latest weigh-in this week vs the latest one before or at the week start.
  double? change;
  final sorted = [...weights]..sort((a, b) => a.date.compareTo(b.date));
  final inWindow = sorted.where((w) => w.date.compareTo(startKey) >= 0 && w.date.compareTo(endKey) <= 0).toList();
  final before = sorted.where((w) => w.date.compareTo(startKey) < 0).toList();
  if (inWindow.isNotEmpty) {
    final baseline = before.isNotEmpty ? before.last : (inWindow.length > 1 ? inWindow.first : null);
    if (baseline != null) change = inWindow.last.kg - baseline.kg;
  }

  return WeeklyReport(
    days: days,
    average: averageOfLogged(days),
    daysLogged: logged.length,
    daysOnTarget: logged.where(onTarget).length,
    goal: goals.calories,
    topFoods: topFoods(inWeek),
    weightChangeKg: change,
    bestDay: best,
  );
}
