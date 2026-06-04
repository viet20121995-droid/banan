import 'dart:typed_data';

/// Non-web stub. Until we wire `path_provider` for native, this just
/// surfaces a runtime error so we notice when the merchant launches a
/// build that can't download.
Future<void> saveXlsx(
  Uint8List bytes,
  String filename, {
  String? mimeOverride,
}) async {
  throw UnsupportedError(
    'Tải file chỉ hỗ trợ trên web build hiện tại.',
  );
}
