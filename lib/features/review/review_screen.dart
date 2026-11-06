import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/ai/ai_provider.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class ReviewArgs {
  const ReviewArgs({required this.items, required this.meal, this.image, this.transcript});
  final List<DetectedItem> items;
  final Meal meal;
  final Uint8List? image; // meal scan photo
  final String? transcript; // voice log text
}

class _Row {
  _Row(this.food, double grams, this.confidence) : grams = TextEditingController(text: grams.round().toString());
  Food food;
  final TextEditingController grams;
  final double? confidence; // null once swapped for a database food

  double get g => double.tryParse(grams.text.replaceAll(',', '.')) ?? 0;
  Nutrients get n => food.forGrams(g);
}

/// Editable list of AI-detected foods. Nothing is logged until "Add".
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.args});
  final ReviewArgs args;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final List<_Row> _rows = [
    for (final i in widget.args.items) _Row(i.toFood(), i.grams, i.confidence),
  ];
  final _removed = <_Row>[];
  late Meal _meal = widget.args.meal;

  @override
  void dispose() {
    for (final r in [..._rows, ..._removed]) {
      r.grams.dispose();
    }
    super.dispose();
  }

  Nutrients get _total => _rows.fold(Nutrients.zero, (a, r) => a + r.n);

  Future<void> _swap(_Row r) async {
    final picked = await context.push<Food>(
      '/search?meal=${_meal.index}&pick=1&q=${Uri.encodeComponent(r.food.name)}',
    );
    if (picked != null) setState(() => r.food = picked);
  }

  Future<void> _save() async {
    final actions = ref.read(diaryActionsProvider);
    final date = dateKey(ref.read(selectedDateProvider));
    final now = DateTime.now();
    var i = 0;
    for (final r in _rows.where((r) => r.g > 0)) {
      await actions.add(Entry(
        date: date,
        meal: _meal,
        food: r.food,
        servingLabel: 'g',
        servingGrams: 1,
        quantity: r.g.roundToDouble(),
        createdAt: now.add(Duration(milliseconds: i++)), // keep detected order
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $i items to ${_meal.label}')));
    context.go('/log');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = _total;
    final count = _rows.where((r) => r.g > 0).length;

    return NScaffold(
      title: 'Review',
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              if (widget.args.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(widget.args.image!, fit: BoxFit.cover)),
                ),
              if (widget.args.transcript != null)
                GlassCard(child: Text('“${widget.args.transcript}”', style: NType.serif(18, t.ink))),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Shrink(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fmt(total.calories), style: NType.dot(44, t.ink)),
                      const Label('kcal total', size: 10),
                    ])),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Shrink(
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('C ${fmt(total.carbs)} G', style: NType.mono(11, t.ink)),
                        Text('P ${fmt(total.protein)} G', style: NType.mono(11, t.ink)),
                        Text('F ${fmt(total.fat)} G', style: NType.mono(11, t.ink)),
                      ]),
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('AI estimates. Check the grams, or tap the search icon to swap an item for a database match.',
                  style: NType.serif(15, t.inkMuted)),
              const SizedBox(height: 12),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No food found. Try again with a clearer photo or description.',
                      textAlign: TextAlign.center, style: NType.serif(18, t.inkMuted)),
                ),
              for (final r in _rows) ...[_item(r), const SizedBox(height: 8)],
              const SizedBox(height: 8),
              const Label('Meal'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in Meal.values)
                  ChoiceChip(
                    label: Text(m.label.toUpperCase(), style: NType.mono(11, m == _meal ? t.onCta : t.ink)),
                    selected: m == _meal,
                    showCheckmark: false,
                    selectedColor: t.cta,
                    backgroundColor: t.glass,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onSelected: (_) => setState(() => _meal = m),
                  ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BlackButton(
            label: count == 0 ? 'Nothing to add' : 'Add $count item${count == 1 ? '' : 's'} to ${_meal.label}',
            onPressed: count == 0 ? null : _save,
          ),
        ),
      ]),
    );
  }

  Widget _item(_Row r) {
    final t = context.tk;
    final conf = r.confidence;
    final tag = conf == null
        ? (r.food.source == FoodSource.usda ? 'USDA MATCH' : 'DATABASE MATCH')
        : 'AI ESTIMATE · ${fmt(conf * 100)}% SURE';
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.food.name, style: NType.mono(13, t.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(tag, style: NType.mono(9, conf != null && conf < 0.5 ? t.accent : t.inkMuted)),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(
                width: 76,
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
              const SizedBox(width: 12),
              Flexible(child: Shrink(Text('${fmt(r.n.calories)} KCAL', style: NType.mono(12, t.ink, weight: FontWeight.w700)))),
            ]),
          ]),
        ),
        Column(children: [
          IconButton(
            tooltip: 'Swap for database match',
            onPressed: () => _swap(r),
            icon: Icon(Icons.manage_search, color: t.ink),
          ),
          IconButton(
            tooltip: 'Remove',
            // Controller is disposed in dispose(); its field is still mounted this frame.
            onPressed: () => setState(() {
              _rows.remove(r);
              _removed.add(r);
            }),
            icon: Icon(Icons.close, color: t.inkMuted),
          ),
        ]),
      ]),
    );
  }
}
