import 'models.dart';
import 'ui_prefs.dart';

class HeroStat {
  const HeroStat(this.label, this.value);
  final String label;
  final String value;
}

/// Everything the Today page's hero ring shows for the chosen [HeroMetric].
class HeroView {
  const HeroView({
    required this.title,
    required this.formula,
    required this.value,
    required this.label,
    required this.progress,
    required this.alarm,
    required this.overIsBad,
    required this.stats,
  });
  final String title; // card label
  final String formula; // small serif explainer
  final double value; // big number
  final String label; // under the number
  final double progress; // ring fill, 1 = goal
  final bool alarm; // show the number in red (over a limit)
  final bool overIsBad; // ring turns red past 1 (not for targets like protein)
  final List<HeroStat> stats; // two side stats
}

String _n(double v) => v.round().toString();

HeroView heroView(HeroMetric m, Nutrients n, Goals g) {
  double ratio(double a, double b) => b == 0 ? 0 : a / b;
  switch (m) {
    case HeroMetric.caloriesLeft:
      final left = g.calories - n.calories;
      return HeroView(
        title: 'Calories',
        formula: 'Remaining = Goal − Food',
        value: left.abs(),
        label: left < 0 ? 'Over' : 'Remaining',
        progress: ratio(n.calories, g.calories),
        alarm: left < 0,
        overIsBad: true,
        stats: [HeroStat('Base goal', _n(g.calories)), HeroStat('Food', _n(n.calories))],
      );
    case HeroMetric.caloriesEaten:
      final left = g.calories - n.calories;
      return HeroView(
        title: 'Calories',
        formula: 'Eaten so far today',
        value: n.calories,
        label: 'Eaten',
        progress: ratio(n.calories, g.calories),
        alarm: left < 0,
        overIsBad: true,
        stats: [HeroStat('Goal', _n(g.calories)), HeroStat(left < 0 ? 'Over' : 'Left', _n(left.abs()))],
      );
    case HeroMetric.proteinLeft:
      final left = g.proteinG - n.protein;
      return HeroView(
        title: 'Protein',
        formula: 'Left = Target − Eaten',
        value: left.abs(),
        label: left <= 0 ? 'G above target' : 'G left',
        progress: ratio(n.protein, g.proteinG),
        alarm: false, // more protein than the target isn't a problem
        overIsBad: false,
        stats: [HeroStat('Target', '${_n(g.proteinG)} G'), HeroStat('Eaten', '${_n(n.protein)} G')],
      );
    case HeroMetric.netCarbs:
      final left = g.netCarbLimitG - n.netCarbs;
      return HeroView(
        title: 'Net carbs',
        formula: 'Carbs − fiber, against your limit',
        value: n.netCarbs,
        label: 'G net carbs',
        progress: ratio(n.netCarbs, g.netCarbLimitG),
        alarm: left < 0,
        overIsBad: true,
        stats: [HeroStat('Limit', '${_n(g.netCarbLimitG)} G'), HeroStat(left < 0 ? 'Over' : 'Left', '${_n(left.abs())} G')],
      );
  }
}
