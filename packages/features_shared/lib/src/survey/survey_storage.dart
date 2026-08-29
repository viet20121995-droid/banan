/// Browser storage helpers for the public survey (draft + anonymous reward
/// key). The real implementation needs `dart:js_interop`, which only exists
/// on web — VM builds (tests) get the no-op stub via the conditional export.
library;

export 'survey_storage_stub.dart' if (dart.library.html) 'survey_storage_web.dart';
