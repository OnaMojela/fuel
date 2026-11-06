import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';

class _Item {
  const _Item(this.title, this.icon, this.route);
  final String title;
  final IconData icon;
  final String route;
}

// Only features that work. (Placeholders were removed; add tiles back as
// features like sleep or steps get built.)
const _items = [
  _Item('Goals', Icons.flag_outlined, '/goals'),
  _Item('Nutrition', Icons.pie_chart_outline, '/nutrition'),
  _Item('Weekly report', Icons.calendar_view_week, '/report'),
  _Item('Recipes', Icons.menu_book_outlined, '/recipes'),
  _Item('Reminders', Icons.notifications_none, '/reminders'),
  _Item('Settings', Icons.settings_outlined, '/settings'),
  _Item('Help', Icons.help_outline, '/help'),
];

/// Grid of small tiles with serif captions, like the feature tiles on nothing.tech.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return NScaffold(
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          sliver: SliverToBoxAdapter(child: Text('more', style: NType.dot(34, t.ink))),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, kNavClearance),
          // Cell height = tile width + room for a 2-line caption (scaled with the
          // phone's font size). The square tile then takes whatever is left, so
          // the cell can never overflow.
          sliver: SliverLayoutBuilder(builder: (context, constraints) {
            final tileW = (constraints.crossAxisExtent - 2 * 12) / 3;
            final caption = MediaQuery.textScalerOf(context).scale(15) * 1.2 * 2 + 8;
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                mainAxisExtent: tileW + caption,
              ),
              itemCount: _items.length,
              itemBuilder: (context, idx) {
                final i = _items[idx];
                return GestureDetector(
                  onTap: () => context.push(i.route),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Center(child: Icon(i.icon, size: 30, color: t.ink)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i.title,
                      textAlign: TextAlign.center,
                      style: NType.serif(15, t.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                );
              },
            );
          }),
        ),
      ]),
    );
  }
}
