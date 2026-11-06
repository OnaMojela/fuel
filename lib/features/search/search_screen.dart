import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../food_detail/food_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.initialMeal, this.initialQuery = '', this.pick = false});
  final Meal initialMeal;
  final String initialQuery;

  /// Pick mode: tapping a food pops it back to the caller instead of opening details.
  final bool pick;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late Meal _meal = widget.initialMeal;
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  late String _query = widget.initialQuery;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    // SA staples show instantly at any speed; the debounce only spaces out
    // network calls (Open Food Facts allows ~10 searches/min).
    _debounce = Timer(const Duration(milliseconds: 450), () => setState(() => _query = v.trim()));
  }

  void _open(Food f) => widget.pick ? context.pop(f) : context.push('/food', extra: FoodDetailArgs(food: f, meal: _meal));

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return NScaffold(
      title: widget.pick ? 'Pick a match' : 'Search food',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                setState(() => _query = v.trim());
              },
              style: NType.mono(14, t.ink),
              decoration: InputDecoration(
                hintText: 'SEARCH FOR A FOOD',
                prefixIcon: Icon(Icons.search, color: t.inkMuted),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: t.inkMuted),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final m in Meal.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(label: m.label, selected: m == _meal, onTap: () => setState(() => _meal = m)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _query.length < 2 ? _recent() : _results()),
        ],
      ),
    );
  }

  Widget _recent() {
    final recent = ref.watch(recentFoodsProvider).value ?? const <Food>[];
    if (recent.isEmpty) {
      return _empty('Search South African staples, products sold in SA, and USDA foods.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Label('Recent'),
        const SizedBox(height: 8),
        for (final f in recent) _FoodRow(food: f, onTap: () => _open(f)),
      ],
    );
  }

  Widget _results() {
    final t = context.tk;
    final res = ref.watch(foodSearchProvider(_query));
    // Keep showing the previous results while a new query starts, instead of
    // flashing a spinner on every keystroke.
    final r = res.value;
    if (r == null) {
      return res.hasError ? _empty('Search failed. Check your connection.') : const Center(child: CircularProgressIndicator());
    }
    final bar = SizedBox(
      height: 2,
      child: r.loading || res.isLoading ? LinearProgressIndicator(color: t.ink, backgroundColor: t.track) : null,
    );
    if (r.foods.isEmpty) {
      return Column(children: [
        bar,
        Expanded(
          child: r.loading
              ? const SizedBox.shrink()
              : _empty(r.errors.isNotEmpty ? r.errors.join(' · ') : 'No foods found for "$_query".'),
        ),
      ]);
    }
    final hasErr = r.errors.isNotEmpty;
    return Column(children: [
      bar,
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: r.foods.length + (hasErr ? 1 : 0),
          itemBuilder: (_, i) {
            if (hasErr && i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(r.errors.join(' · ').toUpperCase(), style: NType.mono(9, t.accent)),
              );
            }
            final f = r.foods[i - (hasErr ? 1 : 0)];
            return _FoodRow(food: f, onTap: () => _open(f));
          },
        ),
      ),
    ]);
  }

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg, textAlign: TextAlign.center, style: NType.serif(18, context.tk.inkMuted)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.cta : t.glass,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label.toUpperCase(), style: NType.mono(11, selected ? t.onCta : t.ink)),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap});
  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final serving = food.allServings.first;
    final kcal = food.forGrams(serving.grams).calories;
    final sub = [
      if (food.brand != null && food.source != FoodSource.za) food.brand!,
      serving.label,
      switch (food.source) {
        FoodSource.usda => 'USDA',
        FoodSource.off => 'OFF',
        FoodSource.za => 'SA · APPROX',
        FoodSource.ai => 'AI',
        FoodSource.custom => 'MINE',
      },
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(food.name, style: NType.mono(13, t.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(sub, style: NType.mono(10, t.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt(kcal), style: NType.dot(20, t.ink)),
            Text('KCAL', style: NType.mono(8, t.inkMuted)),
          ]),
        ]),
      ),
    );
  }
}
