import 'dart:js_interop';

/// Browser glue in web/index.html. Returns an empty token when push is denied
/// or unsupported.
@JS('__bananGetPushToken')
external JSPromise<JSString> _bananGetPushToken();

Future<String?> getWebPushToken() async {
  final token = await _bananGetPushToken().toDart;
  return token.toDart;
}
