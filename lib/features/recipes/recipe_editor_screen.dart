import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class _Row {
  _Row(this.food, double grams) : grams = TextEditingController(text: fmt(grams));
  final Food food;
  final TextEditingController grams;
  double get g => double.tryParse(grams.text.replaceAll(',', '.')) ?? 0;
}

/// Create or edit a recipe: name, servings, ingredients with grams.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipe});
  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late int _servings = widget.recipe?.servings ?? 4;
  late final List<_Row> _rows = [for (final i in widget.recipe?.ingredients ?? const <Ingredient>[]) _Row(i.food, i.grams)];
  final _removed = <_Row>[];

  @override
  void dispose() {
    _name.dispose();
    for (final r in [..._rows, ..._removed]) {
      r.grams.dispose();
    }
    super.dispose();
  }

  Recipe get _draft => Recipe(
        id: widget.recipe?.id,
        name: _name.text.trim(),
        servings: _servings,
        ingredients: [for (final r in _rows) if (r.g > 0) Ingredient(r.food, r.g)],
      );

  Future<void> _addIngredient() async {
    final food = await context.push<Food>('/search?pick=1');
    if (food == null) return;
    // Start from the food's own serving (e.g. "1 cup (250 g)"), else 100 g.
    setState(() => _rows.add(_Row(food, food.allServings.first.grams)));
  }

  Future<void> _save() async {
    await ref.read(recipeActionsProvider).save(_draft);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: c.tk.canvas,
        title: Text('Delete recipe?', style: NType.mono(14, c.tk.ink, weight: FontWeight.w700)),
        content: Text('Entries you already logged from it stay in your diary.', style: NType.serif(16, c.tk.inkMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL', style: NType.mono(11, c.tk.inkMuted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('DELETE', style: NType.mono(11, c.tk.accent, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recipeActionsProvider).delete(widget.recipe!.id!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final d = _draft;
    final s = d.perServing;
    final canSave = d.name.isNotEmpty && d.ingredients.isNotEmpty && _servings > 0;

    return NScaffold(
      title: widget.recipe == null ? 'New recipe' : 'Edit recipe',
      actions: [
        if (widget.recipe != null) IconButton(onPressed: _delete, icon: Icon(Icons.delete_outline, color: t.ink)),
      ],
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: NType.mono(14, t.ink),
                decoration: const InputDecoration(hintText: 'RECIPE NAME, E.G. MOM’S CHAKALAKA'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Row(children: [
                  Expanded(child: Shrink(Label('Servings it makes', color: t.ink, size: 10))),
                  IconButton(
                    onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                    icon: Icon(Icons.remove, color: t.ink, size: 18),
                  ),
                  SizedBox(width: 36, child: Text('$_servings', textAlign: TextAlign.center, style: NType.dot(22, t.ink))),
                  IconButton(onPressed: () => setState(() => _servings++), icon: Icon(Icons.add, color: t.ink, size: 18)),
                ]),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Shrink(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fmt(s.calories), style: NType.dot(40, t.ink)),
                      const Label('kcal per serving', size: 9),
                    ])),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Shrink(
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('C ${fmt(s.carbs)} G', style: NType.mono(11, t.ink)),
                        Text('P ${fmt(s.protein)} G', style: NType.mono(11, t.ink)),
                        Text('F ${fmt(s.fat)} G', style: NType.mono(11, t.ink)),
                        Text('${fmt(d.totalGrams / (_servings == 0 ? 1 : _servings))} G / SERV', style: NType.mono(9, t.inkMuted)),
                      ]),
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              const Label('Ingredients'),
              const SizedBox(height: 8),
              if (_rows.isEmpty) Text('Add what goes into the pot, with weights.', style: NType.serif(16, t.inkMuted)),
              for (final r in _rows) ...[
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.food.name, style: NType.mono(12, t.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${fmt(r.food.forGrams(r.g).calories)} KCAL', style: NType.mono(9, t.inkMuted)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: r.grams,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        style: NType.mono(13, t.ink, weight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          fillColor: t.tint,
                          suffixText: 'g',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => setState(() {
                        _rows.remove(r);
                        _removed.add(r);
                      }),
                      icon: Icon(Icons.close, color: t.inkMuted, size: 18),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              TextButton.icon(
                onPressed: _addIngredient,
                icon: Icon(Icons.add, size: 16, color: t.ink),
                label: Text('ADD INGREDIENT', style: NType.mono(11, t.ink, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BlackButton(label: 'Save recipe', onPressed: canSave ? _save : null),
        ),
      ]),
    );
  }
}
