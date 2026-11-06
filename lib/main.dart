import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app/router.dart';
import 'data/db.dart';
import 'data/prefs.dart';
import 'data/secrets.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open all local stores in parallel to shorten startup.
  final prefsF = Prefs.load();
  // Web build is only for quick UI previews on a PC; phones use native SQLite.
  final dbF = DiaryDb.open(factory: kIsWeb ? databaseFactoryFfiWeb : null);
  final secretsF = Secrets.load();
  final prefs = await prefsF, db = await dbF, secrets = await secretsF;
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      dbProvider.overrideWithValue(db),
      secretsProvider.overrideWithValue(secrets),
    ],
    child: const FuelApp(),
  ));
}

class FuelApp extends ConsumerWidget {
  const FuelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Fuel',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      // Respect the phone's font size, but cap it so fixed layouts (nav bar,
      // rings) stay intact at the largest accessibility sizes.
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
    );
  }
}
