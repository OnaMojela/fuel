import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../food_detail/food_detail_screen.dart';

/// Camera barcode scan → Open Food Facts lookup → Food Detail.
class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key, required this.initialMeal});
  final Meal initialMeal;

  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends ConsumerState<BarcodeScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  final _manual = TextEditingController();
  bool _busy = false;
  String? _notFound; // barcode that had no match
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notFound = null;
      _error = null;
    });
    await _controller.stop();
    try {
      final food = await ref.read(offProvider).byBarcode(code);
      if (!mounted) return;
      if (food == null) {
        setState(() => _notFound = code);
      } else {
        context.pushReplacement('/food', extra: FoodDetailArgs(food: food, meal: widget.initialMeal));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Lookup failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rescan() async {
    setState(() {
      _notFound = null;
      _error = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return NScaffold(
      title: 'Barcode',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null && code.isNotEmpty) _lookup(code);
                  },
                  errorBuilder: (context, error) => Container(
                    color: t.glass,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text('Camera unavailable. Allow camera access, or type the barcode below.',
                        textAlign: TextAlign.center, style: NType.serif(17, t.inkMuted)),
                  ),
                ),
                // Viewfinder frame
                Center(
                  child: Container(
                    width: 240,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text('looking up…', style: NType.dot(24, Colors.white)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_notFound != null)
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Label('Not found'),
                const SizedBox(height: 6),
                Text('Barcode $_notFound isn’t in Open Food Facts yet.', style: NType.serif(17, t.ink)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _rescan,
                      child: Text('SCAN AGAIN', style: NType.mono(11, t.ink, weight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.cta),
                      onPressed: () => context.pushReplacement('/search?meal=${widget.initialMeal.index}'),
                      child: Text('SEARCH NAME', style: NType.mono(11, t.onCta, weight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            )
          else
            Text('Point at the barcode. It scans automatically.', textAlign: TextAlign.center, style: NType.serif(16, t.inkMuted)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: NType.mono(11, t.accent)),
          ],
          const SizedBox(height: 20),
          const Label('Or type the number'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _manual,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: NType.mono(14, t.ink),
                decoration: const InputDecoration(hintText: 'E.G. 5449000000996'),
                onSubmitted: (v) => v.length >= 8 ? _lookup(v) : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: t.cta, fixedSize: const Size(50, 50)),
              onPressed: () => _manual.text.length >= 8 ? _lookup(_manual.text) : null,
              icon: Icon(Icons.arrow_forward, color: t.onCta),
            ),
          ]),
        ],
      ),
    );
  }
}
