import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/ui_prefs.dart';
import 'ai/ai_provider.dart';
import 'reminders.dart';

/// Small key-value settings: goals, theme, API keys.
class Prefs {
  Prefs(this._sp);
  final SharedPreferences _sp;

  static Future<Prefs> load() async => Prefs(await SharedPreferences.getInstance());

  Goals get goals {
    final s = _sp.getString('goals');
    return s == null ? const Goals() : Goals.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> setGoals(Goals g) => _sp.setString('goals', jsonEncode(g.toJson()));

  /// What the app calls the user (empty = no name).
  String get displayName => _sp.getString('display_name') ?? '';
  Future<void> setDisplayName(String name) => _sp.setString('display_name', name.trim());

  UiPrefs get ui => UiPrefs.decode(_sp.getString('ui'));
  Future<void> setUi(UiPrefs ui) => _sp.setString('ui', ui.encode());

  /// 'system' | 'light' | 'dark'
  String get themeMode => _sp.getString('theme') ?? 'system';
  Future<void> setThemeMode(String m) => _sp.setString('theme', m);

  /// USDA FoodData Central key. DEMO_KEY works but is heavily rate limited.
  String get usdaKey => _sp.getString('usda_key') ?? '';
  Future<void> setUsdaKey(String k) => _sp.setString('usda_key', k.trim());

  /// Which AI powers meal scan and voice log.
  AiKind get aiKind => AiKind.values.asNameMap()[_sp.getString('ai_kind')] ?? AiKind.gemini;
  Future<void> setAiKind(AiKind k) => _sp.setString('ai_kind', k.name);

  String aiModel(AiKind k) {
    final m = _sp.getString('ai_model_${k.name}');
    return (m == null || m.isEmpty) ? k.defaultModel : m;
  }

  Future<void> setAiModel(AiKind k, String m) => _sp.setString('ai_model_${k.name}', m.trim());

  List<Reminder> get reminders => Reminder.fromSaved(_sp.getString('reminders'));
  Future<void> setReminders(List<Reminder> list) => _sp.setString('reminders', Reminder.encodeAll(list));

  /// Raw reminder settings, for backup/restore.
  String get remindersJson => _sp.getString('reminders') ?? Reminder.encodeAll(Reminder.defaults);
  Future<void> setRemindersJson(String json) => _sp.setString('reminders', json);
}
