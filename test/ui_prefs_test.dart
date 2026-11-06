import 'dart:convert';

import 'package:calorie_tracker/domain/hero.dart';
import 'package:calorie_tracker/domain/models.dart';
import 'package:calorie_tracker/domain/ui_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UiPrefs', () {
    test('round-trips', () {
      const ui = UiPrefs(
        hero: HeroMetric.proteinLeft,
        accent: true,
        glyphRings: true,
        cards: [
          CardPref(TodayCard.streak, true),
          CardPref(TodayCard.hero, false),
          CardPref(TodayCard.macros, true),
          CardPref(TodayCard.weight, true),
          CardPref(TodayCard.lowCarb, false),
          CardPref(TodayCard.heartHealthy, true),
        ],
      );
      final back = UiPrefs.decode(ui.encode());
      expect(back.hero, HeroMetric.proteinLeft);
      expect(back.accent, isTrue);
      expect(back.glyphRings, isTrue);
      expect(back.visibleCards, [TodayCard.streak, TodayCard.macros, TodayCard.weight, TodayCard.heartHealthy]);
    });

    test('defaults: everything visible, accent off', () {
      final ui = UiPrefs.decode(null);
      expect(ui.accent, isFalse);
      expect(ui.visibleCards, TodayCard.values);
    });

    test('older saves gain new cards; unknown cards and duplicates are dropped', () {
      final saved = jsonEncode({
        'hero': 'unknownMetric',
        'cards': [
          {'id': 'macros', 'on': false},
          {'id': 'hero', 'on': true},
          {'id': 'removedCard', 'on': true},
          {'id': 'macros', 'on': true},
        ],
      });
      final ui = UiPrefs.decode(saved);
      expect(ui.hero, HeroMetric.caloriesLeft);
      expect(ui.cards.first.card, TodayCard.macros);
      expect(ui.cards.first.visible, isFalse);
      expect(ui.cards.map((c) => c.card).toSet(), TodayCard.values.toSet());
      expect(ui.cards, hasLength(TodayCard.values.length));
    });

    test('corrupt data falls back to defaults', () {
      expect(UiPrefs.decode('{not json').hero, HeroMetric.caloriesLeft);
    });
  });

  group('heroView', () {
    const goals = Goals(calories: 2000, proteinPct: 30); // protein target 150 g
    const ate = Nutrients(calories: 2300, protein: 160, carbs: 120, fiber: 10);

    test('calories left: over the goal raises the alarm', () {
      final v = heroView(HeroMetric.caloriesLeft, ate, goals);
      expect(v.value, 300);
      expect(v.label, 'Over');
      expect(v.alarm, isTrue);
      expect(v.progress, closeTo(1.15, 0.001));
    });

    test('calories eaten shows the total and what is left/over', () {
      final v = heroView(HeroMetric.caloriesEaten, const Nutrients(calories: 1200), goals);
      expect(v.value, 1200);
      expect(v.stats[1].label, 'Left');
      expect(v.stats[1].value, '800');
    });

    test('protein above target is not an alarm', () {
      final v = heroView(HeroMetric.proteinLeft, ate, goals);
      expect(v.value, 10);
      expect(v.label, 'G above target');
      expect(v.alarm, isFalse);
      expect(v.overIsBad, isFalse);
    });

    test('net carbs vs the 100 g limit', () {
      final v = heroView(HeroMetric.netCarbs, ate, goals);
      expect(v.value, 110);
      expect(v.alarm, isTrue);
      expect(v.stats[1].label, 'Over');
    });
  });
}
