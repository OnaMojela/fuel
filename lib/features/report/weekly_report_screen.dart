import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../../state/providers.dart';

/// Seven-day summary ending today (or an earlier week via the arrows).
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  int _weeksBack = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final today = DateUtils.dateOnly(DateTime.now());
    final end = today.subtract(Duration(days: 7 * _weeksBack));
    final start = end.subtract(const Duration(days: 6));
    // Enough history to cover the selected week.
    final entries = ref.watch(historyProvider(7 * (_weeksBack + 1))).value ?? const <Entry>[];
    final weights = ref.watch(weightsProvider).value ?? const <WeightEntry>[];
    final goals = ref.watch(goalsProvider);
    final r = weeklyReport(entries: entries, weights: weights, goals: goals, end: end);
    final range = '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';

    return NScaffold(
      title: 'Weekly report',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(children: [
            IconButton(onPressed: () => setState(() => _weeksBack++), icon: Icon(Icons.chevron_left, color: t.ink)),
            Expanded(child: Center(child: Text(range.toUpperCase(), style: NType.mono(12, t.ink, weight: FontWeight.w700)))),
            IconButton(
              onPressed: _weeksBack == 0 ? null : () => setState(() => _weeksBack--),
              icon: Icon(Icons.chevron_right, color: _weeksBack == 0 ? t.track : t.ink),
            ),
          ]),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Text(_summary(r, ref.watch(displayNameProvider)), style: NType.serif(20, t.ink)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _stat(context, r.daysLogged == 0 ? '—' : fmt(r.average.calories), 'Avg kcal / day')),
            const SizedBox(width: 8),
            Expanded(child: _stat(context, '${r.daysLogged}/7', 'Days logged')),
            const SizedBox(width: 8),
            Expanded(child: _stat(context, '${r.daysOnTarget}', 'On target ±10%')),
          ]),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Label('Day by day'),
              const SizedBox(height: 12),
              for (final d in r.days)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(width: 44, child: Text(DateFormat('E').format(d.date).toUpperCase(), style: NType.mono(10, t.ink))),
                    Expanded(child: DotBar(value: r.goal == 0 ? 0 : d.nutrients.calories / r.goal, dots: 20)),
                    SizedBox(
                      width: 64,
                      child: Shrink(
                        Text(d.logged ? fmt(d.nutrients.calories) : '—', style: NType.mono(11, t.ink, weight: FontWeight.w700)),
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ]),
                ),
              Text('Full row = your ${fmt(r.goal)} kcal goal. Red = over it.', style: NType.serif(14, t.inkMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          if (r.daysLogged > 0)
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Label('Average macros'),
                const SizedBox(height: 10),
                _macro(context, 'Carbs', r.average.carbs, goals.carbsG),
                _macro(context, 'Protein', r.average.protein, goals.proteinG),
                _macro(context, 'Fat', r.average.fat, goals.fatG),
                _macro(context, 'Fiber', r.average.fiber, goals.fiberTargetG),
              ]),
            ),
          if (r.topFoods.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Label('Top foods by calories'),
                const SizedBox(height: 10),
                for (final f in r.topFoods)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(f.name, style: NType.mono(12, t.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text('${f.times}× · ${fmt(f.calories)} KCAL', style: NType.mono(10, t.inkMuted)),
                    ]),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// Plain-language summary of the week.
  static String _summary(WeeklyReport r, String name) {
    if (r.daysLogged == 0) return name.isEmpty ? 'Nothing logged this week yet.' : 'Nothing logged this week yet, $name.';
    final avg = r.average.calories;
    final diff = avg - r.goal;
    final vs = diff.abs() <= r.goal * 0.05
        ? 'right on your goal'
        : '${fmt(diff.abs())} ${diff > 0 ? 'over' : 'under'} your goal';
    final parts = <String>[
      '${name.isEmpty ? 'You' : '$name, you'} logged ${r.daysLogged} of 7 days and averaged ${fmt(avg)} kcal, $vs.',
      if (r.bestDay != null) 'Closest to target: ${DateFormat('EEEE').format(r.bestDay!.date)}.',
      if (r.weightChangeKg != null)
        r.weightChangeKg!.abs() < 0.05
            ? 'Your weight held steady.'
            : 'Weight ${r.weightChangeKg! < 0 ? 'down' : 'up'} ${r.weightChangeKg!.abs().toStringAsFixed(1)} kg.',
    ];
    return parts.join(' ');
  }

  Widget _stat(BuildContext context, String value, String label) {
    final t = context.tk;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Shrink(Text(value, style: NType.dot(26, t.ink))),
        const SizedBox(height: 4),
        Shrink(Label(label, size: 8)),
      ]),
    );
  }

  Widget _macro(BuildContext context, String label, double g, double goal) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Shrink(Label(label, color: t.ink, size: 10))),
          Flexible(child: Shrink(Text('${fmt(g)} / ${fmt(goal)} G', style: NType.mono(10, t.inkMuted)), alignment: Alignment.centerRight)),
        ]),
        const SizedBox(height: 5),
        DotBar(value: goal == 0 ? 0 : g / goal, dots: 24),
      ]),
    );
  }
}
