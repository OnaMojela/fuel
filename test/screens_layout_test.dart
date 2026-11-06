import 'package:calorie_tracker/app/router.dart';
import 'package:calorie_tracker/app/theme.dart';
import 'package:calorie_tracker/data/ai/ai_provider.dart';
import 'package:calorie_tracker/data/prefs.dart';
import 'package:calorie_tracker/features/review/review_screen.dart';
import 'package:calorie_tracker/data/secrets.dart';
import 'package:calorie_tracker/domain/models.dart';
import 'package:calorie_tracker/domain/ui_prefs.dart';
import 'package:calorie_tracker/features/food_detail/food_detail_screen.dart';
import 'package:calorie_tracker/state/providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _longFood = Food(
  id: 'off:1',
  name: 'Original Cheese Flavoured Maize Snack With A Very Long Product Name',
  brand: 'Nik Naks, Simba',
  source: FoodSource.off,
  per100g: Nutrients(
    calories: 525,
    protein: 6,
    carbs: 58,
    fat: 30,
    sodium: 900,
  ),
  servings: [
    Serving('serving · 1 portion (330 ml) with an unusually long label', 330),
  ],
);

/// Drives the real router through every main screen at small/large phone
/// widths and font sizes. Any overflow fails the test.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final entries = [
    for (final meal in Meal.values)
      Entry(
        id: meal.index + 1,
        date: '2026-10-09',
        meal: meal,
        food: _longFood,
        servingLabel: 'g',
        servingGrams: 1,
        quantity: 1234,
        createdAt: DateTime(2026, 10, 9, 8 + meal.index),
      ),
  ];

  // History relative to today so charts, streak and the weekly report have data.
  final today = DateUtils.dateOnly(DateTime.now());
  String day(int ago) => dateKey(today.subtract(Duration(days: ago)));
  final history = [
    for (var ago = 0; ago < 40; ago++)
      if (ago % 4 != 3)
        Entry(
          id: 100 + ago,
          date: day(ago),
          meal: Meal.values[ago % 4],
          food: _longFood,
          servingLabel: 'g',
          servingGrams: 1,
          quantity: 250.0 + ago * 37 % 500, // some days over goal, some under
          createdAt: today.subtract(Duration(days: ago)),
        ),
  ];
  final weights = [
    for (var ago = 60; ago >= 0; ago -= 3)
      WeightEntry(day(ago), 92.4 - ago * 0.05),
  ];
  final recipe = Recipe(
    id: 1,
    name:
        'Ouma’s Sunday lamb potjie with samp and chakalaka for the whole family',
    servings: 12,
    ingredients: [
      Ingredient(_longFood, 2500),
      const Ingredient(_longFood, 750),
    ],
  );

  Future<void> pumpApp(WidgetTester tester, double width, double scale) async {
    // A long name (greeting at its widest), Nothing red + glyph rings on, the
    // protein hero, and a reordered layout where half cards pair and one stands alone.
    SharedPreferences.setMockInitialValues({
      'display_name': 'Alexandria Montgomery-Smith',
      'ui': const UiPrefs(
        hero: HeroMetric.proteinLeft,
        accent: true,
        glyphRings: true,
        cards: [
          CardPref(TodayCard.streak, true),
          CardPref(TodayCard.weight, true),
          CardPref(TodayCard.hero, true),
          CardPref(TodayCard.lowCarb, true),
          CardPref(TodayCard.macros, true),
          CardPref(TodayCard.heartHealthy, true),
        ],
      ).encode(),
    });
    final prefs = await Prefs.load();
    tester.view.physicalSize = Size(width * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          secretsProvider.overrideWithValue(Secrets.forTest()),
          diaryProvider.overrideWith((ref) async => entries),
          recentFoodsProvider.overrideWith((ref) async => const []),
          historyProvider.overrideWith((ref, days) async => history),
          weightsProvider.overrideWith((ref) async => weights),
          recipesProvider.overrideWith((ref) async => [recipe]),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('main screens fit at ${width}dp, text ×$scale', (
        tester,
      ) async {
        // Collect every layout error with the screen it happened on, instead
        // of stopping at the first one.
        final failures = <String>[];
        var screen = 'startup';
        // Never call expect() while FlutterError.onError is overridden: a failure
        // there hangs the test runner. Record problems instead; expect at the end.
        void check(bool ok, String what) {
          if (!ok) failures.add('$screen: missing $what');
        }

        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          // Include the app source line of the offending widget, so failures point at the fix.
          final where =
              RegExp(
                r'lib/[\w/]+\.dart:\d+',
              ).firstMatch(d.toString())?.group(0) ??
              '';
          failures.add(
            '$screen: ${d.exceptionAsString().split('\n').first} $where',
          );
        };

        try {
          await pumpApp(tester, width, scale);
          for (final route in [
            '/',
            '/log',
            '/progress',
            '/more',
            '/settings',
            '/goals',
            '/scan',
            '/voice', //
            '/nutrition', '/report', '/recipes', '/reminders', '/help',
          ]) {
            screen = route;
            router.go(route);
            await tester.pumpAndSettle();
          }
          screen = '/food';
          router.go('/');
          router.push(
            '/food',
            extra: const FoodDetailArgs(food: _longFood, meal: Meal.lunch),
          );
          await tester.pumpAndSettle();

          screen = '/recipe';
          router.go('/');
          router.push('/recipe', extra: recipe);
          await tester.pumpAndSettle();

          screen = '/progress 90D';
          router.go('/progress');
          await tester.pumpAndSettle();
          await tester.tap(find.text('90D'));
          await tester.pumpAndSettle();
          check(find.byType(BarChart).evaluate().length == 1, 'calorie chart');
          check(find.byType(LineChart).evaluate().length == 1, 'weight chart');

          screen = '/review';
          router.go('/');
          router.push(
            '/review',
            extra: const ReviewArgs(
              meal: Meal.dinner,
              transcript: 'a big plate of pap with boerewors and chakalaka',
              items: [
                DetectedItem(
                  name: 'Pap (stiff maize porridge), extra large portion',
                  grams: 1250,
                  confidence: 0.35,
                  per100g: Nutrients(calories: 104),
                ),
                DetectedItem(
                  name: 'Boerewors',
                  grams: 150,
                  confidence: 0.9,
                  per100g: Nutrients(calories: 300, fat: 26),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          screen = '/search';
          router.go('/');
          router.push('/search?meal=1');
          await tester.pumpAndSettle();

          screen = 'make it yours';
          router.go('/');
          await tester.pumpAndSettle();
          check(find.text('STREAK').evaluate().isNotEmpty, 'streak card');
          check(find.text('PROTEIN').evaluate().isNotEmpty, 'protein hero');
          await tester.tap(find.byKey(const ValueKey('personal-badge')));
          await tester.pumpAndSettle();
          check(
            find.text('make it yours').evaluate().isNotEmpty,
            'customize sheet',
          );
          await tester.drag(
            find.text('make it yours'),
            const Offset(0, -2000),
          ); // scroll to the card list
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(10, 10)); // dismiss
          await tester.pumpAndSettle();

          screen = 'add sheet';
          router.go('/');
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add).last);
          await tester.pumpAndSettle();
          check(
            find.text('MEAL SCAN').evaluate().length == 1,
            'meal scan tile',
          );
          await tester.tapAt(const Offset(10, 10)); // dismiss
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError =
              prev; // must be restored before expect(), even if a step threw
        }
        expect(failures.toSet().toList(), isEmpty);
      });
    }
  }
}
