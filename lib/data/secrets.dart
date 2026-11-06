import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai/ai_provider.dart';

/// AI API keys, kept in the platform keystore (Keychain / Android Keystore).
/// Loaded once at startup and cached so providers can read them synchronously.
class Secrets {
  Secrets._(this._keys);
  final Map<AiKind, String> _keys;

  /// In-memory keys for tests (no platform keystore).
  @visibleForTesting
  factory Secrets.forTest([Map<AiKind, String> keys = const {}]) => Secrets._({...keys});

  static const _store = FlutterSecureStorage();
  static String _id(AiKind k) => 'ai_key_${k.name}';

  static Future<Secrets> load() async {
    Future<String?> read(AiKind k) async {
      try {
        return await _store.read(key: _id(k));
      } catch (_) {
        return null; // Unreadable keystore entry (e.g. after a backup restore): treat as unset.
      }
    }

    final values = await Future.wait(AiKind.values.map(read)); // keystore reads are slow; do them together
    return Secrets._({
      for (var i = 0; i < AiKind.values.length; i++)
        if (values[i]?.isNotEmpty ?? false) AiKind.values[i]: values[i]!,
    });
  }

  String keyFor(AiKind k) => _keys[k] ?? '';

  Future<void> setKey(AiKind k, String value) async {
    final v = value.trim();
    if (v.isEmpty) {
      _keys.remove(k);
      await _store.delete(key: _id(k));
    } else {
      _keys[k] = v;
      await _store.write(key: _id(k), value: v);
    }
  }
}
