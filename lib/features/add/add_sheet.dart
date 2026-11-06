import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

/// The center "+" hub: Meal Scan (hero), Search, Voice, Barcode.
Future<void> showAddSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.tk.canvas,
    showDragHandle: true,
    // Lets the sheet grow to fit its content (large fonts) and scroll beyond that.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (sheetCtx) {
      final t = sheetCtx.tk;
      void go(String route) {
        Navigator.pop(sheetCtx);
        context.push(route);
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('log food', style: NType.dot(28, t.ink)),
              const SizedBox(height: 16),
              _Tile(
                hero: true,
                icon: Icons.photo_camera_outlined,
                title: 'Meal scan',
                caption: 'Snap your plate. AI estimates the portions.',
                onTap: () => go('/scan'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Tile(icon: Icons.search, title: 'Search', caption: 'Type any food', onTap: () => go('/search'))),
                const SizedBox(width: 10),
                Expanded(child: _Tile(icon: Icons.mic_none, title: 'Voice', caption: 'Say what you ate', onTap: () => go('/voice'))),
                const SizedBox(width: 10),
                Expanded(child: _Tile(icon: Icons.qr_code_scanner, title: 'Barcode', caption: 'Scan a package', onTap: () => go('/barcode'))),
              ]),
            ],
          ),
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.caption, required this.onTap, this.hero = false});
  final IconData icon;
  final String title, caption;
  final VoidCallback onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final fg = hero ? t.onCta : t.ink;
    return Material(
      color: hero ? t.cta : t.glass,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(hero ? 20 : 14),
          child: hero
              ? Row(children: [
                  Icon(icon, color: fg, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title.toUpperCase(), style: NType.mono(14, fg, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(caption, style: NType.serif(16, fg.withValues(alpha: 0.75))),
                    ]),
                  ),
                  Icon(Icons.arrow_forward, color: fg),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: fg, size: 24),
                  const SizedBox(height: 16),
                  Text(title.toUpperCase(), style: NType.mono(11, fg, weight: FontWeight.w700)),
                  Text(caption, style: NType.serif(13, t.inkMuted), maxLines: 2),
                ]),
        ),
      ),
    );
  }
}
