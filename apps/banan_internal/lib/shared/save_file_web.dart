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
