import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/add/add_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Bottom padding screens inside the shell should leave for the floating nav.
const kNavClearance = 120.0;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.nav});
  final StatefulNavigationShell nav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: nav,
      bottomNavigationBar: _NavBar(
        index: nav.currentIndex,
        onTap: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: t.glass,
              child: Row(
                children: [
                  _item(context, 0, Icons.grid_view_rounded, 'Today'),
                  _item(context, 1, Icons.format_list_bulleted, 'Log'),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => showAddSheet(context),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: t.cta, shape: BoxShape.circle),
                          child: Icon(Icons.add, color: t.onCta, size: 28),
                        ),
                      ),
                    ),
                  ),
                  _item(context, 2, Icons.show_chart, 'Progress'),
                  _item(context, 3, Icons.more_horiz, 'More'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, String label) {
    final t = context.tk;
    final active = i == index;
    final c = active ? t.ink : t.inkMuted;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            // One line always; shrinks a touch on narrow phones instead of wrapping.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Shrink(
                Text(label.toUpperCase(), maxLines: 1, style: NType.mono(9, c, weight: active ? FontWeight.w700 : FontWeight.w400)),
                alignment: Alignment.center,
              ),
            ),
            const SizedBox(height: 3),
            // Active indicator: a single dot, Nothing-style.
            Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? t.detail(t.ink) : Colors.transparent)),
          ],
        ),
      ),
    );
  }
}
