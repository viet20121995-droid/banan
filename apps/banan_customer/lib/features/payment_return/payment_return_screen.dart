import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lands here after Stripe / 9Pay / MoMo redirects the customer back to
/// the app. Server-side IPN/webhook is the source of truth for payment
/// status — this page just bridges the redirect tab back into the app.
class PaymentReturnScreen extends ConsumerStatefulWidget {
  const PaymentReturnScreen({
    required this.provider,
    required this.params,
    super.key,
  });

  final String provider;
  final Map<String, String> params;

  @override
  ConsumerState<PaymentReturnScreen> createState() =>
      _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Tiny delay so the user sees the page briefly.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final session = ref.read(authRepositoryProvider).currentSession;
      final orderId = widget.params['order_id'] ??
          widget.params['orderId'] ??
          widget.params['order'];

      if (orderId != null && orderId.isNotEmpty) {
        // Signed-in customers get the full order page (realtime + actions);
        // guests get the public tracking view. /orders/:id is auth-gated and
        // would bounce a guest to /login, even though the server IPN already
        // captured the payment.
        context.go(session != null ? '/orders/$orderId' : '/track/$orderId');
      } else if (session != null) {
        context.go('/orders');
      } else {
        // No order id to track and no session to list. Payment status is
        // verified server-side (IPN), never from the client URL — so don't
        // assert success here (the `status` param is user-spoofable). Just
        // acknowledge receipt and go home.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã nhận yêu cầu thanh toán. Chúng tôi sẽ xác nhận đơn của bạn qua email/điện thoại.',
            ),
          ),
        );
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately neutral. The authoritative payment status comes from the
    // server-backed page this bridge redirects to (/track or /orders) — never
    // from the client-controlled `status` URL param, which is spoofable. So we
    // show a plain "processing" state instead of a (fakeable) success tick.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: BananSpacing.md),
            Text(
              'Đang xử lý thanh toán…',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
