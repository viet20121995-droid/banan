/// Browser download / print helpers. The real implementation needs
/// `dart:js_interop`, which only exists on web — VM builds (tests) get the
/// no-op stub via the conditional export, same pattern as `url_strategy`.
library;

export 'save_file_stub.dart' if (dart.library.html) 'save_file_web.dart';
