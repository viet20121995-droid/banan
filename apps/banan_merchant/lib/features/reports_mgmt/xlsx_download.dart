import 'dart:typed_data';

// Conditional import: the web build picks up `_web.dart` which uses Blob
// + AnchorElement to trigger the file download; on mobile we'd write to
// a path via `path_provider` instead. The stub here keeps a desktop /
// test build compilable.
import 'xlsx_download_stub.dart'
    if (dart.library.html) 'xlsx_download_web.dart' as impl;

/// Saves a byte buffer to the user's downloads — implementation is
/// platform-specific via conditional import. MIME is auto-derived from
/// the [filename] extension (xlsx / csv / pdf / json).
Future<void> saveXlsx(
  Uint8List bytes,
  String filename, {
  String? mimeOverride,
}) =>
    impl.saveXlsx(bytes, filename, mimeOverride: mimeOverride);
