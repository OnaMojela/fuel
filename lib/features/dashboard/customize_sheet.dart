import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/ui_prefs.dart';
import '../../state/providers.dart';

/// "Make it yours": name, hero number, look and Today cards. Every change
/// applies instantly, so the page behind updates as you tap.
Future<void> showCustomizeSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      // Above the whole app, so the floating nav bar doesn't cover the panel.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.tk.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => const _CustomizeSheet(),
    );

class _CustomizeSheet extends ConsumerStatefulWidget {
  const _CustomizeSheet();

  @override
  ConsumerState<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends ConsumerState<_CustomizeSheet> {
  late final _name = TextEditingController(text: ref.read(displayNameProvider));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ui(UiPrefs Function(UiPrefs) change) => ref.read(uiPrefsProvider.notifier).update(change);

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ui = ref.watch(uiPrefsProvider);
    final mode = ref.watch(themeModeProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          Text('make it yours', style: NType.dot(28, t.ink)),
          const SizedBox(height: 20),

          const Label('Your name'),
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
          const SizedBox(height: 24),

          const Label('Hero number'),
          const SizedBox(height: 4),
          Text('What the big ring on Today tracks.', style: NType.serif(15, t.inkMuted)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            padding: EdgeInsets.zero, // no automatic safe-area padding inside the sheet
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: [
              for (final h in HeroMetric.values)
                _Choice(label: h.label, selected: ui.hero == h, onTap: () => _ui((u) => u.copyWith(hero: h))),
            ],
          ),
          const SizedBox(height: 24),

          const Label('Look'),
          const SizedBox(height: 10),
          Row(children: [
            for (final m in ThemeMode.values) ...[
              Expanded(
                child: _Choice(
                  label: m == ThemeMode.system ? 'Auto' : m.name,
                  selected: mode == m,
                  onTap: () => ref.read(themeModeProvider.notifier).set(m),
                ),
              ),
              if (m != ThemeMode.values.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(children: [
              // Live swatch of the accent.
              Container(width: 10, height: 10, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Shrink(Label('Nothing red', color: t.ink, size: 11)),
                  Text('Subtle red details: hero ring, active tab dot, log symbols, your badge.',
                      style: NType.serif(14, t.inkMuted)),
                ]),
              ),
              Switch(
                value: ui.accent,
                activeThumbColor: Colors.white,
                activeTrackColor: t.accent,
                onChanged: (v) => _ui((u) => u.copyWith(accent: v)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Choice(label: 'Solid rings', selected: !ui.glyphRings, onTap: () => _ui((u) => u.copyWith(glyphRings: false)))),
            const SizedBox(width: 8),
            Expanded(child: _Choice(label: '· · Glyph rings', selected: ui.glyphRings, onTap: () => _ui((u) => u.copyWith(glyphRings: true)))),
          ]),
          const SizedBox(height: 24),

          const Label('Today cards'),
          const SizedBox(height: 4),
          Text('Switch cards on or off; drag ≡ to reorder. Small cards pair up side by side.',
              style: NType.serif(15, t.inkMuted)),
          const SizedBox(height: 10),
          ReorderableListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
            // onReorderItem already adjusts the target index for the removed item.
            onReorderItem: (from, to) => _ui((u) {
              final cards = [...u.cards];
              cards.insert(to, cards.removeAt(from));
              return u.copyWith(cards: cards);
            }),
            children: [
              for (var i = 0; i < ui.cards.length; i++)
                Padding(
                  key: ValueKey(ui.cards[i].card),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    child: Row(children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.drag_handle, color: t.inkMuted)),
                      ),
                      Expanded(
                        child: Shrink(Text(ui.cards[i].card.label.toUpperCase(),
                            style: NType.mono(12, ui.cards[i].visible ? t.ink : t.inkMuted))),
                      ),
                      if (ui.cards[i].card.half) Text('½ ', style: NType.mono(10, t.inkMuted)),
                      Switch(
                        value: ui.cards[i].visible,
                        activeThumbColor: t.onCta,
                        activeTrackColor: t.cta,
                        onChanged: (v) => _ui((u) => u.copyWith(cards: [
                              for (final c in u.cards) c.card == ui.cards[i].card ? CardPref(c.card, v) : c,
                            ])),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _ui((u) => u.copyWith(cards: UiPrefs.defaultCards)),
            child: Text('RESET CARD ORDER', style: NType.mono(11, t.inkMuted)),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill in the Nothing style: black when chosen, tinted otherwise.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: selected ? t.cta : t.glass, borderRadius: BorderRadius.circular(6)),
        child: Shrink(
          Text(label.toUpperCase(), maxLines: 1, style: NType.mono(11, selected ? t.onCta : t.ink, weight: selected ? FontWeight.w700 : FontWeight.w400)),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
