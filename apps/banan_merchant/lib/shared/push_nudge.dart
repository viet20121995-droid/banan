import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_token.dart';

/// "Bật thông báo trình duyệt" bar under the app bar until the browser
/// permission is granted. Browsers only show the permission prompt from a
/// user gesture, so the automatic registration at login never asks — this
/// button does. Dismiss hides it for the session.
class PushNudge extends ConsumerStatefulWidget {
  const PushNudge({super.key});

  @override
  ConsumerState<PushNudge> createState() => _PushNudgeState();
}

class _PushNudgeState extends ConsumerState<PushNudge> {
  static bool _dismissed = false;
  String _permission = getWebPushPermission();
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final token = await getWebPushToken();
      if (token != null && token.isNotEmpty) {
        await ref
            .read(devicesApiProvider)
            .register(platform: 'WEB', token: token);
      }
    } catch (_) {
      // Best-effort — the permission state below tells the user what happened.
    }
    if (!mounted) return;
    setState(() {
      _permission = getWebPushPermission();
      _busy = false;
    });
    if (_permission == 'granted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bật thông báo đơn mới trên trình duyệt này.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed ||
        _permission == 'granted' ||
        _permission == 'unsupported' ||
        ref.watch(authSessionProvider).valueOrNull == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final denied = _permission == 'denied';
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.lg,
          vertical: BananSpacing.xs,
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, size: 18),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Text(
                denied
                    ? 'Trình duyệt đang chặn thông báo. Mở khoá ổ khoá cạnh '
                        'địa chỉ web → Thông báo → Cho phép, rồi tải lại.'
                    : 'Bật thông báo để nghe đơn mới ngay cả khi đang ở tab khác.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (!denied)
              FilledButton.tonal(
                onPressed: _busy ? null : _enable,
                child: const Text('Bật thông báo'),
              ),
            IconButton(
              tooltip: 'Để sau',
              onPressed: () => setState(() => _dismissed = true),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
