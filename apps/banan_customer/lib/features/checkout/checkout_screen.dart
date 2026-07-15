import 'dart:async';

import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../addresses/addresses_screen.dart' show myAddressesProvider;
import '../cart/cart_controller.dart';
import 'checkout_cross_sell.dart';
import 'fulfillment_preference.dart';
import 'fulfillment_widgets.dart';
import 'order_draft.dart';

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
  // Online-only: COD (cash) is disabled, 9Pay is the sole method.
  PaymentMethod _paymentMethod = PaymentMethod.ninepay;
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
  /// Carried through from a picked saved address (no visible fields in the
  /// inline form). Re-sent on the order so the address book stays faithful.
  String? _line2;
  String? _district;
  /// Id of the saved address the customer tapped, so the picker can show
  /// which one is currently applied. Null = manual entry.
  String? _selectedAddressId;

  final _notes = TextEditingController();
  final _coupon = TextEditingController();

  // VAT invoice (hóa đơn đỏ) — opt-in for company purchases.
  bool _requestVatInvoice = false;
  final _invoiceCompany = TextEditingController();
  final _invoiceTaxId = TextEditingController();
  final _invoiceAddress = TextEditingController();
  final _invoiceEmail = TextEditingController();

  // Gift order (tặng quà) — opt-in. When ON, the greeting message + recipient
  // + wrap/hide-price flags are sent with the order.
  bool _isGift = false;
  final _giftMessage = TextEditingController();
  final _giftRecipientName = TextEditingController();
  final _giftRecipientPhone = TextEditingController();
  bool _giftWrap = false;
  bool _hidePrice = false;
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

  /// Structured per-item timeline rejection from the backend — when set, the
  /// checkout shows which exact cakes don't fit the chosen time plus one-tap
  /// fixes, instead of the plain [_error] banner.
  OrderTimelineFailure? _timeline;

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
    // Pre-fill from the cart's order draft so the customer doesn't re-pick
    // fulfillment / branch / schedule they already chose on the cart screen.
    // The draft's own defaults fall back to the session-wide pickup/delivery
    // preference, so an empty draft behaves exactly like before.
    final draft = ref.read(orderDraftProvider);
    _fulfillment = draft.fulfillment;
    _pickupStoreId = draft.pickupStoreId;
    _scheduledFor = draft.scheduledFor;
    // Resolve the picked saved-address id (delivery only) against the address
    // book once it loads and apply it to the inline form. Done post-frame so
    // we can use ref.read on the (possibly async) provider after first build.
    final draftAddressId = draft.deliveryAddressId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Dismiss any "Đã thêm X vào giỏ" snackbar still showing from the
      // menu screen — once they're on checkout, "Xem giỏ" is redundant
      // and the message overlaps the bottom "Đặt hàng" button.
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (draftAddressId == null ||
          _fulfillment != FulfillmentType.delivery) {
        return;
      }
      final addresses = ref.read(myAddressesProvider).valueOrNull;
      final match = addresses?.cast<Address?>().firstWhere(
            (a) => a?.id == draftAddressId,
            orElse: () => null,
          );
      if (match != null) _applySavedAddress(match);
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
    _giftMessage.dispose();
    _giftRecipientName.dispose();
    _giftRecipientPhone.dispose();
    super.dispose();
  }

  /// Fill the inline delivery form from a saved address. City is locked to
  /// HCMC, so we keep the controller as-is. The ward picker selection
  /// (`_wardCode`) and the hidden line2/district are carried through too.
  void _applySavedAddress(Address a) {
    setState(() {
      _selectedAddressId = a.id;
      _recipient.text = a.recipient;
      _phone.text = a.phone;
      _line1.text = a.line1;
      _line2 = a.line2;
      _district = a.district;
      _wardCode = a.wardCode;
    });
  }

  /// Once the customer hand-edits a field, the form no longer mirrors the
  /// picked saved address — drop the highlight (and the carried line2/
  /// district so we don't ship stale extras with a now-manual address).
  void _clearSavedSelection() {
    if (_selectedAddressId == null) return;
    setState(() {
      _selectedAddressId = null;
      _line2 = null;
      _district = null;
    });
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
              // Combo lines carry a synthetic `bundle:<id>` variantId for the
              // cart key only — it isn't a real variant UUID. Send null so the
              // backend's UUID validation passes and it expands the bundle.
              variantId: i.isBundle ? null : i.variantId,
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
              line2: _line2,
              city: _city.text.trim(),
              district: _district,
              wardCode: _wardCode,
            )
          : null,
      // Lock in the routed branch from the live quote so the order ends
      // up at the same branch the customer saw on the checkout breakdown.
      deliveryStoreId: _fulfillment == FulfillmentType.delivery
          ? ref
              .read(_deliveryQuoteProvider((
                wardCode: _wardCode,
                productIdsCsv: cart.orderedProductIds.join(','),
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
      // Gift fields — only sent when the gift toggle is on; off → nothing.
      isGift: _isGift,
      giftMessage: _isGift && _giftMessage.text.trim().isNotEmpty
          ? _giftMessage.text.trim()
          : null,
      giftRecipientName: _isGift && _giftRecipientName.text.trim().isNotEmpty
          ? _giftRecipientName.text.trim()
          : null,
      giftRecipientPhone: _isGift && _giftRecipientPhone.text.trim().isNotEmpty
          ? _giftRecipientPhone.text.trim()
          : null,
      giftWrap: _isGift && _giftWrap,
      hidePrice: _isGift && _hidePrice,
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

        // Redirect-based payment (9Pay / MoMo / Stripe): navigate the SAME
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
      failure: (f) => setState(() {
        if (f is OrderTimelineFailure) {
          // Per-item rejection — show the structured panel, not the banner.
          _timeline = f;
          _error = null;
        } else {
          _timeline = null;
          _error = authFailureMessage(f);
        }
      }),
    );
  }

  /// Builds the combined "needs prep time" + "sold only on certain days" note
  /// shown above the schedule picker, or null when the cart has no constraint.
  String? _scheduleNote(CartState cart) {
    final notes = [
      prepLeadNote(leadHours: cart.maxLeadHours, names: cart.leadProductNames),
      // Conflicting day constraints (no single day works for the whole cart):
      // warn up front instead of letting the picker show every day and only
      // failing at checkout. Otherwise show the normal allowed-days note.
      if (cart.hasDayConflict)
        'Các món trong giỏ không bán cùng một ngày — vui lòng bỏ bớt món để '
            'đặt được, hoặc tách thành nhiều đơn.'
      else
        dayConstraintNote(
          allowedDays: cart.allowedDaysOfWeek,
          names: cart.dayConstrainedNames,
        ),
    ].whereType<String>().toList();
    return notes.isEmpty ? null : notes.join('\n\n');
  }

  /// "Chọn giờ sớm nhất phù hợp" — snap the schedule to the soonest moment that
  /// satisfies every cake's lead time AND allowed days, then clear the error.
  void _applyEarliestFeasible(CartState cart, OrderTimelineFailure f) {
    final lead = f.earliestLeadHours ?? cart.maxLeadHours;
    final allowed = cart.allowedDaysOfWeek;
    final set = (allowed.isEmpty || allowed.length >= 7) ? null : allowed.toSet();
    setState(() {
      _scheduledFor = earliestScheduleSlot(
        Duration(hours: lead),
        allowedDays: set,
      );
      _timeline = null;
      _error = null;
    });
  }

  /// "Xoá các món này" — drop every offending cake from the cart so the rest
  /// of the order can go through.
  void _removeOffending(OrderTimelineFailure f) {
    final ids = f.items.map((i) => i.productId).toSet();
    ref.read(cartControllerProvider.notifier).removeProducts(ids);
    setState(() {
      _timeline = null;
      _error = null;
    });
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
    // Expand combos into their real products so the quoted delivery fee uses
    // the same product set the backend charges against (e.g. birthday tier).
    final productIdsCsv = cart.orderedProductIds.join(',');
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
            Builder(
              builder: (context) {
                // Wide screens (desktop) get a 2-column layout: the form on the
                // left, the order summary as a right rail — so the total stays
                // in view without scrolling to the bottom. Narrow stays single.
                final wide = MediaQuery.sizeOf(context).width >= 960;
                final form = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_timeline != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: BananSpacing.lg),
                        child: _TimelineErrorPanel(
                          failure: _timeline!,
                          onPickEarliest: () =>
                              _applyEarliestFeasible(cart, _timeline!),
                          onRemove: () => _removeOffending(_timeline!),
                        ),
                      )
                    else if (_error != null)
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
                      PickupStorePicker(
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
                    LeadAwareSchedule(
                      value: _scheduledFor,
                      onChanged: (next) =>
                          setState(() => _scheduledFor = next),
                      leadHours: cart.maxLeadHours,
                      leadNote: _scheduleNote(cart),
                      allowedDays: cart.allowedDaysOfWeek,
                    ),
                    if (_fulfillment == FulfillmentType.delivery) ...[
                      const SizedBox(height: BananSpacing.xl),
                      Text(
                        s.deliveryAddress,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      // Logged-in customers can pull from their address book
                      // instead of retyping. Guests don't have one, so the
                      // picker is hidden for them and the manual path is used.
                      if (!isGuest) ...[
                        SavedAddressPicker(
                          selectedId: _selectedAddressId,
                          onSelect: _applySavedAddress,
                        ),
                        const SizedBox(height: BananSpacing.md),
                      ],
                      TextFormField(
                        controller: _recipient,
                        decoration:
                            InputDecoration(labelText: s.recipient),
                        onChanged: (_) => _clearSavedSelection(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? s.required : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: s.phone),
                        onChanged: (_) => _clearSavedSelection(),
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
                        onChanged: (_) => _clearSavedSelection(),
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
                        productIds: cart.orderedProductIds,
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
                  ],
                );
                // Optional order extras (VAT invoice, gift wrap) — rarely used,
                // so they live at the bottom of the right rail instead of
                // stretching the main form.
                final extras = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VatInvoiceSection(
                      enabled: _requestVatInvoice,
                      onToggle: (v) =>
                          setState(() => _requestVatInvoice = v),
                      company: _invoiceCompany,
                      taxId: _invoiceTaxId,
                      address: _invoiceAddress,
                      email: _invoiceEmail,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    _GiftSection(
                      enabled: _isGift,
                      onToggle: (v) => setState(() => _isGift = v),
                      message: _giftMessage,
                      recipientName: _giftRecipientName,
                      recipientPhone: _giftRecipientPhone,
                      giftWrap: _giftWrap,
                      onGiftWrap: (v) => setState(() => _giftWrap = v),
                      hidePrice: _hidePrice,
                      onHidePrice: (v) => setState(() => _hidePrice = v),
                    ),
                  ],
                );
                // Savings (coupon / gift card / points) move to the right rail
                // next to the total they affect, so the left form stays short.
                final savings = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _giftCtrl,
                            textCapitalization: TextCapitalization.characters,
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
                    if (membership != null && membership.balance > 0) ...[
                      const SizedBox(height: BananSpacing.lg),
                      _PointsRedeemer(
                        balance: membership.balance,
                        max: maxRedeemable,
                        value: pointsActuallyUsed,
                        vndPerPoint: _vndPerPoint,
                        onChanged: (v) => setState(() => _pointsToRedeem = v),
                        fmt: fmt,
                      ),
                    ],
                  ],
                );
                final summary = _Summary(
                  cart: cart,
                  fee: fee,
                  couponDiscount: couponDiscount,
                  pointsDiscount: pointsDiscount,
                  total: total,
                  fmt: fmt,
                );
                final crossSell = cart.items.isEmpty
                    ? const SizedBox.shrink()
                    : CheckoutCrossSell(
                        seedProductId: cart.items.first.productId,
                        fmt: fmt,
                      );
                final rail = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    savings,
                    const SizedBox(height: BananSpacing.xl),
                    summary,
                    const SizedBox(height: BananSpacing.xl),
                    crossSell,
                    const SizedBox(height: BananSpacing.xl),
                    extras,
                  ],
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1120 : 720),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: form),
                              const SizedBox(width: BananSpacing.xl),
                              Expanded(flex: 2, child: rail),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              form,
                              const SizedBox(height: BananSpacing.xl),
                              rail,
                            ],
                          ),
                  ),
                );
              },
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

