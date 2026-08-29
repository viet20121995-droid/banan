import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Per-tab session storage — keeps the survey draft across back/refresh in
/// the same tab. Both directions swallow storage errors: blocked storage
/// (private mode) only costs the refresh case, never the first load.
void writeSurveySessionValue(String key, String value) {
  if (!kIsWeb) return;
  try {
    _jsEval('sessionStorage.setItem(${jsonEncode(key)},${jsonEncode(value)})');
  } catch (_) {/* storage blocked — in-memory copy still works */}
}

String? readSurveySessionValue(String key) {
  if (!kIsWeb) return null;
  try {
    final res = _jsEval('sessionStorage.getItem(${jsonEncode(key)})');
    return (res as JSString?)?.toDart;
  } catch (_) {
    return null;
  }
}

void removeSurveySessionValue(String key) {
  if (!kIsWeb) return;
  try {
    _jsEval('sessionStorage.removeItem(${jsonEncode(key)})');
  } catch (_) {/* storage blocked — nothing to remove */}
}

/// Per-BROWSER storage (survives the tab) — backs the survey's anonymous
/// reward key. Same error-swallowing contract as the session variants.
void writeSurveyLocalValue(String key, String value) {
  if (!kIsWeb) return;
  try {
    _jsEval('localStorage.setItem(${jsonEncode(key)},${jsonEncode(value)})');
  } catch (_) {/* storage blocked — feature degrades gracefully */}
}

String? readSurveyLocalValue(String key) {
  if (!kIsWeb) return null;
  try {
    final res = _jsEval('localStorage.getItem(${jsonEncode(key)})');
    return (res as JSString?)?.toDart;
  } catch (_) {
    return null;
  }
}
