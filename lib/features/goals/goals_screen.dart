import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../state/providers.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late Goals _g = ref.read(goalsProvider);
  late final _age = TextEditingController(text: '${_g.age}');
  late final _height = TextEditingController(text: fmt(_g.heightCm));
  late final _weight = TextEditingController(text: fmt(_g.weightKg, digits: 1));
  late final _custom = TextEditingController();

  static final _activities = <double, String>{
    1.2: 'Not very active',
    1.375: 'Lightly active',
    1.55: 'Active',
    1.725: 'Very active',
  };
  static final _rates = <double, String>{
    -0.75: 'Lose 0.75 kg / week',
    -0.5: 'Lose 0.5 kg / week',
    -0.25: 'Lose 0.25 kg / week',
    0.0: 'Maintain weight',
    0.25: 'Gain 0.25 kg / week',
    0.5: 'Gain 0.5 kg / week',
  };

  @override
  void initState() {
    super.initState();
    // Show the custom field pre-filled only if the saved target differs from the formula.
    if (_g.isSet && _g.calories != recommendedCalories(_g)) _custom.text = fmt(_g.calories);
  }

  @override
  void dispose() {
    for (final c in [_age, _height, _weight, _custom]) {
      c.dispose();
    }
    super.dispose();
  }

  Goals get _draft => _g.copyWith(
        age: int.tryParse(_age.text) ?? _g.age,
        heightCm: double.tryParse(_height.text) ?? _g.heightCm,
        weightKg: double.tryParse(_weight.text.replaceAll(',', '.')) ?? _g.weightKg,
      );

  double get _target {
    final custom = double.tryParse(_custom.text);
    return custom != null && custom > 0 ? custom : recommendedCalories(_draft);
  }

  void _bump(String macro, double delta) {
    setState(() {
      // Move 5% between the chosen macro and the others, keeping a 100% total.
      final vals = {'c': _g.carbPct, 'p': _g.proteinPct, 'f': _g.fatPct};
      final next = (vals[macro]! + delta).clamp(5.0, 90.0);
      final change = next - vals[macro]!;
      if (change == 0) return;
      vals[macro] = next;
      final others = vals.keys.where((k) => k != macro).toList()..sort((a, b) => vals[b]!.compareTo(vals[a]!));
      final take = change > 0 ? others.first : others.last;
      vals[take] = vals[take]! - change;
      if (vals[take]! < 5) return;
      _g = _g.copyWith(carbPct: vals['c'], proteinPct: vals['p'], fatPct: vals['f']);
    });
  }

  Future<void> _save() async {
    await ref.read(goalsProvider.notifier).save(_draft.copyWith(calories: _target, isSet: true));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final target = _target;
    return NScaffold(
      title: 'Goals',
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Label('Daily calorie goal'),
                  const SizedBox(height: 8),
                  Text(fmt(target), style: NType.dot(56, t.ink)),
                  const SizedBox(height: 4),
                  Text('C ${fmt(target * _g.carbPct / 400)}g · P ${fmt(target * _g.proteinPct / 400)}g · F ${fmt(target * _g.fatPct / 900)}g',
                      style: NType.mono(11, t.inkMuted)),
                ]),
              ),
              const SizedBox(height: 16),
              const Label('About you'),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(children: [
                  Row(children: [
                    for (final s in ['female', 'male'])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: s == 'female' ? 8 : 0),
                          child: _Toggle(
                            label: s,
                            selected: _g.sex == s,
                            onTap: () => setState(() => _g = _g.copyWith(sex: s)),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _numField('Age', _age)),
                    const SizedBox(width: 8),
                    Expanded(child: _numField('Height cm', _height)),
                    const SizedBox(width: 8),
                    Expanded(child: _numField('Weight kg', _weight, decimal: true)),
                  ]),
                  const SizedBox(height: 12),
                  _dropdown<double>('Activity', _g.activity, _activities, (v) => _g = _g.copyWith(activity: v)),
                  const SizedBox(height: 8),
                  _dropdown<double>('Goal', _g.weeklyChangeKg, _rates, (v) => _g = _g.copyWith(weeklyChangeKg: v)),
                ]),
              ),
              const SizedBox(height: 16),
              const Label('Macro split (% of calories)'),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(children: [
                  _macroRow('Carbs', 'c', _g.carbPct),
                  _macroRow('Protein', 'p', _g.proteinPct),
                  _macroRow('Fat', 'f', _g.fatPct),
                ]),
              ),
              const SizedBox(height: 16),
              const Label('Custom calorie goal (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _custom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: NType.mono(14, t.ink),
                decoration: InputDecoration(hintText: 'Use recommended: ${fmt(recommendedCalories(_draft))}'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BlackButton(label: 'Save goals', onPressed: _save),
        ),
      ]),
    );
  }

  Widget _numField(String label, TextEditingController c, {bool decimal = false}) {
    final t = context.tk;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Label(label, size: 9),
      const SizedBox(height: 4),
      TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: NType.mono(14, t.ink, weight: FontWeight.w700),
        decoration: InputDecoration(isDense: true, fillColor: t.tint),
        onChanged: (_) => setState(() {}),
      ),
    ]);
  }

  Widget _dropdown<T>(String label, T value, Map<T, String> options, void Function(T) set) {
    final t = context.tk;
    return Row(children: [
      Label(label, color: t.ink, size: 10),
      const SizedBox(width: 12),
      // Takes the remaining width and ellipsizes long options on narrow phones.
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            style: NType.mono(12, t.ink),
            dropdownColor: t.canvas,
            selectedItemBuilder: (_) => [
              for (final e in options.entries)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() {
              if (v != null) set(v);
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _macroRow(String label, String key, double pct) {
    final t = context.tk;
    return Row(children: [
      Expanded(child: Label(label, color: t.ink, size: 11)),
      IconButton(onPressed: () => _bump(key, -5), icon: Icon(Icons.remove, color: t.ink, size: 18)),
      SizedBox(width: 48, child: Text('${fmt(pct)}%', textAlign: TextAlign.center, style: NType.dot(20, t.ink))),
      IconButton(onPressed: () => _bump(key, 5), icon: Icon(Icons.add, color: t.ink, size: 18)),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? t.cta : t.tint, borderRadius: BorderRadius.circular(6)),
        child: Text(label.toUpperCase(), style: NType.mono(12, selected ? t.onCta : t.ink)),
      ),
    );
  }
}
