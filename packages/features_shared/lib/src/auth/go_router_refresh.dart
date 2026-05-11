import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] to a [Listenable] so it can be passed to GoRouter's
/// `refreshListenable`, causing the router's `redirect` callback to re-run
/// whenever the auth session emits a new value.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
