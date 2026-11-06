import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/ai/ai_provider.dart';
import '../data/ai/claude.dart';
import '../data/ai/gemini.dart';
import '../data/ai/openai.dart';
import '../data/db.dart';
import '../data/reminders.dart';
import '../data/secrets.dart';
import '../app/theme.dart';
import '../domain/ui_prefs.dart';
import '../data/food_api/open_food_facts.dart';
import '../data/food_api/sa_staples.dart';
import '../data/food_api/usda.dart';
import '../data/prefs.dart';
import '../domain/models.dart';

// Overridden in main() once the async stores are open.
final prefsProvider = Provider<Prefs>((ref) => throw UnimplementedError());
final dbProvider = Provider<DiaryDb>((ref) => throw UnimplementedError());
final secretsProvider = Provider<Secrets>((ref) => throw UnimplementedError());

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    )));

final usdaProvider = Provider<UsdaApi>((ref) {
  final prefs = ref.watch(prefsProvider);
  return UsdaApi(ref.watch(dioProvider), () => prefs.usdaKey);
});

final offProvider = Provider<OpenFoodFactsApi>((ref) => OpenFoodFactsApi(ref.watch(dioProvider)));

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

// ---------- Goals & theme ----------

class GoalsNotifier extends Notifier<Goals> {
  @override
  Goals build() => ref.watch(prefsProvider).goals;

