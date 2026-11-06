import 'package:calorie_tracker/data/prefs.dart';
import 'package:calorie_tracker/data/reminders.dart';
import 'package:calorie_tracker/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('greeting follows the time of day and uses the name when set', () {
    expect(greeting('Ona', DateTime(2026, 10, 9, 7)), 'Good morning, Ona');
    expect(greeting('Ona', DateTime(2026, 10, 9, 14)), 'Good afternoon, Ona');
    expect(greeting('', DateTime(2026, 10, 9, 20)), 'Good evening');
    expect(greeting('', DateTime(2026, 10, 9, 2)), 'Good night');
  });

  test('reminder text is personalised only when a name is set', () {
    const msg = 'Log your breakfast while you remember it.';
    expect(ReminderService.personalise(msg, ''), msg);
    expect(ReminderService.personalise(msg, 'Ona'), 'Ona, log your breakfast while you remember it.');
  });

  test('display name is trimmed and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    expect(c.read(displayNameProvider), '');
    await c.read(displayNameProvider.notifier).set('  Ona ');
    expect(c.read(displayNameProvider), 'Ona');
    expect(prefs.displayName, 'Ona');
  });
}
