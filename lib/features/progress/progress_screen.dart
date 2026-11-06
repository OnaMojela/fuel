import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../domain/stats.dart';
import '../../state/providers.dart';

/// Weight trend, calorie history, macro averages and the logging streak.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final goals = ref.watch(goalsProvider);
    final entries = ref.watch(historyProvider(_days)).value ?? const <Entry>[];
    // Streak looks further back than the chart range.
    final streakEntries = ref.watch(historyProvider(366)).value ?? const <Entry>[];
    final weights = ref.watch(weightsProvider).value ?? const <WeightEntry>[];

    final today = DateUtils.dateOnly(DateTime.now());
    final days = dailyTotals(entries, today.subtract(Duration(days: _days - 1)), today);
    final avg = averageOfLogged(days);
    final streak = loggingStreak({for (final e in streakEntries) e.date}, today);

    return NScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavClearance),
        children: [
          Row(children: [
            Expanded(child: Text('progress', style: NType.dot(34, t.ink))),
            _StreakChip(streak),
          ]),
          const SizedBox(height: 16),
          _RangePicker(value: _days, onChanged: (d) => setState(() => _days = d)),
          const SizedBox(height: 12),
          _WeightCard(weights: weights, days: _days),
          const SizedBox(height: 12),
          _CaloriesCard(days: days, goal: goals.calories, average: avg.calories),
          const SizedBox(height: 12),
          _MacroAverages(avg: avg, goals: goals, loggedDays: days.where((d) => d.logged).length),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip(this.days);
  final int days;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: days > 0 ? t.cta : t.glass, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$days', style: NType.dot(22, days > 0 ? t.detail(t.onCta) : t.ink)),
        const SizedBox(width: 8),
        Text(days == 1 ? 'DAY\nSTREAK' : 'DAYS\nSTREAK', style: NType.mono(8, days > 0 ? t.onCta : t.inkMuted)),
      ]),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(children: [
      for (final d in const [7, 30, 90])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d == 90 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: d == value ? t.cta : t.glass, borderRadius: BorderRadius.circular(6)),
                child: Text('${d}D', style: NType.mono(11, d == value ? t.onCta : t.ink, weight: FontWeight.w700)),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ---------- Weight ----------

class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.weights, required this.days});
  final List<WeightEntry> weights;
  final int days;

  Future<void> _logWeight(BuildContext context, WidgetRef ref) async {
    final last = weights.isEmpty ? ref.read(goalsProvider).weightKg : weights.last.kg;
    final kg = await showDialog<double>(context: context, builder: (_) => _WeightDialog(initial: last));
    if (kg != null) await ref.read(weightActionsProvider).log(kg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final today = DateUtils.dateOnly(DateTime.now());
    final fromKey = dateKey(today.subtract(Duration(days: days - 1)));
    final inRange = weights.where((w) => w.date.compareTo(fromKey) >= 0).toList();
    final latest = weights.isEmpty ? null : weights.last;
    // Change across the range: compare with the last weigh-in before it, if any.
    final before = weights.where((w) => w.date.compareTo(fromKey) < 0).toList();
    final base = before.isNotEmpty ? before.last : (inRange.length > 1 ? inRange.first : null);
    final change = (latest != null && base != null && inRange.isNotEmpty) ? latest.kg - base.kg : null;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Label('Weight')),
          if (change != null)
            Text(
              '${change > 0 ? '+' : change < 0 ? '−' : '±'}${change.abs().toStringAsFixed(1)} KG IN ${days}D',
              style: NType.mono(10, t.inkMuted),
            ),
        ]),
        const SizedBox(height: 8),
        Shrink(Text.rich(TextSpan(children: [
          TextSpan(text: latest == null ? '—' : latest.kg.toStringAsFixed(1), style: NType.dot(44, t.ink)),
          TextSpan(text: '  KG', style: NType.mono(12, t.inkMuted)),
        ]))),
        if (latest != null)
          Text('Last weigh-in ${DateFormat('d MMM').format(DateTime.parse(latest.date))}', style: NType.serif(15, t.inkMuted)),
        const SizedBox(height: 16),
        if (inRange.length >= 2)
          SizedBox(height: 160, child: _WeightChart(points: inRange, from: today.subtract(Duration(days: days - 1)), days: days))
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              weights.isEmpty ? 'Log your weight to start a trend line.' : 'Log at least two weigh-ins in this range to see a trend.',
              style: NType.serif(16, t.inkMuted),
            ),
          ),
        const SizedBox(height: 12),
        BlackButton(label: 'Log weight', icon: Icons.add, onPressed: () => _logWeight(context, ref)),
      ]),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points, required this.from, required this.days});
  final List<WeightEntry> points;
  final DateTime from;
  final int days;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final spots = [
      for (final w in points) FlSpot(DateTime.parse(w.date).difference(from).inDays.toDouble(), w.kg),
    ];
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final pad = math.max(0.5, (maxY - minY) * 0.2);

    return LineChart(LineChartData(
      minX: 0,
      maxX: (days - 1).toDouble(),
      minY: (minY - pad).floorToDouble(),
      maxY: (maxY + pad).ceilToDouble(),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: t.track, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _titles(context, days, from, leftDigits: 0),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => t.cta,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                '${DateFormat('d MMM').format(from.add(Duration(days: s.x.round())))}\n${s.y.toStringAsFixed(1)} kg',
                NType.mono(11, t.onCta),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: t.ink,
          barWidth: 2,
          isCurved: false,
          dotData: FlDotData(
            // Latest weigh-in gets the accent (red when Nothing red is on).
            getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
              radius: i == spots.length - 1 ? 5 : 4,
              color: i == spots.length - 1 ? t.detail(t.ink) : t.ink,
              strokeWidth: 2,
              strokeColor: t.canvas,
            ),
          ),
        ),
      ],
    ));
  }
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({required this.initial});
  final double initial;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final _c = TextEditingController(text: widget.initial.toStringAsFixed(1));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_c.text.replaceAll(',', '.'));
    return (v == null || v < 20 || v > 400) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AlertDialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text('log weight', style: NType.dot(26, t.ink)),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: NType.mono(20, t.ink, weight: FontWeight.w700),
        decoration: const InputDecoration(suffixText: 'KG'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: NType.mono(11, t.inkMuted))),
        TextButton(
          onPressed: _value == null ? null : () => Navigator.pop(context, _value),
          child: Text('SAVE', style: NType.mono(11, _value == null ? t.inkMuted : t.ink, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ---------- Calories ----------

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.days, required this.goal, required this.average});
  final List<DayTotal> days;
  final double goal, average;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final logged = days.where((d) => d.logged).length;
    final maxCal = days.fold<double>(goal, (m, d) => math.max(m, d.nutrients.calories));
    final barW = days.length <= 7 ? 16.0 : (days.length <= 30 ? 6.0 : 2.0);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Label('Calories'),
        const SizedBox(height: 8),
        Shrink(Text.rich(TextSpan(children: [
          TextSpan(text: logged == 0 ? '—' : fmt(average), style: NType.dot(44, t.ink)),
          TextSpan(text: '  AVG / DAY', style: NType.mono(11, t.inkMuted)),
        ]))),
        Text('$logged of ${days.length} days logged · goal ${fmt(goal)}', style: NType.serif(15, t.inkMuted)),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: BarChart(BarChartData(
            maxY: (maxCal * 1.15 / 500).ceil() * 500,
            minY: 0,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 500,
              getDrawingHorizontalLine: (_) => FlLine(color: t.track, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, days.length, days.first.date, leftDigits: 0, barChart: true),
            // Dashed goal line.
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: goal, color: t.inkMuted, strokeWidth: 1, dashArray: const [4, 4]),
            ]),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => t.cta,
                getTooltipItem: (group, _, rod, _) {
                  final d = days[group.x];
                  final diff = d.nutrients.calories - goal;
                  final status = !d.logged
                      ? 'nothing logged'
                      : diff > goal * 0.10
                          ? '${fmt(diff)} over goal'
                          : diff < -goal * 0.10
                              ? '${fmt(-diff)} under goal'
                              : 'on target';
                  return BarTooltipItem(
                    '${DateFormat('EEE d MMM').format(d.date)}\n${fmt(d.nutrients.calories)} kcal · $status',
                    NType.mono(10, t.onCta),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: days[i].nutrients.calories,
                    width: barW,
                    color: days[i].nutrients.calories > goal * 1.10 ? t.accent : t.ink,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(math.min(4, barW / 2))),
                  ),
                ]),
            ],
          )),
        ),
        const SizedBox(height: 8),
        // Legend wraps onto two lines on very narrow screens.
        Wrap(spacing: 14, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 0, decoration: BoxDecoration(border: Border(top: BorderSide(color: t.inkMuted)))),
            const SizedBox(width: 6),
            Text('GOAL', style: NType.mono(9, t.inkMuted)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text('OVER BY 10%+', style: NType.mono(9, t.inkMuted)),
          ]),
        ]),
      ]),
    );
  }
}

