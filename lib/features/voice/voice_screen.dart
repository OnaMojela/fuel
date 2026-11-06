import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/ai/ai_provider.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../meal_scan/ai_key_missing.dart';
import '../review/review_screen.dart';

/// Speak (or type) what you ate → AI parses it → review.
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key, required this.initialMeal});
  final Meal initialMeal;

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  final _stt = SpeechToText();
  final _text = TextEditingController();
  bool _sttReady = false;
  bool _listening = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) {
          if (mounted && (s == 'done' || s == 'notListening')) setState(() => _listening = false);
        },
        onError: (e) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _sttReady = ok);
    } catch (_) {
      if (mounted) setState(() => _sttReady = false);
    }
  }

  @override
  void dispose() {
    _stt.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    final before = _text.text.trim();
    setState(() {
      _listening = true;
      _error = null;
    });
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (r) => setState(() {
        // Append to anything already typed.
        _text.text = [if (before.isNotEmpty) before, r.recognizedWords].join(' ');
      }),
    );
  }

  Future<void> _analyze() async {
    final ai = ref.read(aiProvider);
    final text = _text.text.trim();
    if (ai == null || text.isEmpty) return;
    if (_listening) await _stt.stop();
    setState(() {
      _busy = true;
      _listening = false;
      _error = null;
    });
    try {
      final items = await ai.parseText(text);
      if (!mounted) return;
      context.pushReplacement('/review', extra: ReviewArgs(items: items, meal: widget.initialMeal, transcript: text));
    } on AiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (!ref.watch(aiConfigProvider).ready) return const NScaffold(title: 'Voice log', body: AiKeyMissing());

    return NScaffold(
      title: 'Voice log',
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _sttReady && !_busy ? _toggle : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _listening ? 132 : 112,
                    height: _listening ? 132 : 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening ? t.accent : (_sttReady ? t.cta : t.track),
                    ),
                    child: Icon(_listening ? Icons.stop : Icons.mic_none, size: 44, color: t.onCta),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _listening ? 'listening' : (_sttReady ? 'tap to talk' : 'type below'),
                  style: NType.dot(24, t.ink),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _sttReady
                      ? 'e.g. “two scrambled eggs, a slice of toast with butter and a flat white”'
                      : 'Voice input isn’t available on this device.',
                  textAlign: TextAlign.center,
                  style: NType.serif(16, t.inkMuted),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _text,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                style: NType.mono(13, t.ink),
                decoration: const InputDecoration(hintText: 'OR TYPE WHAT YOU ATE'),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: NType.mono(11, t.accent)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _busy
              ? SizedBox(height: 52, child: Center(child: Text('thinking…', style: NType.dot(24, t.ink))))
              : BlackButton(
                  label: 'Log this',
                  icon: Icons.auto_awesome,
                  onPressed: _text.text.trim().isEmpty ? null : _analyze,
                ),
        ),
      ]),
    );
  }
}
