import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/date_switcher.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../domain/stats.dart';
import '../../state/providers.dart';

/// A nutrient row: total vs a goal that is either a limit (stay under) or a
/// target (reach it).
class _Nutrient {
  const _Nutrient(this.label, this.value, this.goal, this.unit, {this.limit = true});
  final String label, unit;
  final double value, goal;
  final bool limit;
}

/// Full daily breakdown: calories per meal, every tracked nutrient vs its goal,
/// and the foods that contributed most.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final goals = ref.watch(goalsProvider);
    final entries = ref.watch(diaryProvider).value ?? const <Entry>[];
    final n = sumEntries(entries);

    final nutrients = [
      _Nutrient('Calories', n.calories, goals.calories, 'kcal'),
      _Nutrient('Protein', n.protein, goals.proteinG, 'g', limit: false),
      _Nutrient('Carbohydrates', n.carbs, goals.carbsG, 'g'),
      _Nutrient('Fiber', n.fiber, goals.fiberTargetG, 'g', limit: false),
      _Nutrient('Sugar', n.sugar, goals.sugarLimitG, 'g'),
      _Nutrient('Fat', n.fat, goals.fatG, 'g'),
      _Nutrient('Saturated fat', n.saturatedFat, goals.satFatLimitG, 'g'),
      _Nutrient('Cholesterol', n.cholesterol, goals.cholesterolLimitMg, 'mg'),
      _Nutrient('Sodium', n.sodium, goals.sodiumLimitMg, 'mg'),
      _Nutrient('Potassium', n.potassium, goals.potassiumTargetMg, 'mg', limit: false),
    ];

    return NScaffold(
      title: 'Nutrition',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const DateSwitcher(),
          // Calories by meal
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Label('Calories by meal'),
              const SizedBox(height: 14),
              for (final m in Meal.values) ...[
                () {
                  final kcal = sumEntries(entries.where((e) => e.meal == m)).calories;
                  final share = n.calories == 0 ? 0.0 : kcal / n.calories;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Shrink(Label(m.label, color: t.ink, size: 10))),
                        Flexible(
                          child: Shrink(Text('${fmt(kcal)} KCAL · ${fmt(share * 100)}%', style: NType.mono(10, t.inkMuted)),
                              alignment: Alignment.centerRight),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      DotBar(value: share, dots: 24),
                    ]),
                  );
                }(),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          // Every nutrient vs goal
          GlassCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Label('Nutrient')),
                SizedBox(width: 70, child: Text('TOTAL', textAlign: TextAlign.right, style: NType.mono(9, t.inkMuted))),
                SizedBox(width: 70, child: Text('GOAL', textAlign: TextAlign.right, style: NType.mono(9, t.inkMuted))),
                SizedBox(width: 64, child: Text('LEFT', textAlign: TextAlign.right, style: NType.mono(9, t.inkMuted))),
              ]),
              const SizedBox(height: 8),
              for (final x in nutrients) _row(context, x),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            'Limits (stay under): sugar ≤10% of calories, saturated fat ≤10%, sodium 2300 mg, cholesterol 300 mg. '
            'Targets (reach): protein, fiber 14 g per 1000 kcal, potassium 3500 mg.',
            style: NType.serif(14, t.inkMuted),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Label('Biggest contributors'),
              const SizedBox(height: 10),
              if (entries.isEmpty) Text('Nothing logged on this day.', style: NType.serif(16, t.inkMuted)),
              for (final f in topFoods(entries))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(f.name, style: NType.mono(12, t.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text('${fmt(f.calories)} KCAL', style: NType.mono(11, t.inkMuted)),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _Nutrient x) {
    final t = context.tk;
    final left = x.goal - x.value;
    // Red only when a limit is exceeded; a target can't be "over".
    final bad = x.limit && left < 0;
    String num(double v) => fmt(v, digits: x.unit == 'g' && v.abs() < 10 ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Shrink(Text(x.label, style: NType.mono(11, t.ink)))),
          SizedBox(width: 70, child: Shrink(Text(num(x.value), style: NType.mono(11, t.ink, weight: FontWeight.w700)), alignment: Alignment.centerRight)),
          SizedBox(width: 70, child: Shrink(Text('${num(x.goal)} ${x.unit}', style: NType.mono(11, t.inkMuted)), alignment: Alignment.centerRight)),
          SizedBox(
            width: 64,
            child: Shrink(
              Text(
                !x.limit && left <= 0 ? 'DONE' : (bad ? '+${num(-left)}' : num(left)),
                style: NType.mono(11, bad ? t.accent : t.inkMuted, weight: bad ? FontWeight.w700 : FontWeight.w400),
              ),
              alignment: Alignment.centerRight,
            ),
          ),
        ]),
        const SizedBox(height: 5),
        DotBar(value: x.goal == 0 ? 0 : (x.limit ? x.value / x.goal : (x.value / x.goal).clamp(0.0, 1.0)), dots: 24),
      ]),
    );
  }
}
