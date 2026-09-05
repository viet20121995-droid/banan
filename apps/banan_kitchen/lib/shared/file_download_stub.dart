import 'dart:typed_data';

/// Non-web stub — the kitchen is a web app; a native build would need
/// `path_provider` + a share sheet here.
Future<void> openOrSaveFile(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  throw UnsupportedError('Mở file chỉ hỗ trợ trên web build hiện tại.');
}
