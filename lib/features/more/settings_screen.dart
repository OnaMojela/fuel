import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/ai/ai_provider.dart';
import '../../data/backup.dart';
import '../../data/reminders.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _usda = TextEditingController(text: ref.read(prefsProvider).usdaKey);
  late final _name = TextEditingController(text: ref.read(displayNameProvider));
  late final _aiKey = TextEditingController(text: ref.read(aiConfigProvider).key);
  late final _aiModel = TextEditingController(text: ref.read(aiConfigProvider).model);
  bool _showKey = false;

  @override
  void dispose() {
    _usda.dispose();
    _name.dispose();
    _aiKey.dispose();
    _aiModel.dispose();
    super.dispose();
  }

  Future<void> _setKind(AiKind k) async {
    await ref.read(aiConfigProvider.notifier).setKind(k);
    final c = ref.read(aiConfigProvider);
    setState(() {
      _aiKey.text = c.key;
      _aiModel.text = c.model;
      _showKey = false;
    });
  }

  Future<void> _saveAi() async {
    final n = ref.read(aiConfigProvider.notifier);
    await n.setKey(_aiKey.text);
    await n.setModel(_aiModel.text);
    _aiModel.text = ref.read(aiConfigProvider).model; // empty → default
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI settings saved')));
  }

  Widget _segmented<T>(List<T> values, T selected, String Function(T) label, void Function(T) onTap) {
    final t = context.tk;
    return GlassCard(
      child: Row(children: [
        for (final v in values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: v == values.last ? 0 : 8),
              child: GestureDetector(
                onTap: () => onTap(v),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: v == selected ? t.cta : t.tint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Shrink(
                    Text(label(v).toUpperCase(), style: NType.mono(11, v == selected ? t.onCta : t.ink)),
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final mode = ref.watch(themeModeProvider);
    final ai = ref.watch(aiConfigProvider);
    return NScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Label('Your name'),
          const SizedBox(height: 4),
          Text('What should the app call you? Used in greetings, reminders and your weekly report.',
              style: NType.serif(15, t.inkMuted)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            style: NType.mono(14, t.ink),
            decoration: const InputDecoration(hintText: 'NAME OR NICKNAME', counterText: ''),
            onChanged: (v) => ref.read(displayNameProvider.notifier).set(v),
            onSubmitted: (_) => rescheduleReminders(ref),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              rescheduleReminders(ref);
            },
          ),
          const SizedBox(height: 28),
          const Label('AI for meal scan & voice'),
          const SizedBox(height: 8),
          _segmented(AiKind.values, ai.kind, (k) => k.label, _setKind),
          const SizedBox(height: 8),
          Text(
            switch (ai.kind) {
              AiKind.gemini => 'Free tier available for some models. Create a key at ${ai.kind.keyUrl}.',
              AiKind.openai => 'Pay-as-you-go, separate from a ChatGPT subscription. Create a key at ${ai.kind.keyUrl}.',
              AiKind.claude => 'Pay-as-you-go. Create a key at ${ai.kind.keyUrl}. '
                  'claude-haiku-5-5 is a much cheaper model option.',
            },
            style: NType.serif(15, t.inkMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiKey,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            style: NType.mono(13, t.ink),
            decoration: InputDecoration(
              hintText: '${ai.kind.label.toUpperCase()} API KEY',
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility, color: t.inkMuted),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiModel,
            autocorrect: false,
            style: NType.mono(13, t.ink),
            decoration: InputDecoration(hintText: 'MODEL (DEFAULT ${ai.kind.defaultModel})'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(ai.ready ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 16, color: t.inkMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(ai.ready ? 'KEY SAVED ON THIS DEVICE' : 'NO KEY YET', style: NType.mono(10, t.inkMuted))),
          ]),
          const SizedBox(height: 12),
          BlackButton(label: 'Save AI settings', onPressed: _saveAi),
          const SizedBox(height: 28),
          const Label('Appearance'),
          const SizedBox(height: 8),
          _segmented(ThemeMode.values, mode, (m) => m.name, (m) => ref.read(themeModeProvider.notifier).set(m)),
          const SizedBox(height: 20),
          const Label('USDA FoodData Central API key'),
          const SizedBox(height: 4),
          Text(
            'Optional. Without one the shared demo key is used, which allows only ~30 searches an hour. '
            'Get a free key at fdc.nal.usda.gov/api-key-signup.',
            style: NType.serif(15, t.inkMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usda,
            style: NType.mono(13, t.ink),
            decoration: const InputDecoration(hintText: 'PASTE KEY'),
            onChanged: (v) => ref.read(prefsProvider).setUsdaKey(v),
          ),
          const SizedBox(height: 28),
          const Label('Backup'),
          const SizedBox(height: 4),
          Text(
            'Your diary lives only on this phone. Export a backup file now and then (save it to Google Drive or '
            'send it to yourself) so you can restore it on a new phone. API keys aren’t included.',
            style: NType.serif(15, t.inkMuted),
          ),
          const SizedBox(height: 12),
          BlackButton(label: 'Export backup', icon: Icons.ios_share, onPressed: _export),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _import,
              icon: Icon(Icons.restore, color: t.ink, size: 18),
              label: Text('RESTORE FROM FILE', style: NType.mono(12, t.ink, weight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: t.ink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Backup get _backup => Backup(ref.read(dbProvider), ref.read(prefsProvider));


  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    try {
      await _backup.share();
    } catch (e) {
      _toast('Export failed: $e');
    }
  }

  Future<void> _import() async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.canvas,
        title: Text('Replace all data?', style: NType.mono(14, t.ink, weight: FontWeight.w700)),
        content: Text(
          'Restoring replaces everything on this phone (diary, weights, recipes, goals) with the backup.',
          style: NType.serif(16, t.inkMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL', style: NType.mono(11, t.inkMuted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('CHOOSE FILE', style: NType.mono(11, t.ink, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!await _backup.pickAndRestore()) return;
      refreshAll(ref);
      ref.invalidate(goalsProvider);
      ref.invalidate(displayNameProvider);
      ref.invalidate(uiPrefsProvider);
      _name.text = ref.read(displayNameProvider);
      try {
        await ReminderService.instance.apply(ref.read(prefsProvider).reminders, name: ref.read(displayNameProvider));
      } catch (_) {
        // Notification permission may be off; the Reminders screen will ask.
      }
      _toast('Backup restored');
    } on FormatException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Restore failed: $e');
    }
  }
}
