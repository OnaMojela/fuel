import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/date_switcher.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/hero.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../domain/stats.dart';
import '../../domain/ui_prefs.dart';
import '../../state/providers.dart';
import 'customize_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final goals = ref.watch(goalsProvider);
    final ui = ref.watch(uiPrefsProvider);
    final name = ref.watch(displayNameProvider);
    final entries = ref.watch(diaryProvider).value ?? const <Entry>[];
    final n = sumEntries(entries);

    Widget card(TodayCard c) => switch (c) {
          TodayCard.hero => _HeroCard(view: heroView(ui.hero, n, goals)),
          TodayCard.macros => _MacrosCard(n: n, goals: goals),
          TodayCard.streak => const _StreakCard(),
          TodayCard.weight => const _WeightCard(),
          TodayCard.lowCarb => _LowCarbCard(n: n, goals: goals),
          TodayCard.heartHealthy => _HeartHealthyCard(n: n, goals: goals),
        };

    // Lay out visible cards in the user's order; adjacent half-width cards share a row.
    final visible = ui.visibleCards;
    final rows = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final c = visible[i];
      if (c.half && i + 1 < visible.length && visible[i + 1].half) {
        // (No IntrinsicHeight: DotBar uses LayoutBuilder, which can't report intrinsic sizes.)
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: card(c)),
          const SizedBox(width: 12),
          Expanded(child: card(visible[i + 1])),
        ]));
        i++;
      } else {
        rows.add(card(c));
      }
    }

    return NScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavClearance),
        children: [
          Row(
            children: [
              Text('fuel', style: NType.dot(34, t.ink)),
              const Spacer(),
              _Badge(
                key: const ValueKey('personal-badge'),
                name: name,
                progress: goals.calories == 0 ? 0 : n.calories / goals.calories,
                onTap: () => showCustomizeSheet(context),
              ),
            ],
          ),
          Text('${greeting(name)}.', style: NType.serif(20, t.inkMuted)),
          const DateSwitcher(),
          if (!goals.isSet) ...[
            GlassCard(
              onTap: () => context.push('/goals'),
              child: Row(children: [
                Expanded(child: Text('Set your goals to get a personal calorie target.', style: NType.serif(18, t.ink))),
                Icon(Icons.arrow_forward, color: t.ink),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          if (rows.isEmpty)
            GlassCard(
              onTap: () => showCustomizeSheet(context),
              child: Text('All cards are hidden. Tap here (or your badge) to choose what shows.',
                  style: NType.serif(18, t.inkMuted)),
            ),
          for (final r in rows) ...[r, const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

/// Top-right personal badge: your initial inside a ring of dots that fills as
/// you eat toward today's calorie goal. Opens the "Make it yours" panel.
class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.name, required this.progress, required this.onTap});
  final String name;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final initial = name.isEmpty ? '·' : name.characters.first.toUpperCase();
    return Semantics(
      button: true,
      label: 'Personalise',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(
            painter: _BadgeDots(progress, t.detail(t.ink), t.track),
            child: Center(child: Text(initial, style: NType.dot(20, t.ink))),
          ),
        ),
      ),
    );
  }
}

class _BadgeDots extends CustomPainter {
  _BadgeDots(this.progress, this.on, this.off);
  final double progress;
  final Color on, off;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 20;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final filled = (progress.clamp(0.0, 1.0) * n).round();
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 2, Paint()..color = i < filled ? on : off);
    }
  }

  @override
  bool shouldRepaint(_BadgeDots o) => o.progress != progress || o.on != on || o.off != off;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.view});
  final HeroView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = view;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(v.title),
          Text(v.formula, style: NType.serif(15, t.inkMuted)),
          const SizedBox(height: 16),
          // Ring shrinks on narrow phones so the stats beside it always fit.
          LayoutBuilder(
            builder: (context, c) => Row(
              children: [
                Ring(
                  value: v.progress,
                  size: (c.maxWidth * 0.55).clamp(100.0, 150.0),
                  stroke: 8,
                  accent: true,
                  overIsBad: v.overIsBad,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmt(v.value), style: NType.dot(40, v.alarm ? t.accent : t.ink)),
                      const SizedBox(height: 4),
                      Label(v.label, size: 10, color: v.alarm ? t.accent : null),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stat(context, Icons.flag_outlined, v.stats[0]),
                      const SizedBox(height: 14),
                      _stat(context, Icons.restaurant, v.stats[1]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, HeroStat s) {
    final t = context.tk;
    return Row(children: [
      Icon(icon, size: 18, color: t.inkMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Shrink(Label(s.label, size: 10)),
          Shrink(Text(s.value, style: NType.mono(16, t.ink, weight: FontWeight.w700))),
        ]),
      ),
    ]);
  }
}

