import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'receipt_download.dart';

/// Payment truth comes from the API snapshot, never a gateway return parameter.
bool receiptIsPaid(Order order) =>
    order.status != OrderStatus.cancelled &&
    order.payments.any((p) => p.status == PaymentStatus.captured) &&
    order.payments
            .where((p) => p.status == PaymentStatus.captured)
            .fold<double>(0, (total, p) => total + p.amount) >=
        order.total &&
    !order.payments.any((p) => p.status == PaymentStatus.refunded) &&
    !order.refunds.any((r) => r.status != RefundStatus.rejected);

String receiptPaymentLabel(Order order) {
  if (order.refunds.any((r) => r.status == RefundStatus.completed) ||
      order.payments.any((p) => p.status == PaymentStatus.refunded)) {
    return 'Có giao dịch hoàn tiền';
  }
  if (order.refunds.any((r) => r.status != RefundStatus.rejected)) {
    return 'Đang xử lý hoàn tiền';
  }
  if (order.status == OrderStatus.cancelled) return 'Đơn đã hủy';
  if (receiptIsPaid(order)) return 'Đã thanh toán';
  if (order.payments.any((p) => p.status == PaymentStatus.failed)) {
    return 'Thanh toán chưa thành công';
  }
  return 'Chưa thanh toán';
}

Future<void> showOrderReceipt(BuildContext context, Order order) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xfff3f5f4),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Đóng hóa đơn',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                OrderReceipt(order: order),
              ],
            ),
          ),
        ),
      ),
    );

/// Thermal-paper receipt shared by the customer and counter-order workflows.
/// The boundary encloses the entire paper, even when it exceeds the viewport.
class OrderReceipt extends StatefulWidget {
  const OrderReceipt({
    required this.order,
    super.key,
    this.reload,
    this.saveImage,
  });

  final Order order;
  final Future<Order> Function()? reload;
  final void Function(Uint8List bytes, String filename)? saveImage;

  @override
  State<OrderReceipt> createState() => _OrderReceiptState();
}

