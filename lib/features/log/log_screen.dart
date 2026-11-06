import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/date_switcher.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../state/providers.dart';
import '../food_detail/food_detail_screen.dart';

/// "Today's Log" — the food diary, grouped by meal.
class LogScreen extends ConsumerWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final goals = ref.watch(goalsProvider);
    final diary = ref.watch(diaryProvider);
    final entries = diary.value ?? const <Entry>[];
    final total = sumEntries(entries).calories;

    return NScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavClearance),
        children: [
          Text("today's log", style: NType.dot(30, t.ink)),
          const DateSwitcher(),
          GlassCard(
            child: Row(
              children: [
                Expanded(child: _sum(context, 'Goal', goals.calories)),
                Text('−', style: NType.mono(16, t.detail(t.inkMuted))),
                Expanded(child: _sum(context, 'Food', total)),
                Text('=', style: NType.mono(16, t.detail(t.inkMuted))),
                Expanded(flex: 2, child: _sum(context, 'Remaining', goals.calories - total, highlight: true)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (diary.isLoading && entries.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else
            for (final meal in Meal.values) ...[
              _MealSection(meal: meal, entries: entries.where((e) => e.meal == meal).toList()),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _sum(BuildContext context, String label, double v, {bool highlight = false}) {
    final t = context.tk;
    return Column(children: [
      Shrink(Text(fmt(v), style: NType.dot(highlight ? 24 : 20, highlight && v < 0 ? t.accent : t.ink)),
          alignment: Alignment.center),
      const SizedBox(height: 2),
      Shrink(Label(label, size: 9), alignment: Alignment.center),
    ]);
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({required this.meal, required this.entries});
  final Meal meal;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final kcal = sumEntries(entries).calories;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Expanded(child: Label(meal.label, color: t.ink, size: 12)),
              Text(fmt(kcal), style: NType.mono(13, t.ink, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 4),
          for (final e in entries)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: t.accent,
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) {
                final actions = ref.read(diaryActionsProvider);
                actions.delete(e.id!);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Removed ${e.food.name}'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => actions.add(Entry(
                      date: e.date,
                      meal: e.meal,
                      food: e.food,
                      servingLabel: e.servingLabel,
                      servingGrams: e.servingGrams,
                      quantity: e.quantity,
                      createdAt: e.createdAt,
                    )),
                  ),
                ));
              },
              child: InkWell(
                onTap: () => context.push('/food', extra: FoodDetailArgs(food: e.food, meal: e.meal, entry: e)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.food.name, style: NType.mono(13, t.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [if (e.food.brand != null) e.food.brand!, e.amountLabel].join(' · '),
                          style: NType.mono(10, t.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(fmt(e.nutrients.calories), style: NType.mono(13, t.ink)),
                    ),
                  ]),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => context.push('/search?meal=${meal.index}'),
            icon: Icon(Icons.add, size: 16, color: t.ink),
            label: Text('ADD FOOD', style: NType.mono(11, t.ink, weight: FontWeight.w700)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}
