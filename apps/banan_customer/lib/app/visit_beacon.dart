import 'dart:math';

import 'package:banan_data/banan_data.dart';
import 'package:flutter/foundation.dart';

import '../shared/web_storage.dart' as storage;

const _chars = '0123456789abcdefghijklmnopqrstuvwxyz';

// Mirrors the backend's /metrics/visit validation — a saved value that would
// be rejected (seeded/corrupted localStorage) is thrown away and regenerated,
// otherwise this browser would silently 400 on every launch forever.
final _validId = RegExp(r'^[\w-]{8,64}$');

/// Random visitor id persisted to localStorage, so repeat visits by the same
/// browser count as one unique in the daily traffic report. No account, no
/// cookie — just a meaningless random string.
String _visitorId() {
  final saved = storage.read('banan_visitor');
  if (saved != null && _validId.hasMatch(saved)) return saved;
  final rnd = Random();
  final id = List.generate(24, (_) => _chars[rnd.nextInt(_chars.length)]).join();
  storage.write('banan_visitor', id);
  return id;
}

/// Fire-and-forget visit beacon — feeds the daily traffic report email.
/// Web-only (the deployed storefront is what "site visits" means) and never
/// throws: a failed beacon must not affect the customer in any way.
Future<void> sendVisitBeacon() async {
  if (!kIsWeb) return;
  try {
    await createDioClient().post<void>(
      '/metrics/visit',
      data: {'visitorId': _visitorId()},
    );
  } catch (_) {}
}