/// "🎁 Gửi tặng / Đây là quà tặng" block. Hidden by default; turning the
/// switch on reveals the greeting message, recipient name + phone, and the
/// "Gói quà" / "Ẩn giá trên phiếu giao" checkboxes. Mirrors the VAT section
/// styling so the two opt-in cards look consistent.
class _GiftSection extends StatelessWidget {
  const _GiftSection({
    required this.enabled,
    required this.onToggle,
    required this.message,
    required this.recipientName,
    required this.recipientPhone,
    required this.giftWrap,
    required this.onGiftWrap,
    required this.hidePrice,
    required this.onHidePrice,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController message;
  final TextEditingController recipientName;
  final TextEditingController recipientPhone;
  final bool giftWrap;
  final ValueChanged<bool> onGiftWrap;
  final bool hidePrice;
  final ValueChanged<bool> onHidePrice;

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
            title: const Text('🎁 Gửi tặng / Đây là quà tặng'),
            subtitle: Text(
              enabled
                  ? 'Kèm thiệp chúc, người nhận và tuỳ chọn gói quà.'
                  : 'Bật khi bạn muốn gửi đơn này làm quà tặng.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: BananSpacing.xs),
            TextField(
              controller: message,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Lời chúc',
                hintText: 'Lời chúc gửi kèm thiệp…',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: recipientName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tên người nhận',
                helperText: 'Người sẽ nhận món quà này (không bắt buộc).',
              ),
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: recipientPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'SĐT người nhận',
                helperText: 'Để shipper liên hệ người nhận (không bắt buộc).',
              ),
            ),
            const SizedBox(height: BananSpacing.xs),
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: giftWrap,
              onChanged: (v) => onGiftWrap(v ?? false),
              title: const Text('Gói quà / hộp quà'),
            ),
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: hidePrice,
              onChanged: (v) => onHidePrice(v ?? false),
              title: const Text('Ẩn giá trên phiếu giao'),
              subtitle: Text(
                'Người nhận sẽ không thấy giá tiền.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
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
    // Online pay goes through 9Pay (QR / card / bank). It only completes once
    // NINEPAY_MERCHANT_KEY / NINEPAY_SECRET_KEY / NINEPAY_CHECKSUM_KEY are set
    // in backend/.env(.prod) and the IPN URL is registered in the 9Pay
    // dashboard; until then the backend rejects it up-front (before any order is
    // created) with a clear "phương thức chưa khả dụng" message, so cash stays
    // the safe default.
    // COD disabled — 9Pay only. (Re-add the cash tuple here to bring it back.)
    final options = <(PaymentMethod, IconData, String)>[
      (PaymentMethod.ninepay, Icons.qr_code_2_outlined, 'Quét QR / Thẻ / Chuyển khoản (9Pay)'),
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
          // Inline quantity editing so the cart is merged into checkout —
          // there is no separate cart step. `−` at quantity 1 removes the line
          // (setQuantity(0) deletes it).
          for (final item in cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: BananSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Giảm',
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => ref
                        .read(cartControllerProvider.notifier)
                        .setQuantity(item.key, item.quantity - 1),
                  ),
                  Text('${item.quantity}', style: theme.textTheme.titleMedium),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tăng',
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => ref
                        .read(cartControllerProvider.notifier)
                        .setQuantity(item.key, item.quantity + 1),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  SizedBox(
                    width: 88,
                    child: Text(
                      fmt.format(item.lineTotal),
                      textAlign: TextAlign.end,
                    ),
                  ),
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

/// Red panel that names every cake which doesn't fit the chosen fulfilment
/// time, with one-tap fixes. Shown in place of the generic error banner when
/// the backend returns a structured `ORDER_ITEMS_TIMELINE` rejection.
class _TimelineErrorPanel extends StatelessWidget {
  const _TimelineErrorPanel({
    required this.failure,
    required this.onPickEarliest,
    required this.onRemove,
  });

  final OrderTimelineFailure failure;
  final VoidCallback onPickEarliest;
  final VoidCallback onRemove;

  static const _wd = {
    0: 'CN',
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
  };

  String _reasonText(TimelineViolation v) {
    switch (v.reason) {
      case TimelineReason.leadTime:
        return 'cần đặt trước ${v.leadTimeHours ?? 0} giờ';
      case TimelineReason.dayUnavailable:
        final days = (v.availableDaysOfWeek.toList()..sort())
            .map((d) => _wd[d] ?? '?$d')
            .join(', ');
        return 'chỉ bán $days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        border:
            Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_outlined, color: theme.colorScheme.error),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  'Một số món không kịp thời gian bạn chọn',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          for (final v in failure.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: '•  '),
                    TextSpan(
                      text: v.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' — ${_reasonText(v)}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: BananSpacing.md),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onPickEarliest,
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Chọn giờ sớm nhất phù hợp'),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                label: const Text('Xoá các món này'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
