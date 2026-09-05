import 'dart:js_interop';

/// Browser glue in web/index.html. Returns an empty token when push is denied
/// or unsupported.
@JS('__bananGetPushToken')
external JSPromise<JSString> _bananGetPushToken();

@JS('__bananPushPermission')
external JSString _bananPushPermission();

Future<String?> getWebPushToken() async {
  final token = await _bananGetPushToken().toDart;
  return token.toDart;
}

/// `granted` / `denied` / `default` / `unsupported` — the browser's
/// Notification permission for this site.
String getWebPushPermission() => _bananPushPermission().toDart;
