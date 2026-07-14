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

      // /orders/:id is auth-gated. A guest who just paid has no session, so
      // routing them there bounces them to /login (mirrors the returning-guest
      // branch in checkout_screen). The server IPN already captured the
      // payment, so confirm here and send them home instead.
      final session = ref.read(authRepositoryProvider).currentSession;
      if (session == null) {
        final status = widget.params['status'] ?? 'completed';
        final ok = status == 'success' || status == 'completed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Thanh toán thành công! Chúng tôi sẽ liên hệ xác nhận đơn của bạn.'
                  : 'Thanh toán chưa hoàn tất. Vui lòng thử lại hoặc liên hệ cửa hàng.',
            ),
          ),
        );
        context.go('/');
        return;
      }

      final orderId = widget.params['order_id'] ??
          widget.params['orderId'] ??
          widget.params['order'];
      if (orderId != null && orderId.isNotEmpty) {
        context.go('/orders/$orderId');
      } else {
        context.go('/orders');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.params['status'] ?? 'completed';
    final ok = status == 'success' || status == 'completed';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 56,
              color:
                  ok ? BananColors.success : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: BananSpacing.md),
            Text(
              ok ? 'Đã xác nhận thanh toán' : 'Thanh toán chưa hoàn tất',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: BananSpacing.sm),
            const Text('Đang chuyển sang đơn hàng của bạn…'),
          ],
        ),
      ),
    );
  }
}
