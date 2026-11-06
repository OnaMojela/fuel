import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../domain/nutrition.dart';
import '../../state/providers.dart';

class FoodDetailArgs {
  const FoodDetailArgs({required this.food, required this.meal, this.entry});
  final Food food;
  final Meal meal;
  final Entry? entry; // set when editing an existing log entry
}

class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({super.key, required this.args});
  final FoodDetailArgs args;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  late final List<Serving> _servings;
  late Serving _serving;
  late Meal _meal = widget.args.meal;
  late final _qty = TextEditingController();

  Food get food => widget.args.food;
  Entry? get entry => widget.args.entry;

  @override
  void initState() {
    super.initState();
    _servings = [...food.allServings];
    final e = entry;
    if (e != null) {
      _serving = _servings.firstWhere(
        (s) => s.label == e.servingLabel && s.grams == e.servingGrams,
        orElse: () {
          final s = Serving(e.servingLabel, e.servingGrams);
          _servings.insert(0, s);
          return s;
        },
      );
      _qty.text = _trim(e.quantity);
    } else {
      _serving = _servings.first;
      _qty.text = _serving.label == 'g' ? '100' : '1';
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double get _quantity => double.tryParse(_qty.text.replaceAll(',', '.')) ?? 0;
  double get _grams => _serving.grams * _quantity;

  Future<void> _save() async {
    final actions = ref.read(diaryActionsProvider);
    final e = entry;
    final newEntry = Entry(
      id: e?.id,
      date: e?.date ?? dateKey(ref.read(selectedDateProvider)),
      meal: _meal,
      food: food,
      servingLabel: _serving.label,
      servingGrams: _serving.grams,
      quantity: _quantity,
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    if (e == null) {
      await actions.add(newEntry);
    } else {
      await actions.update(newEntry);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${e == null ? 'Added to' : 'Updated in'} ${_meal.label}')),
    );
    context.go('/log');
  }

  Future<void> _delete() async {
    await ref.read(diaryActionsProvider).delete(entry!.id!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final n = food.forGrams(_grams);
    final split = macroSplit(n);
    final goals = ref.watch(goalsProvider);

    return NScaffold(
      title: entry == null ? 'Add food' : 'Edit entry',
      actions: [
        if (entry != null) IconButton(onPressed: _delete, icon: Icon(Icons.delete_outline, color: t.ink)),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Text(food.name, style: NType.serif(30, t.ink)),
                if (food.brand != null) ...[
                  const SizedBox(height: 4),
                  Label(food.brand!),
                ],
                const SizedBox(height: 16),

                // Serving + quantity + meal
                GlassCard(
                  child: Column(children: [
                    _row(
                      'Serving size',
                      DropdownButtonHideUnderline(
                        child: DropdownButton<Serving>(
                          value: _serving,
                          isDense: true,
                          // Expanded + ellipsis so long serving names can't overflow the row.
                          isExpanded: true,
                          alignment: AlignmentDirectional.centerEnd,
                          style: NType.mono(12, t.ink),
                          dropdownColor: t.canvas,
                          selectedItemBuilder: (_) => [
                            for (final s in _servings)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          items: [
                            for (final s in _servings)
                              DropdownMenuItem(value: s, child: Text(s.label, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (s) => setState(() {
                            if (s == null) return;
                            // Keep the amount sensible when switching between "g" and a serving.
                            if (s.label == 'g' && _serving.label != 'g') _qty.text = _trim(_grams.roundToDouble());
                            if (s.label != 'g' && _serving.label == 'g') _qty.text = '1';
                            _serving = s;
                          }),
                        ),
                      ),
                    ),
                    Divider(color: t.track, height: 20),
                    _row(
                      _serving.label == 'g' ? 'Grams' : 'Number of servings',
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _qty,
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          style: NType.mono(14, t.ink, weight: FontWeight.w700),
                          decoration: InputDecoration(
                            isDense: true,
                            fillColor: t.tint,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    Divider(color: t.track, height: 20),
                    _row(
                      'Meal',
                      DropdownButtonHideUnderline(
                        child: DropdownButton<Meal>(
                          value: _meal,
                          isDense: true,
                          isExpanded: true,
                          selectedItemBuilder: (_) => [
                            for (final m in Meal.values)
                              Align(alignment: Alignment.centerRight, child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          style: NType.mono(12, t.ink),
                          dropdownColor: t.canvas,
                          items: [for (final m in Meal.values) DropdownMenuItem(value: m, child: Text(m.label))],
                          onChanged: (m) => setState(() => _meal = m ?? _meal),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // Calories + macro split
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(builder: (context, c) => Row(children: [
                    Ring(
                      value: goals.calories == 0 ? 0 : n.calories / goals.calories,
                      size: (c.maxWidth * 0.38).clamp(80.0, 110.0),
                      stroke: 6,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(fmt(n.calories), style: NType.dot(30, t.ink)),
                        const Label('kcal', size: 9),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(children: [
                        _macro('Carbs', n.carbs, split.carbs),
                        _macro('Fat', n.fat, split.fat),
                        _macro('Protein', n.protein, split.protein),
                      ]),
                    ),
                  ])),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${fmt(goals.calories == 0 ? 0 : n.calories / goals.calories * 100)}% OF DAILY GOAL',
                      style: NType.mono(9, t.inkMuted)),
                ),
                const SizedBox(height: 12),

                // Full nutrition facts
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Label('Nutrition facts'),
                    const SizedBox(height: 4),
                    Text('For ${fmt(_grams)} g', style: NType.serif(15, t.inkMuted)),
                    const SizedBox(height: 10),
                    _fact('Calories', n.calories, 'kcal', bold: true),
                    _fact('Total fat', n.fat, 'g', bold: true),
                    _fact('Saturated fat', n.saturatedFat, 'g', indent: true),
                    _fact('Cholesterol', n.cholesterol, 'mg', bold: true),
                    _fact('Sodium', n.sodium, 'mg', bold: true),
                    _fact('Potassium', n.potassium, 'mg', bold: true),
                    _fact('Total carbohydrates', n.carbs, 'g', bold: true),
                    _fact('Dietary fiber', n.fiber, 'g', indent: true),
                    _fact('Sugars', n.sugar, 'g', indent: true),
                    _fact('Protein', n.protein, 'g', bold: true),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: BlackButton(
              label: entry == null ? 'Add to ${_meal.label}' : 'Save changes',
              onPressed: _quantity > 0 ? _save : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget trailing) => Row(children: [
        Expanded(child: Shrink(Label(label, color: context.tk.ink, size: 10))),
        Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
      ]);

  Widget _macro(String label, double grams, double share) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Shrink(Label(label, color: t.ink, size: 10))),
          const SizedBox(width: 4),
          Flexible(
            flex: 2,
            child: Shrink(Text('${fmt(grams, digits: 1)} G · ${fmt(share * 100)}%', style: NType.mono(10, t.inkMuted)),
                alignment: Alignment.centerRight),
          ),
        ]),
        const SizedBox(height: 4),
        DotBar(value: share, dots: 16),
      ]),
    );
  }

  Widget _fact(String label, double v, String unit, {bool bold = false, bool indent = false}) {
    final t = context.tk;
    final w = bold ? FontWeight.w700 : FontWeight.w400;
    return Container(
      padding: EdgeInsets.fromLTRB(indent ? 16 : 0, 8, 0, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.track))),
      child: Row(children: [
        Expanded(child: Text(label, style: NType.mono(12, t.ink, weight: w))),
        Text('${fmt(v, digits: unit == 'g' ? 1 : 0)} $unit', style: NType.mono(12, t.ink, weight: w)),
      ]),
    );
  }
}
