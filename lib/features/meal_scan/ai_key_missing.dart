import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';

/// Shown by AI features until an API key is saved in Settings.
class AiKeyMissing extends StatelessWidget {
  const AiKeyMissing({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('ai key', style: NType.dot(48, t.ink)),
        const SizedBox(height: 12),
        Text(
          'Meal scan and voice log need an AI API key. Gemini offers a free tier on some models. Add a key in Settings.',
          textAlign: TextAlign.center,
          style: NType.serif(19, t.inkMuted),
        ),
        const SizedBox(height: 24),
        BlackButton(label: 'Open settings', onPressed: () => context.push('/settings')),
      ]),
    );
  }
}
