import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';

const _faq = <(String, String)>[
  (
    'How accurate is meal scan?',
    'The AI identifies foods well, but portion sizes are estimates, usually within 10–25%. Always check the grams '
        'on the review screen before saving. Shooting from above with the whole plate in frame helps most. '
        'Adding a note like “fried in oil” improves the estimate.',
  ),
  (
    'Which AI should I use, and what does it cost?',
    'Choose Gemini, OpenAI or Claude in Settings and paste an API key from that provider. Gemini offers a free tier '
        'on some models. OpenAI and Claude are pay-as-you-go: a small model costs a fraction of a cent per scan. '
        'A ChatGPT subscription doesn’t include API access.',
  ),
  (
    'What does “SA · APPROX” mean?',
    'Built-in South African dishes (pap, boerewors, chakalaka…) use typical values for the dish as usually made. '
        'Home recipes vary, so treat them as estimates. For your own versions, create a Recipe.',
  ),
  (
    'Where does food data come from?',
    'Your recipes, built-in SA staples, Open Food Facts South Africa (packaged products sold here, and barcodes), '
        'and USDA FoodData Central (plain foods). Add a free USDA key in Settings to avoid its shared rate limit.',
  ),
  (
    'A barcode wasn’t found.',
    'Open Food Facts is crowd-sourced, so some local products are missing. Search by name instead, or use '
        'meal scan on the package’s nutrition label.',
  ),
  (
    'Where is my data stored?',
    'Everything stays on this phone. Nothing is uploaded except meal photos and voice text, which go only to the AI '
        'provider you chose, when you ask it to analyse them. API keys are kept in the phone’s secure keystore.',
  ),
  (
    'How do I move to a new phone?',
    'Settings → Export backup, save the file somewhere you can reach (e.g. Google Drive), then on the new phone use '
        'Settings → Restore from file. Re-enter your API key afterwards.',
  ),
  (
    'Reminders don’t arrive.',
    'Check that notifications are allowed for the app in your phone’s settings, and that battery optimisation isn’t '
        'blocking it. Reminders can arrive a few minutes late by design.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return NScaffold(
      title: 'Help',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          for (final (q, a) in _faq) ...[
            GlassCard(
              padding: EdgeInsets.zero,
              // Transparent Material so the tile's tap ripple has something to draw on.
              child: Material(
                type: MaterialType.transparency,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      q,
                      style: NType.mono(12, t.ink, weight: FontWeight.w700),
                    ),
                    iconColor: t.ink,
                    collapsedIconColor: t.inkMuted,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(a, style: NType.serif(17, t.inkMuted))],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