/// Shared, recessive axis labels: a few dates along the bottom, values on the left.
FlTitlesData _titles(BuildContext context, int days, DateTime from, {required int leftDigits, bool barChart = false}) {
  final t = context.tk;
  final every = days <= 7 ? 1 : (days <= 30 ? 7 : 30);
  final fmtDate = days <= 7 ? DateFormat('E') : DateFormat('d/M');
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (v, meta) => (v == meta.max || v == meta.min && !barChart)
            ? const SizedBox.shrink()
            : SideTitleWidget(meta: meta, child: Text(v.toStringAsFixed(leftDigits), style: NType.mono(9, t.inkMuted))),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          // Label every Nth day, counted back from today so "today" is always labelled.
          if ((days - 1 - i) % every != 0) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            child: Text(fmtDate.format(from.add(Duration(days: i))).toUpperCase(), style: NType.mono(8, t.inkMuted)),
          );
        },
      ),
    ),
  );
}

// ---------- Macros ----------

class _MacroAverages extends StatelessWidget {
  const _MacroAverages({required this.avg, required this.goals, required this.loggedDays});
  final Nutrients avg;
  final Goals goals;
  final int loggedDays;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final split = macroSplit(avg);
    Widget row(String label, double g, double goalG, double share, int targetPct) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Shrink(Label(label, color: t.ink, size: 10))),
              Flexible(
                flex: 3,
                child: Shrink(
                  Text('${fmt(g)} / ${fmt(goalG)} G · ${fmt(share * 100)}% (GOAL $targetPct%)', style: NType.mono(10, t.inkMuted)),
                  alignment: Alignment.centerRight,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            DotBar(value: goalG == 0 ? 0 : g / goalG, dots: 24),
          ]),
        );

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Label('Average macros per logged day'),
        const SizedBox(height: 14),
        if (loggedDays == 0)
          Text('Nothing logged in this range yet.', style: NType.serif(16, t.inkMuted))
        else ...[
          row('Carbs', avg.carbs, goals.carbsG, split.carbs, goals.carbPct.round()),
          row('Protein', avg.protein, goals.proteinG, split.protein, goals.proteinPct.round()),
          row('Fat', avg.fat, goals.fatG, split.fat, goals.fatPct.round()),
        ],
      ]),
    );
  }
}
