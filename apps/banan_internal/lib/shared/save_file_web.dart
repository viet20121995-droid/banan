// Inline JS built by adjacent-string concatenation — the whitespace lint
// doesn't apply meaningfully to markup/code strings (same as print_ticket).
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Hands the browser a file to save (web-only; silently no-ops elsewhere).
/// Same eval-bridge pattern the merchant app uses for printing.
void saveBytesAsFile(Uint8List bytes, String filename, String mimeType) {
  if (!kIsWeb) return;
  final b64 = base64Encode(bytes);
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
  _jsEval(
    '(function(){var a=document.createElement("a");'
    'a.href="data:$mimeType;base64,$b64";'
    'a.download="$safeName";document.body.appendChild(a);a.click();a.remove();})();',
  );
}

/// Per-tab session storage. Holds the Mystery Shopper token after the URL
/// is stripped (history/screenshot/referrer hygiene) so a refresh in the
/// same tab keeps working. Both directions swallow storage errors —
/// blocked storage only costs the refresh case, never the first load.
void writeSessionValue(String key, String value) {
  if (!kIsWeb) return;
  try {
    _jsEval('sessionStorage.setItem(${jsonEncode(key)},${jsonEncode(value)})');
  } catch (_) {/* storage blocked (private mode) — in-memory copy still works */}
}

String? readSessionValue(String key) {
  if (!kIsWeb) return null;
  try {
    final res = _jsEval('sessionStorage.getItem(${jsonEncode(key)})');
    return (res as JSString?)?.toDart;
  } catch (_) {
    return null;
  }
}

void removeSessionValue(String key) {
  if (!kIsWeb) return;
  try {
    _jsEval('sessionStorage.removeItem(${jsonEncode(key)})');
  } catch (_) {/* storage blocked — nothing to remove */}
}

/// Per-BROWSER storage (survives the tab) — backs the survey's anonymous
/// reward key. Same error-swallowing contract as the session variants.
void writeLocalValue(String key, String value) {
  if (!kIsWeb) return;
  try {
    _jsEval('localStorage.setItem(${jsonEncode(key)},${jsonEncode(value)})');
  } catch (_) {/* storage blocked (private mode) — feature degrades gracefully */}
}

String? readLocalValue(String key) {
  if (!kIsWeb) return null;
  try {
    final res = _jsEval('localStorage.getItem(${jsonEncode(key)})');
    return (res as JSString?)?.toDart;
  } catch (_) {
    return null;
  }
}

/// Opens an external http(s) link in a new tab (web-only). Any other scheme
/// is refused — admin-entered URLs must never become javascript: execution.
/// Scheme match is case-insensitive (HTTPS://… is a valid URL).
void openExternalUrl(String url) {
  if (!kIsWeb) return;
  final u = url.trim();
  final scheme = Uri.tryParse(u)?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return;
  _jsEval('window.open(${jsonEncode(u)},"_blank","noopener,noreferrer")');
}

/// Opens the browser print dialog for the given HTML (web-only).
void printHtml(String html, String title) {
  if (!kIsWeb) return;
  final escaped = html
      .replaceAll(r'\', r'\\')
      .replaceAll('`', r'\`')
      .replaceAll(r'$', r'\$');
  _jsEval(
    '(function(){var w=window.open("","_blank","width=1100,height=800");'
    'if(!w)return;w.document.open();w.document.write(`$escaped`);'
    'w.document.close();w.focus();})();',
  );
}
