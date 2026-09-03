import 'dart:js_interop';
import 'dart:math';

@JS('eval')
external JSAny? _jsEval(String code);

const _idChars = '0123456789abcdefghijklmnopqrstuvwxyz';
final _validId = RegExp(r'^[\w-]{8,64}$');

String _evalString(String code) {
  try {
    final r = _jsEval(code);
    final v = r?.dartify();
    return v is String ? v : '';
  } catch (_) {
    return '';
  }
}

/// mobile / tablet / desktop from the viewport width — enough for the
/// "% on phone" line of the daily report.
String deviceClass() {
  final w = int.tryParse(_evalString('String(window.innerWidth)')) ?? 1200;
  if (w < 768) return 'mobile';
  if (w < 1100) return 'tablet';
  return 'desktop';
}

/// Where this session came from: `utm_source` when a campaign link set one,
/// else the referrer host, else "direct". Never a full URL — a host is all
/// the report needs and all we want to store.
String trafficSource() {
  final utm = _evalString(
    'new URLSearchParams(window.location.search).get("utm_source") || ""',
  ).trim();
  if (utm.isNotEmpty) return utm.length > 60 ? utm.substring(0, 60) : utm;
  final host = _evalString(
    '(function(){try{return document.referrer?new URL(document.referrer).host:""}catch(e){return ""}})()',
  ).trim();
  if (host.isEmpty) return 'direct';
  return host.length > 100 ? host.substring(0, 100) : host;
}

/// The same anonymous visitor id the visit beacon persists in localStorage
/// (`banan_visitor`), so visits and behaviour events line up. Regenerated
/// when missing or malformed — the backend rejects anything else.
String visitorId() {
  final saved = _evalString(
    'window.__bananStorageGet ? window.__bananStorageGet("banan_visitor") : ""',
  );
  if (_validId.hasMatch(saved)) return saved;
  final rnd = Random();
  final id = List.generate(24, (_) => _idChars[rnd.nextInt(_idChars.length)]).join();
  _evalString('window.__bananStorageSet && window.__bananStorageSet("banan_visitor", "$id"); ""');
  return id;
}
