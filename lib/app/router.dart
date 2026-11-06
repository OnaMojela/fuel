import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import '../features/barcode/barcode_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/food_detail/food_detail_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/help/help_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/recipes/recipe_editor_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/report/weekly_report_screen.dart';
import '../features/log/log_screen.dart';
import '../features/meal_scan/meal_scan_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/settings_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/review_screen.dart';
import '../features/search/search_screen.dart';
import '../features/voice/voice_screen.dart';
import 'shell.dart';

/// `?meal=<index>` on logging routes; defaults to the meal for the time of day.
Meal _meal(GoRouterState s) {
  final m = int.tryParse(s.uri.queryParameters['meal'] ?? '');
  return m == null || m < 0 || m >= Meal.values.length ? Meal.forNow() : Meal.values[m];
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, nav) => AppShell(nav: nav),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/log', builder: (_, _) => const LogScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())]),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (_, s) => SearchScreen(
        initialMeal: _meal(s),
        initialQuery: s.uri.queryParameters['q'] ?? '',
        pick: s.uri.queryParameters['pick'] == '1',
      ),
    ),
    GoRoute(path: '/scan', builder: (_, s) => MealScanScreen(initialMeal: _meal(s))),
    GoRoute(path: '/voice', builder: (_, s) => VoiceScreen(initialMeal: _meal(s))),
    GoRoute(path: '/barcode', builder: (_, s) => BarcodeScreen(initialMeal: _meal(s))),
    GoRoute(path: '/review', builder: (_, s) => ReviewScreen(args: s.extra! as ReviewArgs)),
    GoRoute(path: '/food', builder: (_, s) => FoodDetailScreen(args: s.extra! as FoodDetailArgs)),
    GoRoute(path: '/goals', builder: (_, _) => const GoalsScreen()),
    GoRoute(path: '/nutrition', builder: (_, _) => const NutritionScreen()),
    GoRoute(path: '/report', builder: (_, _) => const WeeklyReportScreen()),
    GoRoute(path: '/recipes', builder: (_, _) => const RecipesScreen()),
    GoRoute(path: '/recipe', builder: (_, s) => RecipeEditorScreen(recipe: s.extra as Recipe?)),
    GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
    GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
