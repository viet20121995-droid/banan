import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Plays the new-order chime.
///
/// The actual WebAudio synthesis + autoplay-unlock lives in
/// `web/index.html` (`window.__bananChime`) so a single AudioContext is
/// created and resumed on the merchant's first interaction (login click).
/// Creating a fresh context here on each order would stay "suspended"
/// under the browser autoplay policy and produce no sound.
///
/// Non-web falls back to the system alert. Always best-effort.
void playNewOrderChime() {
  if (kIsWeb) {
    try {
      _jsEval('window.__bananChime && window.__bananChime()');
      return;
    } catch (_) {
      // fall through
    }
  }
  SystemSound.play(SystemSoundType.alert);
}
