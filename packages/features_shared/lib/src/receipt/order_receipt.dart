import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../i18n/app_strings.dart';
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

/// Receipt wording in [lang] (`vi` / `en` / `ja`); the staff apps run in
/// Vietnamese, the customer app in the customer's language.
String receiptText(String vi, String lang) => switch (lang) {
      'en' => _receiptText[vi]?.$1 ?? vi,
      'ja' => _receiptText[vi]?.$2 ?? vi,
      _ => vi,
    };

/// The customer app's chosen language; Vietnamese wherever there is none
/// (staff apps keep the default, widget tests have no ProviderScope).
String _lang(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(localeProvider)
        .name;
  } catch (_) {
    return 'vi';
  }
}

const Map<String, (String, String)> _receiptText = {
  'Có giao dịch hoàn tiền': ('Refunded', '返金あり'),
  'Đang xử lý hoàn tiền': ('Refund in progress', '返金処理中'),
  'Đơn đã hủy': ('Order cancelled', 'キャンセル済み'),
  'Đã thanh toán': ('Paid', 'お支払い済み'),
  'Thanh toán chưa thành công': ('Payment failed', 'お支払い未完了'),
  'Chưa thanh toán': ('Unpaid', '未払い'),
  'Đóng hóa đơn': ('Close receipt', 'レシートを閉じる'),
  'Chưa lưu được ảnh hóa đơn. Vui lòng thử lại.': (
    "Couldn't save the receipt image. Please try again.",
    'レシート画像を保存できませんでした。もう一度お試しください。'
  ),
  'Đang chờ xác nhận từ cổng thanh toán.': (
    'Waiting for the payment gateway to confirm.',
    '決済代行会社からの確認を待っています。'
  ),
  'Cảm ơn bạn đã chọn Banan.': (
    'Thank you for choosing Banan.',
    'Bananをお選びいただきありがとうございます。'
  ),
  'Đang tạo ảnh…': ('Creating image…', '画像を作成中…'),
  'Chụp hóa đơn': ('Save receipt image', 'レシートを保存'),
  'Kiểm tra thanh toán': ('Check payment', 'お支払いを確認'),
  'PHIẾU THANH TOÁN': ('PAYMENT RECEIPT', 'お支払い明細'),
  'ĐT': ('Tel', 'TEL'),
  'Mã đơn': ('Order', '注文番号'),
  'Đặt lúc': ('Placed', '注文日時'),
  'Nhận hàng': ('Fulfilment', '受け取り方法'),
  'Tại cửa hàng': ('Pickup in store', '店頭受け取り'),
  'Giao hàng': ('Delivery', '配達'),
  'Hẹn nhận': ('Scheduled', 'ご予約日時'),
  'món': ('item', '点'),
  'Tạm tính': ('Subtotal', '小計'),
  'Giảm combo': ('Set discount', 'セット割引'),
  'Khuyến mãi': ('Promotion', 'キャンペーン割引'),
  'Mã giảm giá': ('Discount code', 'クーポン割引'),
  'Đổi điểm': ('Points redeemed', 'ポイント利用'),
  'Thẻ quà tặng': ('Gift card', 'ギフトカード'),
  'Phí giao hàng': ('Delivery fee', '配達料'),
  'TỔNG CỘNG': ('TOTAL', '合計'),
  'Phiếu xác nhận đơn hàng, không thay thế hóa đơn VAT.': (
    'Order confirmation — not a VAT invoice.',
    'ご注文確認書です。VATインボイスではありません。'
  ),
};

String receiptPaymentLabel(Order order, [String lang = 'vi']) {
  String t(String vi) => receiptText(vi, lang);
  if (order.refunds.any((r) => r.status == RefundStatus.completed) ||
      order.payments.any((p) => p.status == PaymentStatus.refunded)) {
    return t('Có giao dịch hoàn tiền');
  }
  if (order.refunds.any((r) => r.status != RefundStatus.rejected)) {
    return t('Đang xử lý hoàn tiền');
  }
  if (order.status == OrderStatus.cancelled) return t('Đơn đã hủy');
  if (receiptIsPaid(order)) return t('Đã thanh toán');
  if (order.payments.any((p) => p.status == PaymentStatus.failed)) {
    return t('Thanh toán chưa thành công');
  }
  return t('Chưa thanh toán');
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
                    tooltip: receiptText('Đóng hóa đơn', _lang(context)),
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
          SnackBar(
            content: Text(
              receiptText(
                'Chưa lưu được ảnh hóa đơn. Vui lòng thử lại.',
                _lang(context),
              ),
            ),
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
              receiptPaymentLabel(_order, _lang(context)),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              receiptText(
                _pending
                    ? 'Đang chờ xác nhận từ cổng thanh toán.'
                    : 'Cảm ơn bạn đã chọn Banan.',
                _lang(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _capture,
              icon: Icon(
                _saving ? Icons.hourglass_top : Icons.photo_camera_outlined,
              ),
              label: Text(
                receiptText(
                  _saving ? 'Đang tạo ảnh…' : 'Chụp hóa đơn',
                  _lang(context),
                ),
              ),
            ),
            if (_pending && widget.reload != null)
              TextButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(receiptText('Kiểm tra thanh toán', _lang(context))),
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
    final lang = _lang(context);
    String t(String vi) => receiptText(vi, lang);
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
                Text(
                  t('PHIẾU THANH TOÁN'),
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
                    '${t('ĐT')}: ${order.storePhone}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                divider,
                row(t('Mã đơn'), order.code),
                row(t('Đặt lúc'), DateFormat('dd/MM/yyyy HH:mm').format(date)),
                row(
                  t('Nhận hàng'),
                  order.fulfillmentType == FulfillmentType.pickup
                      ? t('Tại cửa hàng')
                      : t('Giao hàng'),
                ),
                if (order.scheduledFor != null)
                  row(
                    t('Hẹn nhận'),
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
                    '${money.format(item.unitPrice)} / ${t('món')}',
                    style: const TextStyle(color: Color(0xff69746d)),
                  ),
                  if (item.customMessage?.isNotEmpty ?? false)
                    Text(item.customMessage!),
                  const SizedBox(height: 8),
                ],
                divider,
                row(t('Tạm tính'), money.format(order.subtotal)),
                if (order.bundleDiscount > 0)
                  row(t('Giảm combo'),
                      '-${money.format(order.bundleDiscount)}'),
                if (order.campaignDiscount > 0)
                  row(t('Khuyến mãi'),
                      '-${money.format(order.campaignDiscount)}'),
                if (order.couponDiscount > 0)
                  row(t('Mã giảm giá'),
                      '-${money.format(order.couponDiscount)}'),
                if (order.pointsDiscount > 0)
                  row(t('Đổi điểm'), '-${money.format(order.pointsDiscount)}'),
                if (order.giftCardAmountVnd > 0)
                  row(
                    t('Thẻ quà tặng'),
                    '-${money.format(order.giftCardAmountVnd)}',
                  ),
                if (order.deliveryFee > 0)
                  row(t('Phí giao hàng'), money.format(order.deliveryFee)),
                divider,
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  child: row(t('TỔNG CỘNG'), money.format(order.total),
                      strong: true),
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
                    receiptPaymentLabel(order, lang).toUpperCase(),
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
                Text(
                  t('Phiếu xác nhận đơn hàng, không thay thế hóa đơn VAT.'),
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
