import 'push_token_stub.dart' if (dart.library.js_interop) 'push_token_web.dart'
    as implementation;

Future<String?> getWebPushToken() => implementation.getWebPushToken();
