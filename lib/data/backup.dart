import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import '../domain/ui_prefs.dart';
import 'db.dart';
import 'prefs.dart';

/// Backup = diary, weights, recipes, goals and reminder times as one JSON file.
/// API keys are deliberately NOT included.
class Backup {
  Backup(this._db, this._prefs);
  final DiaryDb _db;
  final Prefs _prefs;

  Future<String> exportJson() async {
    final data = await _db.exportAll();
    data['goals'] = _prefs.goals.toJson();
    data['reminders'] = jsonDecode(_prefs.remindersJson);
    data['name'] = _prefs.displayName;
    data['ui'] = jsonDecode(_prefs.ui.encode());
    return const JsonEncoder.withIndent(' ').convert(data);
  }

  /// Opens the phone's share sheet (save to Drive, WhatsApp to yourself, email…).
  Future<void> share() async {
    final json = await exportJson();
    final name = 'fuel-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(json), name: name, mimeType: 'application/json')],
      fileNameOverrides: [name],
      subject: 'Fuel backup',
    ));
  }

  /// Lets the user pick a backup file and restores it. Returns false if cancelled.
  /// Throws [FormatException] if the file isn't a backup from this app.
  Future<bool> pickAndRestore() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return false;
    await restoreJson(utf8.decode(await files.single.readAsBytes()));
    return true;
  }

  Future<void> restoreJson(String json) async {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      throw const FormatException('That file isn’t valid JSON.');
    }
    if (data is! Map<String, dynamic> || data['entries'] is! List) {
      throw const FormatException('That file isn’t a backup from this app.');
    }
    await _db.importAll(data);
    if (data['goals'] is Map) await _prefs.setGoals(Goals.fromJson(Map<String, dynamic>.from(data['goals'] as Map)));
    if (data['reminders'] is List) await _prefs.setRemindersJson(jsonEncode(data['reminders']));
    if (data['name'] is String) await _prefs.setDisplayName(data['name'] as String);
    if (data['ui'] is Map) await _prefs.setUi(UiPrefs.decode(jsonEncode(data['ui'])));
  }
}
