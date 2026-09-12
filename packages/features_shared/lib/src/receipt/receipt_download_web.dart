import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('document.createElement')
external _Anchor _createElement(String tag);

extension type _Anchor(JSObject _) implements JSObject {
  external String get href;
  external set href(String value);
  external String get download;
  external set download(String value);
  external void click();
}

void downloadReceipt(Uint8List bytes, String filename) {
  _createElement('a')
    ..href = 'data:image/png;base64,${base64Encode(bytes)}'
    ..download = filename
    ..click();
}
