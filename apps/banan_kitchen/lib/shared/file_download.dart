import 'dart:typed_data';

// Conditional import: the web build opens the bytes in a new tab (PDF) or
// downloads them; other platforms get the stub until a native path exists.
import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart'
    as impl;

/// Hands [bytes] to the user: a PDF opens in a new browser tab (print from
/// there), anything else downloads under [filename].
Future<void> openOrSaveFile(Uint8List bytes, String filename, String mime) =>
    impl.openOrSaveFile(bytes, filename, mime);
