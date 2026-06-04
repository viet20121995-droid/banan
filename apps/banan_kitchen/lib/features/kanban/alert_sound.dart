import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@JS('eval')
external JSAny? _jsEval(String code);

/// Plays the kitchen "new ticket" chime. The WebAudio synthesis +
/// autoplay-unlock live in `web/index.html` (`window.__bananChime`) so a
/// single AudioContext is resumed on the staff's first interaction.
/// Non-web falls back to the system alert. Always best-effort.
void playNewTicketChime() {
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
