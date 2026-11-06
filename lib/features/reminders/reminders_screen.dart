import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/reminders.dart';
import '../../state/providers.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  late List<Reminder> _list = ref.read(prefsProvider).reminders;
  String? _error;

  ReminderService get _svc => ReminderService.instance;

  Future<void> _update(Reminder r) async {
    // Ask for permission the first time something is switched on.
    if (r.enabled && !_list.any((x) => x.enabled)) {
      final ok = await _svc.requestPermission();
      if (!ok) {
        setState(() => _error = 'Notifications are blocked. Allow them for this app in your phone settings.');
        return;
      }
    }
    final next = [for (final x in _list) x.id == r.id ? r : x];
    setState(() {
      _list = next;
      _error = null;
    });
    await ref.read(prefsProvider).setReminders(next);
    try {
      await _svc.apply(next, name: ref.read(displayNameProvider));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not schedule reminders: $e');
    }
  }

  Future<void> _pickTime(Reminder r) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
    if (picked != null) await _update(r.copyWith(hour: picked.hour, minute: picked.minute, enabled: true));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return NScaffold(
      title: 'Reminders',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (!_svc.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Reminders work in the phone app, not this preview.', style: NType.serif(16, t.accent)),
            ),
          for (final r in _list) ...[
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Shrink(Label(r.label, color: t.ink, size: 11)),
                    const SizedBox(height: 2),
                    Text(r.message, style: NType.serif(14, t.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Flexible(
                  flex: 2,
                  child: TextButton(
                    onPressed: () => _pickTime(r),
                    child: Shrink(
                      Text(
                        MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: r.hour, minute: r.minute),
                            alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat),
                        style: NType.dot(22, r.enabled ? t.ink : t.inkMuted),
                      ),
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                Switch(
                  value: r.enabled,
                  activeThumbColor: t.onCta,
                  activeTrackColor: t.cta,
                  onChanged: (v) => _update(r.copyWith(enabled: v)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: NType.mono(11, t.accent)),
          ],
          const SizedBox(height: 8),
          Text('Tap a time to change it. Reminders repeat daily and may arrive a few minutes late to save battery.',
              style: NType.serif(15, t.inkMuted)),
        ],
      ),
    );
  }
}
