import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Reminder {
  const Reminder({required this.id, required this.label, required this.message, required this.hour, required this.minute, this.enabled = false});
  final int id; // also the notification id
  final String label, message;
  final int hour, minute;
  final bool enabled;

  Reminder copyWith({int? hour, int? minute, bool? enabled}) => Reminder(
        id: id,
        label: label,
        message: message,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {'id': id, 'h': hour, 'm': minute, 'on': enabled};

  static const defaults = [
    Reminder(id: 1, label: 'Breakfast', message: 'Log your breakfast while you remember it.', hour: 8, minute: 0),
    Reminder(id: 2, label: 'Lunch', message: 'Time to log lunch. A quick meal scan does it.', hour: 13, minute: 0),
    Reminder(id: 3, label: 'Dinner', message: 'Log dinner to close out the day.', hour: 19, minute: 0),
    Reminder(id: 4, label: 'Weigh-in', message: 'Step on the scale and log your weight.', hour: 7, minute: 0),
  ];

  /// Merges saved times/toggles onto the defaults (labels stay current).
  static List<Reminder> fromSaved(String? json) {
    if (json == null) return defaults;
    final saved = {for (final j in jsonDecode(json) as List) (j as Map)['id'] as int: j};
    return [
      for (final d in defaults)
        saved[d.id] == null
            ? d
            : d.copyWith(hour: saved[d.id]!['h'] as int, minute: saved[d.id]!['m'] as int, enabled: saved[d.id]!['on'] as bool),
    ];
  }

  static String encodeAll(List<Reminder> list) => jsonEncode([for (final r in list) r.toJson()]);
}

/// Schedules repeating daily local notifications. Uses inexact alarms, so a
/// reminder may arrive a few minutes late, but no special alarm permission
/// is needed.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Phone-only: the PC web preview has no scheduled notifications.
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Johannesburg'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks the OS for notification permission. Returns false if refused.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Replaces all scheduled reminders with the enabled ones in [list].
  /// With a [name], messages are personalised ("Ona, log your breakfast…").
  Future<void> apply(List<Reminder> list, {String name = ''}) async {
    if (!supported) return;
    await _init();
    await _plugin.cancelAll();
    for (final r in list.where((r) => r.enabled)) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.label,
        body: personalise(r.message, name),
        scheduledDate: _next(r.hour, r.minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Meal reminders',
            channelDescription: 'Daily reminders to log meals and weight',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
  }

  @visibleForTesting
  static String personalise(String message, String name) =>
      name.isEmpty ? message : '$name, ${message[0].toLowerCase()}${message.substring(1)}';

  static tz.TZDateTime _next(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}
