import 'dart:convert';

/// What the big ring on the Today page tracks.
enum HeroMetric {
  caloriesLeft('Calories left'),
  caloriesEaten('Calories eaten'),
  proteinLeft('Protein left'),
  netCarbs('Net carbs');

  const HeroMetric(this.label);
  final String label;
}

/// Cards on the Today page. "Half" cards pair up side by side when adjacent.
enum TodayCard {
  hero('Hero ring', half: false),
  macros('Macros', half: false),
  streak('Streak', half: true),
  weight('Weight', half: true),
  lowCarb('Low carb', half: true),
  heartHealthy('Heart healthy', half: true);

  const TodayCard(this.label, {required this.half});
  final String label;
  final bool half;
}

class CardPref {
  const CardPref(this.card, this.visible);
  final TodayCard card;
  final bool visible;
}

/// Personalisation for the Today page and the Nothing-red accent.
class UiPrefs {
  const UiPrefs({
    this.hero = HeroMetric.caloriesLeft,
    this.accent = false,
    this.glyphRings = false,
    this.cards = defaultCards,
  });

  final HeroMetric hero;
  final bool accent; // subtle Nothing-red details
  final bool glyphRings; // rings drawn as dotted circles
  final List<CardPref> cards; // order + visibility

  static const defaultCards = [
    CardPref(TodayCard.hero, true),
    CardPref(TodayCard.macros, true),
    CardPref(TodayCard.streak, true),
    CardPref(TodayCard.weight, true),
    CardPref(TodayCard.lowCarb, true),
    CardPref(TodayCard.heartHealthy, true),
  ];

  List<TodayCard> get visibleCards => [for (final c in cards) if (c.visible) c.card];

  UiPrefs copyWith({HeroMetric? hero, bool? accent, bool? glyphRings, List<CardPref>? cards}) => UiPrefs(
        hero: hero ?? this.hero,
        accent: accent ?? this.accent,
        glyphRings: glyphRings ?? this.glyphRings,
        cards: cards ?? this.cards,
      );

  String encode() => jsonEncode({
        'hero': hero.name,
        'accent': accent,
        'glyph': glyphRings,
        'cards': [for (final c in cards) {'id': c.card.name, 'on': c.visible}],
      });

  /// Tolerant decode: unknown values fall back to defaults, and cards added in
  /// newer versions are appended (visible) so they're never silently missing.
  static UiPrefs decode(String? s) {
    if (s == null) return const UiPrefs();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final saved = <CardPref>[];
      for (final c in (j['cards'] as List? ?? const [])) {
        final card = TodayCard.values.asNameMap()[(c as Map)['id']];
        if (card != null && !saved.any((x) => x.card == card)) saved.add(CardPref(card, c['on'] != false));
      }
      for (final d in defaultCards) {
        if (!saved.any((x) => x.card == d.card)) saved.add(d);
      }
      return UiPrefs(
        hero: HeroMetric.values.asNameMap()[j['hero']] ?? HeroMetric.caloriesLeft,
        accent: j['accent'] == true,
        glyphRings: j['glyph'] == true,
        cards: saved,
      );
    } catch (_) {
      return const UiPrefs();
    }
  }
}
