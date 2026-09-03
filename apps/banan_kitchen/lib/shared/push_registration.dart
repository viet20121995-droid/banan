import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_token.dart';

Future<void> _fetchAndRegister(WidgetRef ref) async {
  try {
    final token = await getWebPushToken();
    if (token == null || token.isEmpty) return;
    await ref.read(devicesApiProvider).register(platform: 'WEB', token: token);
  } catch (_) {
    // Push is optional — never surface errors to staff.
  }
}

/// Registers a web-push token once per logged-in kitchen user.
class PushRegistrar extends ConsumerStatefulWidget {
  const PushRegistrar({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<PushRegistrar> createState() => _PushRegistrarState();
}

class _PushRegistrarState extends ConsumerState<PushRegistrar> {
  String? _doneForUserId;

  void _maybeRegister(AuthSession? session) {
    final user = session?.user;
    if (user == null) return;
    if (_doneForUserId == user.id) return;
    _doneForUserId = user.id;
    _fetchAndRegister(ref);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRegister(ref.read(authSessionProvider).valueOrNull);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(
      authSessionProvider,
      (_, next) => _maybeRegister(next.valueOrNull),
    );
    return widget.child;
  }
}