class _OrderReceiptState extends State<OrderReceipt>
    with SingleTickerProviderStateMixin {
  final _paperKey = GlobalKey();
  late Order _order;
  late final AnimationController _feed;
  Timer? _timer;
  int _attempts = 0;
  bool _saving = false;
  bool _refreshing = false;

  bool get _pending =>
      _order.status != OrderStatus.cancelled &&
      !receiptIsPaid(_order) &&
      _order.payments.any(
        (p) =>
            p.provider != PaymentMethod.cash &&
            (p.status == PaymentStatus.initiated ||
                p.status == PaymentStatus.authorized),
      );

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _feed = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scheduleRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _feed.value = 1;
    } else if (!_feed.isAnimating && _feed.value == 0) {
      unawaited(_feed.forward());
    }
  }

  @override
  void didUpdateWidget(OrderReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order != widget.order) {
      _order = widget.order;
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    if (_pending && widget.reload != null && _attempts < 20) {
      _timer = Timer(const Duration(seconds: 3), _refresh);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || widget.reload == null) return;
    setState(() => _refreshing = true);
    _attempts++;
    try {
      final order = await widget.reload!();
      if (!mounted) return;
      setState(() => _order = order);
    } catch (_) {
      // Keep the last confirmed snapshot and allow an explicit retry.
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        _scheduleRefresh();
      }
    }
  }

  Future<void> _capture() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _feed.value = 1;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary = _paperKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      // Limit both texture dimensions for very long orders on mobile GPUs.
      final ratio = math.min(
        2.5,
        8000 /
            math.max(
              boundary.size.width,
              boundary.size.height,
            ),
      );
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('No PNG data');
        (widget.saveImage ?? downloadReceipt)(
          data.buffer.asUint8List(),
          'Banan-${_order.code.replaceAll(RegExp("[^a-zA-Z0-9_-]"), "_")}.png',
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được ảnh hóa đơn. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = receiptIsPaid(_order);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xff202c28),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(height: 3, color: const Color(0xff090f0c)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedBuilder(
                animation: _feed,
                child: RepaintBoundary(
                  key: _paperKey,
                  child: ReceiptPaper(order: _order),
                ),
                builder: (context, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: Curves.easeOutCubic.transform(_feed.value),
                    child: child,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              paid ? Icons.check_circle_outline : Icons.receipt_long_outlined,
              color: paid ? const Color(0xff216940) : const Color(0xff796238),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              receiptPaymentLabel(_order),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _pending
                  ? 'Đang chờ xác nhận từ cổng thanh toán.'
                  : 'Cảm ơn bạn đã chọn Banan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _capture,
              icon: Icon(
                _saving ? Icons.hourglass_top : Icons.photo_camera_outlined,
              ),
              label: Text(_saving ? 'Đang tạo ảnh…' : 'Chụp hóa đơn'),
            ),
            if (_pending && widget.reload != null)
              TextButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Kiểm tra thanh toán'),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({required this.order, super.key});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final paid = receiptIsPaid(order);
    final date = order.createdAt.toUtc().add(const Duration(hours: 7));
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: _ReceiptRule(),
    );
    return ClipPath(
      clipper: _PaperEdge(),
      child: ColoredBox(
        color: Colors.white,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.5,
            color: Color(0xff26332c),
            letterSpacing: 0,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand mark ships inside this package so every app that
                // shows a receipt (customer, merchant) has it.
                Center(
                  child: Image.asset(
                    'assets/brand/logo.png',
                    package: 'banan_features_shared',
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'BANAN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff216940),
                  ),
                ),
                const Text('FUKUOKA · SAIGON', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'PHIẾU THANH TOÁN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (order.storeName != null)
                  Text(order.storeName!, textAlign: TextAlign.center),
                if ((order.storeAddress ?? '').isNotEmpty)
                  Text(
                    order.storeAddress!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                if ((order.storePhone ?? '').isNotEmpty)
                  Text(
                    'ĐT: ${order.storePhone}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                divider,
                row('Mã đơn', order.code),
                row('Đặt lúc', DateFormat('dd/MM/yyyy HH:mm').format(date)),
                row(
                  'Nhận hàng',
                  order.fulfillmentType == FulfillmentType.pickup
                      ? 'Tại cửa hàng'
                      : 'Giao hàng',
                ),
                if (order.scheduledFor != null)
                  row(
                    'Hẹn nhận',
                    DateFormat('dd/MM/yyyy HH:mm').format(
                      order.scheduledFor!.toUtc().add(const Duration(hours: 7)),
                    ),
                  ),
                divider,
                for (final item in order.items) ...[
                  row(
                    '${item.quantity} × ${item.productName}',
                    money.format(item.lineTotal),
                    strong: true,
                  ),
                  if (item.variantLabel?.isNotEmpty ?? false)
                    Text(item.variantLabel!),
                  Text(
                    '${money.format(item.unitPrice)} / món',
                    style: const TextStyle(color: Color(0xff69746d)),
                  ),
                  if (item.customMessage?.isNotEmpty ?? false)
                    Text(item.customMessage!),
                  const SizedBox(height: 8),
                ],
                divider,
                row('Tạm tính', money.format(order.subtotal)),
                if (order.bundleDiscount > 0)
                  row('Giảm combo', '-${money.format(order.bundleDiscount)}'),
                if (order.campaignDiscount > 0)
                  row('Khuyến mãi', '-${money.format(order.campaignDiscount)}'),
                if (order.couponDiscount > 0)
                  row('Mã giảm giá', '-${money.format(order.couponDiscount)}'),
                if (order.pointsDiscount > 0)
                  row('Đổi điểm', '-${money.format(order.pointsDiscount)}'),
                if (order.giftCardAmountVnd > 0)
                  row(
                    'Thẻ quà tặng',
                    '-${money.format(order.giftCardAmountVnd)}',
                  ),
                if (order.deliveryFee > 0)
                  row('Phí giao hàng', money.format(order.deliveryFee)),
                divider,
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  child:
                      row('TỔNG CỘNG', money.format(order.total), strong: true),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: paid
                          ? const Color(0xff216940)
                          : const Color(0xff796238),
                    ),
                  ),
                  child: Text(
                    receiptPaymentLabel(order).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: paid
                          ? const Color(0xff216940)
                          : const Color(0xff796238),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('banancakes.vn', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'Phiếu xác nhận đơn hàng, không thay thế hóa đơn VAT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xff69746d)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRule extends StatelessWidget {
  const _ReceiptRule();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            (constraints.maxWidth / 9).floor(),
            (_) => const SizedBox(
              width: 4,
              height: 1,
              child: ColoredBox(color: Color(0xffbec7c1)),
            ),
          ),
        ),
      );
}

class _PaperEdge extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 6);
    for (double x = 0; x < size.width; x += 10) {
      path
        ..lineTo(x + 5, size.height)
        ..lineTo(math.min(x + 10, size.width), size.height - 6);
    }
    return path
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(_PaperEdge oldClipper) => false;
}
