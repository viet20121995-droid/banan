import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cart/cart_controller.dart';
import '../locations/locations_screen.dart' show storesListProvider;
import 'fulfillment_preference.dart';

const _deliveryFee = 30000.0;
const _vndPerPoint = 100;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  // Seeded from the menu-screen Pickup/Delivery choice in initState so the
  // customer doesn't have to pick fulfillment twice.
  late FulfillmentType _fulfillment;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  /// Hard-coded to TP.HCM — we only deliver in HCMC. Kept as a controller
  /// so the submit payload still carries the field; the form renders a
  /// read-only disabled tile instead of a TextField.
  final _city = TextEditingController(text: 'Thành phố Hồ Chí Minh');
  /// Selected HCMC ward (post-2025 reform) for the delivery address. Drives
  /// the distance-based delivery surcharge.
  String? _wardCode;

  final _notes = TextEditingController();
  final _coupon = TextEditingController();

  // VAT invoice (hóa đơn đỏ) — opt-in for company purchases.
  bool _requestVatInvoice = false;
  final _invoiceCompany = TextEditingController();
  final _invoiceTaxId = TextEditingController();
  final _invoiceAddress = TextEditingController();
  final _invoiceEmail = TextEditingController();
  CouponPreview? _appliedCoupon;
  String? _couponError;
  bool _validatingCoupon = false;
  // Gift card redemption.
  final _giftCtrl = TextEditingController();
  String? _giftCode;
  int? _giftBalance;
  String? _giftMsg;
  bool _giftBusy = false;
  // Loyalty point redemption — how many Micho points the (logged-in)
  // customer chose to burn on this order. Clamped to balance + order value
  // in build(); the backend caps it authoritatively too.
  int _pointsToRedeem = 0;
  bool _placing = false;
  String? _error;

  // Guest checkout fields — used only when there's no auth session.
  final _guestName = TextEditingController();
  final _guestPhone = TextEditingController();
  final _guestEmail = TextEditingController();

  /// `null` = order ASAP (default). Otherwise the customer-chosen pickup or
  /// delivery moment (sent to backend as `scheduledFor`).
  DateTime? _scheduledFor;

  /// Which Banan branch the customer wants to pick up from. Required when
  /// fulfillment = PICKUP. Pre-populated from the stores list once it loads.
  String? _pickupStoreId;

  @override
  void initState() {
    super.initState();
    // Inherit the Pickup/Delivery choice the customer made on the menu.
    _fulfillment = ref.read(fulfillmentPreferenceProvider);
    // Dismiss any "Đã thêm X vào giỏ" snackbar still showing from the
    // menu screen — once they're on checkout, "Xem giỏ" is redundant
    // and the message overlaps the bottom "Đặt hàng" button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).removeCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _notes.dispose();
    _coupon.dispose();
    _giftCtrl.dispose();
    _guestName.dispose();
    _guestPhone.dispose();
    _guestEmail.dispose();
    _invoiceCompany.dispose();
    _invoiceTaxId.dispose();
    _invoiceAddress.dispose();
    _invoiceEmail.dispose();
    super.dispose();
  }

  void _onFulfillmentChanged(FulfillmentType next) {
    // Keep the session-wide preference in sync so the menu toggle reflects
    // a change made here too.
    ref.read(fulfillmentPreferenceProvider.notifier).state = next;
    setState(() {
      _fulfillment = next;
      // Free-delivery coupon's discount changes when delivery fee changes;
      // simplest path is to clear the applied coupon when fulfillment flips.
      if (_appliedCoupon?.appliesToDelivery ?? false) {
        _appliedCoupon = null;
        _couponError = null;
      }
    });
  }

  Future<void> _applyCoupon(double cartSubtotal, double fee) async {
    final code = _coupon.text.trim();
    if (code.isEmpty) {
      setState(() {
        _appliedCoupon = null;
        _couponError = null;
      });
      return;
    }
    setState(() {
      _validatingCoupon = true;
      _couponError = null;
    });
    final repo = ref.read(couponRepositoryProvider);
    final result = await repo.validate(
      code: code,
      subtotalVnd: cartSubtotal.round(),
      deliveryFeeVnd: fee.round(),
    );
    if (!mounted) return;
    setState(() {
      _validatingCoupon = false;
      result.when(
        success: (preview) {
          _appliedCoupon = preview;
          _couponError = null;
        },
        failure: (f) {
          _appliedCoupon = null;
          _couponError = authFailureMessage(f);
        },
      );
    });
  }

  Future<void> _applyGiftCard() async {
    final code = _giftCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _giftCode = null;
        _giftBalance = null;
        _giftMsg = null;
      });
      return;
    }
    setState(() {
      _giftBusy = true;
      _giftMsg = null;
    });
    final res = await ref.read(giftCardsApiProvider).validate(code);
    if (!mounted) return;
    setState(() {
      _giftBusy = false;
      res.when(
        success: (v) {
          if (v.valid) {
            _giftCode = v.code;
            _giftBalance = v.balanceVnd;
            _giftMsg = null;
          } else {
            _giftCode = null;
            _giftBalance = null;
            _giftMsg = 'Mã không hợp lệ, đã hết hạn hoặc hết số dư.';
          }
        },
        failure: (f) {
          _giftCode = null;
          _giftBalance = null;
          _giftMsg = f.message ?? f.code;
        },
      );
    });
  }

  Future<void> _place() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // Surface a visible hint instead of silently doing nothing — the
      // invalid field(s) above are highlighted but may be scrolled off.
      setState(
        () =>
            _error = 'Vui lòng điền đầy đủ các thông tin còn thiếu phía trên.',
      );
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });

    final isGuest = ref.read(authSessionProvider).valueOrNull == null;
    final cart = ref.read(cartControllerProvider);

    // Re-clamp the chosen points against the live balance + order value so we
    // never send more than the customer can actually burn. Guests redeem
    // nothing. The backend re-caps authoritatively; this keeps the request
    // honest and matches the on-screen preview.
    final membership = isGuest
        ? null
        : ref.read(membershipSummaryProvider).valueOrNull;
    final couponDiscount = _appliedCoupon?.discount ?? 0.0;
    final subtotalAfterCoupon =
        (cart.subtotal - couponDiscount).clamp(0.0, double.infinity);
    final maxRedeemable = (subtotalAfterCoupon ~/ _vndPerPoint)
        .clamp(0, membership?.balance ?? 0);
    final pointsToRedeem = _pointsToRedeem.clamp(0, maxRedeemable);

    final draft = NewOrder(
      items: cart.items
          .map(
            (i) => NewOrderItem(
              productId: i.productId,
              variantId: i.variantId,
              quantity: i.quantity,
              customMessage: i.customMessage,
              personalization: i.personalization,
            ),
          )
          .toList(),
      fulfillmentType: _fulfillment,
      paymentMethod: _paymentMethod,
      address: _fulfillment == FulfillmentType.delivery
          ? NewAddress(
              recipient: _recipient.text.trim(),
              phone: _phone.text.trim(),
              line1: _line1.text.trim(),
              city: _city.text.trim(),
              wardCode: _wardCode,
            )
          : null,
      // Lock in the routed branch from the live quote so the order ends
      // up at the same branch the customer saw on the checkout breakdown.
      deliveryStoreId: _fulfillment == FulfillmentType.delivery
          ? ref
              .read(_deliveryQuoteProvider((
                wardCode: _wardCode,
                productIdsCsv:
                    cart.items.map((i) => i.productId).join(','),
              )))
              .valueOrNull
              ?.store
              ?.id
          : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      couponCode: _appliedCoupon?.code,
      giftCardCode: _giftCode,
      pointsToRedeem: pointsToRedeem > 0 ? pointsToRedeem : null,
      scheduledFor: _scheduledFor,
      guestFullName: isGuest ? _guestName.text.trim() : null,
      guestPhone: isGuest ? _guestPhone.text.trim() : null,
      guestEmail: isGuest && _guestEmail.text.trim().isNotEmpty
          ? _guestEmail.text.trim()
          : null,
      pickupStoreId:
          _fulfillment == FulfillmentType.pickup ? _pickupStoreId : null,
      requestVatInvoice: _requestVatInvoice,
      invoiceCompanyName:
          _requestVatInvoice ? _invoiceCompany.text.trim() : null,
      invoiceTaxId: _requestVatInvoice ? _invoiceTaxId.text.trim() : null,
      invoiceAddress:
          _requestVatInvoice ? _invoiceAddress.text.trim() : null,
      invoiceEmail: _requestVatInvoice ? _invoiceEmail.text.trim() : null,
    );

    final repo = ref.read(orderRepositoryProvider);
    final result = await repo.placeOrder(draft);

    if (!mounted) return;
    setState(() => _placing = false);

    result.when(
      success: (placed) async {
        ref.read(cartControllerProvider.notifier).clear();

        // Guest checkout for a NEW phone gets fresh tokens from the backend —
        // adopt them so the customer is logged in for order tracking. A
        // RETURNING guest (existing phone) does NOT get a session (avoids
        // phone-only account takeover), so we handle that case below.
        if (placed.guestSession != null) {
          await ref
              .read(authRepositoryProvider)
              .adoptSession(placed.guestSession!);
        }

        if (placed.payment.configurationError != null) {
          setState(() => _error = placed.payment.configurationError);
          return;
        }

        // Redirect-based payment (VNPay / MoMo / Stripe): navigate the SAME
        // tab to the gateway. A new-tab popup ('_blank') gets silently
        // blocked by the browser because this runs after an `await` (no
        // longer a direct user gesture) — which looked like "nothing
        // happens". The provider's return URL brings the customer back.
        if (placed.payment.hasRedirect) {
          await launchUrl(
            Uri.parse(placed.payment.redirectUrl!),
            webOnlyWindowName: '_self',
          );
          return;
        }
        if (!context.mounted) return;

        final session = ref.read(authRepositoryProvider).currentSession;
        if (session != null) {
          // Logged-in customer or freshly-created guest → full order tracking.
          ref.invalidate(membershipSummaryProvider);
          context.go('/orders/${placed.order.id}');
        } else {
          // Returning guest (no session): the order page is auth-gated, so
          // confirm here and return home instead of bouncing to the login
          // screen. The order IS placed — staff will process it.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đặt hàng thành công! Chúng tôi sẽ liên hệ xác nhận đơn của bạn.',
              ),
            ),
          );
          context.go('/');
        }
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isGuest = session == null;
    final membership = isGuest
        ? null
        : ref.watch(membershipSummaryProvider).valueOrNull;
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    // Read the most recent quote (if any) so the on-page total mirrors what
    // the backend will charge. Backend auto-routes to the nearest open
    // branch from the ward, applies the right tier (birthday cake vs.
    // standard) from the admin's DeliveryConfig, and returns the final fee.
    final productIdsCsv = cart.items.map((i) => i.productId).join(',');
    final quoteKey = (
      wardCode: _wardCode,
      productIdsCsv: productIdsCsv,
    );
    double deliveryFee = 0;
    if (_fulfillment == FulfillmentType.delivery) {
      final qAsync = ref.watch(_deliveryQuoteProvider(quoteKey));
      deliveryFee = qAsync.valueOrNull?.totalVnd.toDouble() ?? 0;
    }
    final fee = _fulfillment == FulfillmentType.delivery ? deliveryFee : 0.0;
    final couponDiscount = _appliedCoupon?.discount ?? 0.0;
    final subtotalAfterCoupon = (cart.subtotal - couponDiscount).clamp(0.0, double.infinity);
    final maxRedeemable = (subtotalAfterCoupon ~/ _vndPerPoint)
        .clamp(0, membership?.balance ?? 0);
    final pointsActuallyUsed = _pointsToRedeem.clamp(0, maxRedeemable);
    final pointsDiscount = pointsActuallyUsed * _vndPerPoint.toDouble();
    final total = (cart.subtotal - couponDiscount - pointsDiscount + fee)
        .clamp(0.0, double.infinity);
    // Gift-card preview — backend applies min(balance, total) authoritatively;
    // this just shows the customer what they'll actually pay.
    final giftPreview = (_giftCode != null && _giftBalance != null)
        ? _giftBalance!.toDouble().clamp(0.0, total)
        : 0.0;
    final totalAfterGift = (total - giftPreview).clamp(0.0, double.infinity);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.checkout)),
        body: EmptyState(
          title: s.emptyCartTitle,
          message: s.emptyCartMsg,
          icon: Icons.shopping_bag_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.checkout)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.lg),
          child: PrimaryButton(
            label: '${s.placeOrder} · ${fmt.format(totalAfterGift)}',
            loading: _placing,
            expand: true,
            onPressed: _place,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(BananSpacing.md),
                        margin:
                            const EdgeInsets.only(bottom: BananSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BananRadii.rmd,
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.4),
                        ),
                        child: Text(_error!),
                      ),
                    if (isGuest) ...[
                      _GuestContactSection(
                        nameController: _guestName,
                        phoneController: _guestPhone,
                        emailController: _guestEmail,
                      ),
                      const SizedBox(height: BananSpacing.xl),
                    ],
                    Text(s.fulfillment, style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    SegmentedButton<FulfillmentType>(
                      segments: [
                        ButtonSegment(
                          value: FulfillmentType.pickup,
                          label: Text(s.pickup),
                          icon: const Icon(Icons.storefront_outlined),
                        ),
                        ButtonSegment(
                          value: FulfillmentType.delivery,
                          label: Text(s.delivery),
                          icon: const Icon(Icons.delivery_dining_outlined),
                        ),
                      ],
                      selected: {_fulfillment},
                      onSelectionChanged: (set) =>
                          _onFulfillmentChanged(set.first),
                    ),
                    if (_fulfillment == FulfillmentType.pickup) ...[
                      const SizedBox(height: BananSpacing.xl),
                      Text(
                        s.pickupBranch,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      _PickupStorePicker(
                        selectedId: _pickupStoreId,
                        onSelect: (id) =>
                            setState(() => _pickupStoreId = id),
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text(
                      _fulfillment == FulfillmentType.delivery
                          ? s.whenDeliver
                          : s.whenReady,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    _ScheduleSection(
                      value: _scheduledFor,
                      onChanged: (next) =>
                          setState(() => _scheduledFor = next),
                    ),
                    if (_fulfillment == FulfillmentType.delivery) ...[
                      const SizedBox(height: BananSpacing.xl),
                      Text(
                        s.deliveryAddress,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _recipient,
                        decoration:
                            InputDecoration(labelText: s.recipient),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? s.required : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: s.phone),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? s.required : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _line1,
                        decoration: InputDecoration(
                          labelText: s.addressLine,
                          helperText: 'VD: 15B8 Lê Thánh Tôn',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? s.required : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      // Locked — Banan chỉ giao trong TP.HCM. The field is
                      // intentionally read-only so customers can't enter
                      // an out-of-city address that the routing can't
                      // resolve a fee for.
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: s.city,
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          enabled: false,
                          helperText: 'Hiện Banan chỉ giao trong TP.HCM',
                        ),
                        child: Text(
                          'Thành phố Hồ Chí Minh',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: BananSpacing.md),
                      // HCMC post-2025 ward picker. Required for accurate
                      // delivery distance check; without it we charge base
                      // fee regardless of where the customer is.
                      _CheckoutWardPicker(
                        selectedCode: _wardCode,
                        onChanged: (code) =>
                            setState(() => _wardCode = code),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      // Live quote — surfaces the 15.000₫ surcharge for
                      // addresses beyond the 3 km radius (and the higher
                      // birthday-cake tier when applicable) before submit.
                      _DeliveryQuoteBox(
                        wardCode: _wardCode,
                        productIds:
                            cart.items.map((i) => i.productId).toList(),
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text(s.savings, style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    _CouponField(
                      controller: _coupon,
                      applied: _appliedCoupon,
                      validating: _validatingCoupon,
                      error: _couponError,
                      onApply: () => _applyCoupon(cart.subtotal, fee),
                      onClear: () => setState(() {
                        _coupon.clear();
                        _appliedCoupon = null;
                        _couponError = null;
                      }),
                      fmt: fmt,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    // Gift card redemption.
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _giftCtrl,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Mã thẻ quà tặng',
                              prefixIcon: Icon(Icons.card_giftcard_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: BananSpacing.sm),
                        FilledButton(
                          onPressed: _giftBusy ? null : _applyGiftCard,
                          child: Text(_giftBusy ? '…' : 'Áp dụng'),
                        ),
                      ],
                    ),
                    if (_giftCode != null && _giftBalance != null)
                      Padding(
                        padding: const EdgeInsets.only(top: BananSpacing.xs),
                        child: Text(
                          'Thẻ $_giftCode · số dư ${fmt.format(_giftBalance)} '
                          '— trừ ${fmt.format(giftPreview)} vào đơn này.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: BananColors.success),
                        ),
                      ),
                    if (_giftMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: BananSpacing.xs),
                        child: Text(
                          _giftMsg!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    // Loyalty point redemption — only for a logged-in customer
                    // who actually has points. Guests + zero-balance accounts
                    // never see this block.
                    if (membership != null && membership.balance > 0) ...[
                      const SizedBox(height: BananSpacing.lg),
                      _PointsRedeemer(
                        balance: membership.balance,
                        max: maxRedeemable,
                        value: pointsActuallyUsed,
                        vndPerPoint: _vndPerPoint,
                        onChanged: (v) =>
                            setState(() => _pointsToRedeem = v),
                        fmt: fmt,
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text(s.payment, style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    _PaymentSelector(
                      fulfillment: _fulfillment,
                      selected: _paymentMethod,
                      onChanged: (m) => setState(() => _paymentMethod = m),
                    ),
                    const SizedBox(height: BananSpacing.xl),
                    TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: s.notesOptional,
                      ),
                    ),
                    const SizedBox(height: BananSpacing.xl),
                    _VatInvoiceSection(
                      enabled: _requestVatInvoice,
                      onToggle: (v) =>
                          setState(() => _requestVatInvoice = v),
                      company: _invoiceCompany,
                      taxId: _invoiceTaxId,
                      address: _invoiceAddress,
                      email: _invoiceEmail,
                    ),
                    const SizedBox(height: BananSpacing.xxl),
                    _Summary(
                      cart: cart,
                      fee: fee,
                      couponDiscount: couponDiscount,
                      pointsDiscount: pointsDiscount,
                      total: total,
                      fmt: fmt,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible "Xuất hoá đơn VAT" block. Hidden by default; expanding it
/// reveals the 4 required company-invoice fields (tên, MST, địa chỉ, email).
class _VatInvoiceSection extends StatelessWidget {
  const _VatInvoiceSection({
    required this.enabled,
    required this.onToggle,
    required this.company,
    required this.taxId,
    required this.address,
    required this.email,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController company;
  final TextEditingController taxId;
  final TextEditingController address;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: BananSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onToggle,
            title: const Text('Xuất hoá đơn VAT (hoá đơn đỏ)'),
            subtitle: Text(
              enabled
                  ? 'Hoá đơn sẽ được gửi qua email sau khi đơn hoàn tất.'
                  : 'Bật khi cần hoá đơn cho công ty.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: BananSpacing.xs),
            TextFormField(
              controller: company,
              decoration: const InputDecoration(
                labelText: 'Tên công ty',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: taxId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã số thuế',
                helperText: '8–13 chữ số.',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ công ty',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email nhận hoá đơn',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CouponField extends ConsumerWidget {
  const _CouponField({
    required this.controller,
    required this.applied,
    required this.validating,
    required this.error,
    required this.onApply,
    required this.onClear,
    required this.fmt,
  });

  final TextEditingController controller;
  final CouponPreview? applied;
  final bool validating;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    if (applied != null) {
      return Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: BananColors.success.withValues(alpha: 0.08),
          border: Border.all(color: BananColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: BananColors.success, size: 20,),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    applied!.code,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    applied!.appliesToDelivery
                        ? s.freeDelivery
                        : '−${fmt.format(applied!.discount)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: s.couponCode,
                  prefixIcon:
                      const Icon(Icons.local_offer_outlined, size: 20),
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            const SizedBox(width: BananSpacing.sm),
            FilledButton.tonal(
              onPressed: validating ? null : onApply,
              child: validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.apply),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: BananSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Dùng điểm Micho" — loyalty point redemption block. Shows the available
/// balance, a slider to pick how many points to burn (0..max, where max is
/// capped by both the balance and the order value), and the resulting
/// discount preview. Rendered only for a logged-in customer with points.
class _PointsRedeemer extends StatelessWidget {
  const _PointsRedeemer({
    required this.balance,
    required this.max,
    required this.value,
    required this.vndPerPoint,
    required this.onChanged,
    required this.fmt,
  });

  final int balance;
  final int max;
  final int value;
  final int vndPerPoint;
  final ValueChanged<int> onChanged;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxClamped = max.clamp(0, balance);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  'Dùng điểm Micho',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (value > 0)
                Text(
                  '≈ −${fmt.format(value * vndPerPoint)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bạn có $balance điểm (≈ ${fmt.format(balance * vndPerPoint)})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (maxClamped == 0)
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.xs),
              child: Text(
                'Giá trị đơn hàng chưa đủ để đổi điểm.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else ...[
            Slider(
              min: 0,
              max: maxClamped.toDouble(),
              divisions: maxClamped,
              value: value.toDouble().clamp(0, maxClamped.toDouble()),
              label: '$value điểm',
              onChanged: (v) => onChanged(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đổi $value/$maxClamped điểm',
                  style: theme.textTheme.bodySmall,
                ),
                if (value > 0)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BananSpacing.sm,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => onChanged(0),
                    child: const Text('Bỏ chọn'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentSelector extends ConsumerWidget {
  const _PaymentSelector({
    required this.fulfillment,
    required this.selected,
    required this.onChanged,
  });

  final FulfillmentType fulfillment;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cash on receipt (COD) is the active method while VNPay API keys aren't
    // configured yet. Stripe/MoMo backend providers still work too. To turn a
    // method back on, just add its row here, e.g.:
    //   (PaymentMethod.vnpay, Icons.account_balance_outlined, s.vnpayHint),
    final options = <(PaymentMethod, IconData, String)>[
      (PaymentMethod.cash, Icons.payments_outlined, 'Trả tiền mặt khi nhận hàng'),
    ];
    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: _PaymentRow(
              method: option.$1,
              icon: option.$2,
              hint: option.$3,
              selected: selected == option.$1,
              onTap: () => onChanged(option.$1),
            ),
          ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    required this.icon,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final IconData icon;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rmd,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
          border: Border.all(
            color: color,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: theme.textTheme.titleSmall),
                  Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.cart,
    required this.fee,
    required this.couponDiscount,
    required this.pointsDiscount,
    required this.total,
    required this.fmt,
  });

  final CartState cart;
  final double fee;
  final double couponDiscount;
  final double pointsDiscount;
  final double total;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.summary, style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          for (final item in cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: BananSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}× ${item.productName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(fmt.format(item.lineTotal)),
                ],
              ),
            ),
          const Divider(height: BananSpacing.lg),
          _Line(label: s.subtotal, value: fmt.format(cart.subtotal)),
          if (couponDiscount > 0)
            _Line(
              label: s.coupon,
              value: '−${fmt.format(couponDiscount)}',
              accent: true,
            ),
          if (pointsDiscount > 0)
            _Line(
              label: s.pointsDiscount,
              value: '−${fmt.format(pointsDiscount)}',
              accent: true,
            ),
          _Line(label: s.deliveryFee, value: fmt.format(fee)),
          const SizedBox(height: BananSpacing.sm),
          _Line(label: s.total, value: fmt.format(total), bold: true),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.accent = false,
  });
  final String label;
  final String value;
  final bool bold;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    final style = accent
        ? base?.copyWith(color: theme.colorScheme.primary)
        : base;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

/// Pickup branch selector — radio list of all Banan stores, rendered from
/// the same `storesListProvider` the Locations screen uses. Auto-selects
/// the first branch when the list first loads, so the customer doesn't
/// have to tap anything to use the default.
class _PickupStorePicker extends ConsumerStatefulWidget {
  const _PickupStorePicker({required this.selectedId, required this.onSelect});
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  ConsumerState<_PickupStorePicker> createState() =>
      _PickupStorePickerState();
}

class _PickupStorePickerState extends ConsumerState<_PickupStorePicker> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(storesListProvider);
    final s = ref.watch(stringsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: BananSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        s.couldNotLoadBranches,
        style: theme.textTheme.bodySmall,
      ),
      data: (stores) {
        // Auto-select the first *available* branch the first time we see
        // the list — skipping any that have pickup paused, so the customer
        // never lands on a blocked default. Falls back to the first store
        // if every branch is paused (so the picker still renders something).
        if (widget.selectedId == null && stores.isNotEmpty) {
          final firstOpen = stores.firstWhere(
            (s) => s.acceptsPickup,
            orElse: () => stores.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onSelect(firstOpen.id);
          });
        }
        // If the currently selected store gets paused (rare but possible
        // when the page is open while the merchant toggles), bounce to
        // the next available one automatically.
        final sel = widget.selectedId == null
            ? null
            : stores.cast<Store?>().firstWhere(
                  (s) => s?.id == widget.selectedId,
                  orElse: () => null,
                );
        if (sel != null && !sel.acceptsPickup) {
          final next = stores.firstWhere(
            (s) => s.acceptsPickup,
            orElse: () => sel,
          );
          if (next.id != sel.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onSelect(next.id);
            });
          }
        }
        return Column(
          children: [
            for (final store in stores)
              Padding(
                padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                child: _StoreOption(
                  store: store,
                  selected: store.id == widget.selectedId,
                  // Disable selection when this branch isn't accepting
                  // pickup; the badge inside the tile explains why.
                  onTap: store.acceptsPickup
                      ? () => widget.onSelect(store.id)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoreOption extends StatelessWidget {
  const _StoreOption({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  final Store store;
  final bool selected;

  /// Null = this branch is paused and can't be selected. The tile renders
  /// dimmed with a "Đang tạm nghỉ" badge instead.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BananRadii.rmd,
        child: Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : (theme.dividerTheme.color ?? Colors.black12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                disabled
                    ? Icons.block
                    : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                color: disabled
                    ? theme.colorScheme.outline
                    : (selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline),
                size: 22,
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: BananSpacing.sm),
                        if (disabled)
                          _PausedChip(reason: store.pauseReason)
                        else
                          _OpenClosedChip(open: store.isOpenNow),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.address,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (disabled && (store.pauseReason?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          store.pauseReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Đang tạm nghỉ" badge shown on a paused branch tile.
class _PausedChip extends StatelessWidget {
  const _PausedChip({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Đang tạm nghỉ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tiny green "Open" / grey "Closed" pill.
class _OpenClosedChip extends ConsumerWidget {
  const _OpenClosedChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = open ? BananColors.success : BananColors.cocoaSoft;
    final t = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        open ? t.openNow : t.closedNow,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Guest-checkout contact form. Required when no auth session — collects
/// the minimum the merchant + delivery driver need (name, phone, optional
/// email for receipt + birthday-treat notifications).
class _GuestContactSection extends ConsumerWidget {
  const _GuestContactSection({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.yourDetails, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.weWillText,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              // Use this widget's own context so the GoRouter lookup
              // happens at click time against the current widget tree —
              // sidesteps any "stale parent context" weirdness.
              Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => ctx.go('/login?next=/cart'),
                  child: Text(t.haveAccount),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: t.fullName),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.required : null,
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: t.phone,
              hintText: '+84…',
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return t.required;
              if (val.length < 7) return t.phoneTooShort;
              return null;
            },
          ),
          const SizedBox(height: BananSpacing.md),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: t.emailOptional,
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return null;
              if (!val.contains('@') || !val.contains('.')) {
                return t.invalidEmail;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

/// "As soon as possible" vs "Schedule for later" toggle. When the customer
/// picks a future date+time, [onChanged] fires with the chosen DateTime.
/// Same picker for pickup or delivery — the parent screen relabels above it.
class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  static const _minLeadMinutes = 30;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now.add(const Duration(hours: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Guard rail: refuse picks too close to now — the store needs lead time.
    final earliest = now.add(const Duration(minutes: _minLeadMinutes));
    onChanged(picked.isBefore(earliest) ? earliest : picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final isScheduled = value != null;
    final fmt = DateFormat.yMMMEd().add_jm();

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s.scheduleNow),
                icon: const Icon(Icons.flash_on_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(s.scheduleLater),
                icon: const Icon(Icons.event_outlined),
              ),
            ],
            selected: {isScheduled},
            onSelectionChanged: (set) {
              if (set.first) {
                _pick(context);
              } else {
                onChanged(null);
              }
            },
          ),
          if (isScheduled) ...[
            const SizedBox(height: BananSpacing.md),
            InkWell(
              onTap: () => _pick(context),
              borderRadius: BananRadii.rmd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BananSpacing.sm,
                  vertical: BananSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: theme.colorScheme.primary),
                    const SizedBox(width: BananSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fmt.format(value!),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            _relativeLabel(value!, s),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeLabel(DateTime when, AppStrings s) {
    final diff = when.difference(DateTime.now());
    if (diff.inMinutes < 60) return s.inMinutes(diff.inMinutes);
    if (diff.inHours < 24) return s.inHours(diff.inHours);
    final days = diff.inDays;
    return days == 1 ? s.tomorrow : s.inDays(days);
  }
}

/// Bottom-sheet ward picker for the inline delivery form at checkout.
/// Mirrors the one in the address book but lives here so the checkout
/// form doesn't depend on the addresses feature.
class _CheckoutWardPicker extends ConsumerWidget {
  const _CheckoutWardPicker({
    required this.selectedCode,
    required this.onChanged,
  });
  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hcmWardsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Phường (TP.HCM)',
          errorText: 'Không tải được danh sách phường',
        ),
        child: Text('—'),
      ),
      data: (wards) {
        final selected = wards.cast<HcmWard?>().firstWhere(
              (w) => w?.code == selectedCode,
              orElse: () => null,
            );
        return InkWell(
          onTap: () async {
            final picked = await showModalBottomSheet<HcmWard?>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _WardPickerSheet(wards: wards),
            );
            if (picked != null) onChanged(picked.code);
          },
          borderRadius: BananRadii.rmd,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Phường (TP.HCM)',
              helperText:
                  'Sau cải cách 7/2025 — chọn phường để tính phí giao hàng',
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              selected?.name ?? 'Chọn phường…',
              style: selected == null
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}

class _WardPickerSheet extends StatefulWidget {
  const _WardPickerSheet({required this.wards});
  final List<HcmWard> wards;

  @override
  State<_WardPickerSheet> createState() => _WardPickerSheetState();
}

class _WardPickerSheetState extends State<_WardPickerSheet> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = _q.trim().toLowerCase();
    final filtered = lower.isEmpty
        ? widget.wards
        : widget.wards.where((w) {
            return w.name.toLowerCase().contains(lower) ||
                (w.oldArea ?? '').toLowerCase().contains(lower);
          }).toList();
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: BananSpacing.lg),
        child: Column(
          children: [
            Text(
              'Chọn phường (TP.HCM)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên phường hoặc quận cũ',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: BananSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy phường khớp.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final w = filtered[i];
                        return ListTile(
                          title: Text(w.name),
                          subtitle: w.oldArea == null
                              ? null
                              : Text('Quận/khu vực cũ: ${w.oldArea}'),
                          onTap: () => Navigator.pop(context, w),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live delivery-fee preview. Backend auto-routes to the nearest open
/// Banan branch from the chosen ward, applies the admin-tuned tier from
/// `DeliveryConfig` (birthday cake vs. standard), and returns the final
/// fee. The widget displays the routed store + a tier breakdown.
class _DeliveryQuoteBox extends ConsumerWidget {
  const _DeliveryQuoteBox({
    required this.wardCode,
    required this.productIds,
  });
  final String? wardCode;
  final List<String> productIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final quoteFuture = ref.watch(_deliveryQuoteProvider((
      wardCode: wardCode,
      productIdsCsv: productIds.join(','),
    )));

    return quoteFuture.when(
      loading: () => const SizedBox(
        height: 24,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text(
        'Không tính được phí: $e',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      data: (q) {
        final bg = q.noStoreAvailable
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
            : q.isOtherWard
                ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                : theme.colorScheme.surface;
        final tierLabel = q.tier == DeliveryFeeTier.birthdayCake
            ? 'Bánh sinh nhật'
            : 'Sản phẩm thường';
        final bandLabel = q.isOtherWard ? 'phường khác' : 'cùng phường';
        return Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            color: bg,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q.store != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: BananSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giao từ: ${q.store!.name}',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            q.store!.address,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: BananSpacing.md),
              ] else if (q.noStoreAvailable) ...[
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: BananSpacing.sm),
                    Expanded(
                      child: Text(
                        'Hiện không có cửa hàng nào nhận giao hàng tới phường này.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: BananSpacing.md),
              ],
              Row(
                children: [
                  Icon(
                    q.tier == DeliveryFeeTier.birthdayCake
                        ? Icons.cake_outlined
                        : (q.isOtherWard
                            ? Icons.local_shipping_outlined
                            : Icons.check_circle_outline),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  Expanded(
                    child: Text(
                      q.totalVnd == 0
                          ? 'Miễn phí giao hàng'
                          : 'Phí giao hàng dự kiến',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    fmt.format(q.totalVnd),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Phân loại: $tierLabel — $bandLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (q.tier == DeliveryFeeTier.birthdayCake)
                      Text(
                        '• Đơn có bánh sinh nhật — áp dụng biểu phí riêng',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (q.distanceKm != null)
                      Text(
                        '• Khoảng cách từ cửa hàng đến phường: '
                        '${q.distanceKm!.toStringAsFixed(1)} km',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    if (!q.wardKnown)
                      Text(
                        '• Chọn phường ở trên để tính chính xác',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Family-provider key. All fields are primitives so Dart record's
/// structural equality works — earlier versions included a raw
/// `List<String>` which is reference-compared, so every widget rebuild
/// produced a *new* family entry and the quote loop never settled.
typedef _QuoteKey = ({String? wardCode, String productIdsCsv});

/// Cached by (wardCode + cart hash) — re-fetched only when the customer
/// changes the ward or the cart contents.
final _deliveryQuoteProvider = FutureProvider.autoDispose
    .family<DeliveryQuote, _QuoteKey>((ref, key) async {
  final api = ref.watch(geoApiProvider);
  final ids = key.productIdsCsv.isEmpty
      ? const <String>[]
      : key.productIdsCsv.split(',');
  final res = await api.deliveryQuote(
    wardCode: key.wardCode,
    productIds: ids,
  );
  return res.when(
    success: (q) => q,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});
