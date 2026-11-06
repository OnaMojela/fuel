import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../food_detail/food_detail_screen.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    return NScaffold(
      title: 'Recipes',
      body: Column(children: [
        Expanded(
          child: recipes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('no recipes', style: NType.dot(36, t.ink)),
                      const SizedBox(height: 10),
                      Text(
                        'Combine ingredients once (say, your chakalaka or Sunday stew), then log a serving in one tap. '
                        'Recipes also show up in food search.',
                        textAlign: TextAlign.center,
                        style: NType.serif(17, t.inkMuted),
                      ),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = recipes[i];
                    final s = r.perServing;
                    return GlassCard(
                      onTap: () => context.push('/recipe', extra: r),
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.name, style: NType.mono(13, t.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              '${r.ingredients.length} INGREDIENTS · ${r.servings} SERVINGS · '
                              'P ${fmt(s.protein)} C ${fmt(s.carbs)} F ${fmt(s.fat)}',
                              style: NType.mono(9, t.inkMuted),
                              maxLines: 2,
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(fmt(s.calories), style: NType.dot(20, t.ink)),
                          Text('KCAL/SERV', style: NType.mono(8, t.inkMuted)),
                        ]),
                        IconButton(
                          tooltip: 'Log a serving',
                          icon: Icon(Icons.add_circle_outline, color: t.ink),
                          onPressed: () => context.push('/food', extra: FoodDetailArgs(food: r.toFood(), meal: Meal.forNow())),
                        ),
                      ]),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BlackButton(label: 'New recipe', icon: Icons.add, onPressed: () => context.push('/recipe')),
        ),
      ]),
    );
  }
}
