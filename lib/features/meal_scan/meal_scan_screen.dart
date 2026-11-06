import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/ai/ai_provider.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../review/review_screen.dart';
import 'ai_key_missing.dart';

/// Photo → AI → review. The photo is downscaled to 1024px before upload,
/// which keeps requests fast and cheap without hurting recognition.
class MealScanScreen extends ConsumerStatefulWidget {
  const MealScanScreen({super.key, required this.initialMeal});
  final Meal initialMeal;

  @override
  ConsumerState<MealScanScreen> createState() => _MealScanScreenState();
}

class _MealScanScreenState extends ConsumerState<MealScanScreen> {
  final _note = TextEditingController();
  Uint8List? _image;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _image = bytes;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}. Check app permissions.');
    }
  }

  Future<void> _analyze() async {
    final ai = ref.read(aiProvider);
    final img = _image;
    if (ai == null || img == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await ai.analyzeMeal(img, note: _note.text);
      if (!mounted) return;
      context.pushReplacement('/review', extra: ReviewArgs(items: items, meal: widget.initialMeal, image: img));
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
    final config = ref.watch(aiConfigProvider);
    if (!config.ready) return const NScaffold(title: 'Meal scan', body: AiKeyMissing());

    return NScaffold(
      title: 'Meal scan',
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              GestureDetector(
                onTap: _busy ? null : () => _pick(ImageSource.camera),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _image != null
                        ? Image.memory(_image!, fit: BoxFit.cover)
                        : Container(
                            color: t.glass,
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.photo_camera_outlined, size: 48, color: t.ink),
                              const SizedBox(height: 12),
                              Text('snap your plate', style: NType.dot(26, t.ink)),
                              const SizedBox(height: 6),
                              Text('Shoot from above, whole plate in frame.', style: NType.serif(16, t.inkMuted)),
                            ]),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _ghost(Icons.photo_camera_outlined, _image == null ? 'Camera' : 'Retake', () => _pick(ImageSource.camera))),
                const SizedBox(width: 8),
                Expanded(child: _ghost(Icons.photo_library_outlined, 'Gallery', () => _pick(ImageSource.gallery))),
              ]),
              const SizedBox(height: 16),
              const Label('Add context (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                enabled: !_busy,
                style: NType.mono(13, t.ink),
                decoration: const InputDecoration(hintText: 'E.G. FRIED IN BUTTER, HALF EATEN'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: NType.mono(11, t.accent)),
              ],
              const SizedBox(height: 16),
              Text('Using ${config.kind.label} · ${config.model}'.toUpperCase(), style: NType.mono(9, t.inkMuted)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _busy
              ? SizedBox(
                  height: 52,
                  child: Center(child: Text('analyzing…', style: NType.dot(24, t.ink))),
                )
              : BlackButton(label: 'Analyze meal', icon: Icons.auto_awesome, onPressed: _image == null ? null : _analyze),
        ),
      ]),
    );
  }

  Widget _ghost(IconData icon, String label, VoidCallback onTap) {
    final t = context.tk;
    return Material(
      color: t.glass,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _busy ? null : onTap,
        child: SizedBox(
          height: 46,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: t.ink),
            const SizedBox(width: 8),
            Text(label.toUpperCase(), style: NType.mono(11, t.ink, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