/// Days-in-a-row plus a 7-dot strip of the last week (filled = logged).
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final entries = ref.watch(historyProvider(366)).value ?? const <Entry>[];
    final logged = {for (final e in entries) e.date};
    final today = DateUtils.dateOnly(DateTime.now());
    final streak = loggingStreak(logged, today);
    return GlassCard(
      onTap: () => context.go('/progress'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Label('Streak'),
        const SizedBox(height: 10),
        Shrink(Text.rich(TextSpan(children: [
          TextSpan(text: '$streak', style: NType.dot(32, streak > 0 ? t.detail(t.ink) : t.ink)),
          TextSpan(text: streak == 1 ? '  DAY' : '  DAYS', style: NType.mono(10, t.inkMuted)),
        ]))),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var ago = 6; ago >= 0; ago--)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: logged.contains(dateKey(today.subtract(Duration(days: ago)))) ? t.ink : t.track,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Last 7 days', style: NType.mono(9, t.inkMuted)),
      ]),
    );
  }
}

/// Latest weigh-in and the change over 30 days. Tap for the full chart.
class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final weights = ref.watch(weightsProvider).value ?? const <WeightEntry>[];
    final latest = weights.isEmpty ? null : weights.last;
    final monthAgo = dateKey(DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 30)));
    final before = weights.where((w) => w.date.compareTo(monthAgo) <= 0).toList();
    final base = before.isNotEmpty ? before.last : (weights.length > 1 ? weights.first : null);
    final change = (latest != null && base != null && base != latest) ? latest.kg - base.kg : null;
    return GlassCard(
      onTap: () => context.go('/progress'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Label('Weight'),
        const SizedBox(height: 10),
        Shrink(Text.rich(TextSpan(children: [
          TextSpan(text: latest == null ? '—' : latest.kg.toStringAsFixed(1), style: NType.dot(32, t.ink)),
          TextSpan(text: '  KG', style: NType.mono(10, t.inkMuted)),
        ]))),
        const SizedBox(height: 12),
        Text(
          latest == null
              ? 'Tap to log your first weigh-in.'
              : change == null
                  ? 'Log more to see a trend.'
                  : '${change > 0 ? '+' : change < 0 ? '−' : '±'}${change.abs().toStringAsFixed(1)} kg in 30 days',
          style: NType.serif(14, t.inkMuted),
        ),
      ]),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.n, required this.goals});
  final Nutrients n;
  final Goals goals;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('Macros'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _macro(context, 'Carbs', n.carbs, goals.carbsG)),
              const SizedBox(width: 8),
              Expanded(child: _macro(context, 'Protein', n.protein, goals.proteinG)),
              const SizedBox(width: 8),
              Expanded(child: _macro(context, 'Fat', n.fat, goals.fatG)),
            ],
          ),
        ],
      ),
    );
  }

  /// One macro column; the ring fits the column width (max 84) on narrow phones.
  Widget _macro(BuildContext context, String label, double eaten, double goal) {
    final t = context.tk;
    final left = goal - eaten;
    return LayoutBuilder(
      builder: (context, c) => Column(children: [
        Ring(
          value: goal == 0 ? 0 : eaten / goal,
          size: c.maxWidth.clamp(0.0, 84.0),
          stroke: 5,
          child: Text(fmt(eaten), style: NType.dot(24, eaten > goal ? t.accent : t.ink)),
        ),
        const SizedBox(height: 8),
        Shrink(Label(label, color: t.ink, size: 10), alignment: Alignment.center),
        Shrink(Text('/${fmt(goal)} G', style: NType.mono(10, t.inkMuted)), alignment: Alignment.center),
        Shrink(
          Text(left >= 0 ? '${fmt(left)} G LEFT' : '${fmt(-left)} G OVER',
              style: NType.mono(9, left >= 0 ? t.inkMuted : t.accent)),
          alignment: Alignment.center,
        ),
      ]),
    );
  }
}

class _LowCarbCard extends StatelessWidget {
  const _LowCarbCard({required this.n, required this.goals});
  final Nutrients n;
  final Goals goals;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('Low carb'),
          const SizedBox(height: 10),
          Shrink(Text(fmt(n.netCarbs), style: NType.dot(32, t.ink))),
          Text('/ ${fmt(goals.netCarbLimitG)} g net carbs', style: NType.serif(14, t.inkMuted)),
          const SizedBox(height: 12),
          DotBar(value: n.netCarbs / goals.netCarbLimitG, dots: 12),
          const SizedBox(height: 10),
          Text('Net carbs = carbs − fiber', style: NType.mono(9, t.inkMuted)),
        ],
      ),
    );
  }
}

class _HeartHealthyCard extends StatelessWidget {
  const _HeartHealthyCard({required this.n, required this.goals});
  final Nutrients n;
  final Goals goals;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('Heart healthy'),
          const SizedBox(height: 12),
          _row(context, 'Sat. fat', n.saturatedFat, goals.satFatLimitG, 'g'),
          _row(context, 'Sodium', n.sodium, goals.sodiumLimitMg, 'mg'),
          _row(context, 'Fiber', n.fiber, goals.fiberTargetG, 'g'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double v, double goal, String unit) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Shrink(Label(label, color: t.ink, size: 9))),
          const SizedBox(width: 4),
          Flexible(
            child: Shrink(Text('${fmt(v)}/${fmt(goal)}$unit', style: NType.mono(9, t.inkMuted)), alignment: Alignment.centerRight),
          ),
        ]),
        const SizedBox(height: 5),
        DotBar(value: goal == 0 ? 0 : v / goal, dots: 12),
      ]),
    );
  }
}