  Future<void> save(Goals g) async {
    await ref.read(prefsProvider).setGoals(g);
    state = g;
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, Goals>(GoalsNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.values.byName(ref.watch(prefsProvider).themeMode);

  Future<void> set(ThemeMode m) async {
    await ref.read(prefsProvider).setThemeMode(m.name);
    state = m;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class UiPrefsNotifier extends Notifier<UiPrefs> {
  @override
  UiPrefs build() => ref.watch(prefsProvider).ui;

  Future<void> update(UiPrefs Function(UiPrefs) change) async {
    state = change(state); // apply instantly; persist in the background
    await ref.read(prefsProvider).setUi(state);
  }
}

final uiPrefsProvider = NotifierProvider<UiPrefsNotifier, UiPrefs>(UiPrefsNotifier.new);

// Themes are rebuilt only when the look settings change.
final lightThemeProvider = Provider<ThemeData>((ref) {
  final ui = ref.watch(uiPrefsProvider);
  return buildTheme(Brightness.light, accentOn: ui.accent, glyphRings: ui.glyphRings);
});
final darkThemeProvider = Provider<ThemeData>((ref) {
  final ui = ref.watch(uiPrefsProvider);
  return buildTheme(Brightness.dark, accentOn: ui.accent, glyphRings: ui.glyphRings);
});

class DisplayNameNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(prefsProvider).displayName;

  Future<void> set(String name) async {
    await ref.read(prefsProvider).setDisplayName(name);
    state = name.trim();
  }
}

/// How the user wants to be addressed ('' when not set).
final displayNameProvider = NotifierProvider<DisplayNameNotifier, String>(DisplayNameNotifier.new);

/// Re-applies active reminders, e.g. after the name in their text changed.
Future<void> rescheduleReminders(WidgetRef ref) async {
  final list = ref.read(prefsProvider).reminders;
  if (!list.any((r) => r.enabled)) return;
  try {
    await ReminderService.instance.apply(list, name: ref.read(displayNameProvider));
  } catch (_) {
    // Permission may have been revoked; the Reminders screen handles that.
  }
}

/// "Good morning, Ona" / "Good evening" — time-of-day greeting with the name if set.
String greeting(String name, [DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  final part = h < 5 ? 'Good night' : h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  return name.isEmpty ? part : '$part, $name';
}

// ---------- AI ----------

class AiConfig {
  const AiConfig(this.kind, this.model, this.key);
  final AiKind kind;
  final String model;
  final String key;
  bool get ready => key.isNotEmpty;
}

class AiConfigNotifier extends Notifier<AiConfig> {
  Prefs get _prefs => ref.read(prefsProvider);
  Secrets get _secrets => ref.read(secretsProvider);

  AiConfig _for(AiKind k) => AiConfig(k, _prefs.aiModel(k), _secrets.keyFor(k));

  @override
  AiConfig build() => _for(ref.watch(prefsProvider).aiKind);

  Future<void> setKind(AiKind k) async {
    await _prefs.setAiKind(k);
    state = _for(k);
  }

  Future<void> setKey(String key) async {
    await _secrets.setKey(state.kind, key);
    state = _for(state.kind);
  }

  Future<void> setModel(String model) async {
    await _prefs.setAiModel(state.kind, model);
    state = _for(state.kind);
  }
}

final aiConfigProvider = NotifierProvider<AiConfigNotifier, AiConfig>(AiConfigNotifier.new);

/// The configured AI, or null until the user adds an API key.
final aiProvider = Provider<AiProvider?>((ref) {
  final c = ref.watch(aiConfigProvider);
  if (!c.ready) return null;
  // A separate client: AI calls are slow and shouldn't share search timeouts.
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  return switch (c.kind) {
    AiKind.gemini => GeminiProvider(dio, c.key, c.model),
    AiKind.openai => OpenAiProvider(dio, c.key, c.model),
    AiKind.claude => ClaudeProvider(dio, c.key, c.model),
  };
});

// ---------- Diary ----------

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void set(DateTime d) => state = DateUtils.dateOnly(d);
  void shift(int days) => state = state.add(Duration(days: days));
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// Entries for the selected day.
final diaryProvider = FutureProvider<List<Entry>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(dbProvider).entriesFor(dateKey(date));
});

final recentFoodsProvider = FutureProvider<List<Food>>((ref) => ref.watch(dbProvider).recentFoods());

/// Write operations on the diary; refreshes dependent views afterwards.
class DiaryActions {
  DiaryActions(this._ref);
  final Ref _ref;

  DiaryDb get _db => _ref.read(dbProvider);

  void _refresh() {
    _ref.invalidate(diaryProvider);
    _ref.invalidate(recentFoodsProvider);
    _ref.invalidate(historyProvider);
  }

  Future<void> add(Entry e) async {
    await _db.insert(e);
    _refresh();
  }

  Future<void> update(Entry e) async {
    await _db.update(e);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _db.delete(id);
    _refresh();
  }
}

final diaryActionsProvider = Provider<DiaryActions>((ref) => DiaryActions(ref));

// ---------- History, weight, recipes ----------

/// All entries from [days] days ago up to today (for charts and reports).
final historyProvider = FutureProvider.family<List<Entry>, int>((ref, days) {
  final today = DateUtils.dateOnly(DateTime.now());
  final from = today.subtract(Duration(days: days - 1));
  return ref.watch(dbProvider).entriesBetween(dateKey(from), dateKey(today));
});

final weightsProvider = FutureProvider<List<WeightEntry>>((ref) => ref.watch(dbProvider).weights());

final recipesProvider = FutureProvider<List<Recipe>>((ref) => ref.watch(dbProvider).recipes());

class WeightActions {
  WeightActions(this._ref);
  final Ref _ref;

  /// Logs today's (or [date]'s) weight. The latest weigh-in also becomes the
  /// weight used by the Goals calculator; the calorie goal itself isn't changed.
  Future<void> log(double kg, {DateTime? date}) async {
    final d = DateUtils.dateOnly(date ?? DateTime.now());
    await _ref.read(dbProvider).setWeight(dateKey(d), kg);
    final all = await _ref.read(dbProvider).weights();
    if (all.isNotEmpty && all.last.date == dateKey(d)) {
      final goals = _ref.read(goalsProvider);
      await _ref.read(goalsProvider.notifier).save(goals.copyWith(weightKg: kg));
    }
    _ref.invalidate(weightsProvider);
  }

  Future<void> delete(String date) async {
    await _ref.read(dbProvider).deleteWeight(date);
    _ref.invalidate(weightsProvider);
  }
}

final weightActionsProvider = Provider<WeightActions>((ref) => WeightActions(ref));

class RecipeActions {
  RecipeActions(this._ref);
  final Ref _ref;

  Future<int> save(Recipe r) async {
    final id = await _ref.read(dbProvider).saveRecipe(r);
    _ref.invalidate(recipesProvider);
    _searchCache.clear(); // recipes appear in search
    return id;
  }

  Future<void> delete(int id) async {
    await _ref.read(dbProvider).deleteRecipe(id);
    _ref.invalidate(recipesProvider);
    _searchCache.clear();
  }
}

final recipeActionsProvider = Provider<RecipeActions>((ref) => RecipeActions(ref));

/// Re-reads everything after a backup import.
void refreshAll(WidgetRef ref) {
  _searchCache.clear();
  ref.invalidate(diaryProvider);
  ref.invalidate(recentFoodsProvider);
  ref.invalidate(historyProvider);
  ref.invalidate(weightsProvider);
  ref.invalidate(recipesProvider);
}

// ---------- Food search ----------

class SearchResult {
  const SearchResult(this.foods, this.errors, {this.loading = false});
  final List<Food> foods;
  final List<String> errors;
  final bool loading; // more sources still on their way
}

/// Completed searches, so retyping a query is instant. Lives for the app session.
final _searchCache = <String, SearchResult>{};

/// Progressive search: built-in SA staples appear instantly, then Open Food
/// Facts (South Africa) and USDA results merge in as each one responds.
/// A failing source doesn't fail the whole search.
final foodSearchProvider = StreamProvider.autoDispose.family<SearchResult, String>((ref, query) async* {
  final q = query.trim().toLowerCase();
  if (q.length < 2) {
    yield const SearchResult([], []);
    return;
  }
  final cached = _searchCache[q];
  if (cached != null) {
    yield cached;
    return;
  }

  // Local first: the user's own recipes, then built-in SA staples.
  final recipes = await ref.read(recipesProvider.future);
  final local = [
    for (final r in recipes)
      if (q.split(RegExp(r'\s+')).every((w) => r.name.toLowerCase().contains(w))) r.toFood(),
    ...searchSaStaples(q),
  ];
  yield SearchResult(local, const [], loading: true);

  final errors = <String>[];

  Future<List<Food>> guard(String name, Future<List<Food>> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      debugPrint('$name search failed: $e');
      errors.add(code == 429 ? '$name rate limit reached' : '$name unavailable');
      return const [];
    } catch (e, st) {
      debugPrint('$name search failed: $e\n$st');
      errors.add('$name unavailable');
      return const [];
    }
  }

  List<Food>? off, usda;
  // Fixed order regardless of which source answers first, so rows don't jump:
  // SA staples, then SA packaged products interleaved with USDA generic foods.
  SearchResult build({required bool loading}) {
    final merged = [...local];
    final seen = {for (final f in local) f.name.toLowerCase()};
    final a = off ?? const <Food>[], b = usda ?? const <Food>[];
    for (var i = 0; i < a.length || i < b.length; i++) {
      for (final list in [a, b]) {
        if (i < list.length && seen.add('${list[i].name.toLowerCase()}|${list[i].brand?.toLowerCase()}')) {
          merged.add(list[i]);
        }
      }
    }
    return SearchResult(merged, List.unmodifiable(errors), loading: loading);
  }

  final offF = guard('Open Food Facts', () => ref.read(offProvider).search(q)).then((v) => off = v);
  final usdaF = guard('USDA', () => ref.read(usdaProvider).search(q)).then((v) => usda = v);

  await Future.any([offF, usdaF]);
  yield build(loading: true);
  await Future.wait([offF, usdaF]);

  final done = build(loading: false);
  if (errors.isEmpty) {
    if (_searchCache.length > 60) _searchCache.remove(_searchCache.keys.first);
    _searchCache[q] = done;
  }
  yield done;
});
