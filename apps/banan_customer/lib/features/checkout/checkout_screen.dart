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

const _deliveryFee = 30000.0;
const _vndPerPoint = 100;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  FulfillmentType _fulfillment = FulfillmentType.pickup;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController(text: 'Ho Chi Minh City');
  final _notes = TextEditingController();
  final _coupon = TextEditingController();
  CouponPreview? _appliedCoupon;
  String? _couponError;
  bool _validatingCoupon = false;
  int _pointsToRedeem = 0;
  bool _placing = false;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  void _onFulfillmentChanged(FulfillmentType next) {
    setState(() {
      _fulfillment = next;
      if (next == FulfillmentType.delivery &&
          _paymentMethod == PaymentMethod.cash) {
        _paymentMethod = PaymentMethod.stripe;
      }
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

  Future<void> _place() async {
    if (_fulfillment == FulfillmentType.delivery &&
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });

    final cart = ref.read(cartControllerProvider);
    final draft = NewOrder(
      items: cart.items
          .map(
            (i) => NewOrderItem(
              productId: i.productId,
              variantId: i.variantId,
              quantity: i.quantity,
              customMessage: i.customMessage,
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
            )
          : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      couponCode: _appliedCoupon?.code,
      pointsToRedeem: _pointsToRedeem > 0 ? _pointsToRedeem : null,
    );

    final repo = ref.read(orderRepositoryProvider);
    final result = await repo.placeOrder(draft);

    if (!mounted) return;
    setState(() => _placing = false);

    result.when(
      success: (placed) async {
        ref.read(cartControllerProvider.notifier).clear();
        // Refresh membership balance — points + earn-on-completion both
        // change the user state.
        ref.invalidate(membershipSummaryProvider);

        if (placed.payment.configurationError != null) {
          setState(() => _error = placed.payment.configurationError);
          return;
        }

        context.go('/orders/${placed.order.id}');
        if (placed.payment.hasRedirect) {
          unawaited(
            launchUrl(
              Uri.parse(placed.payment.redirectUrl!),
              webOnlyWindowName: '_blank',
            ),
          );
        }
      },
      failure: (f) => setState(() => _error = authFailureMessage(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final membership =
        ref.watch(membershipSummaryProvider).valueOrNull;
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final fee = _fulfillment == FulfillmentType.delivery ? _deliveryFee : 0.0;
    final couponDiscount = _appliedCoupon?.discount ?? 0.0;
    final subtotalAfterCoupon = (cart.subtotal - couponDiscount).clamp(0.0, double.infinity);
    final maxRedeemable = (subtotalAfterCoupon ~/ _vndPerPoint)
        .clamp(0, membership?.balance ?? 0);
    final pointsActuallyUsed = _pointsToRedeem.clamp(0, maxRedeemable);
    final pointsDiscount = pointsActuallyUsed * _vndPerPoint.toDouble();
    final total = (cart.subtotal - couponDiscount - pointsDiscount + fee)
        .clamp(0.0, double.infinity);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const EmptyState(
          title: 'Your cart is empty',
          message: 'Add a cake from the menu before checking out.',
          icon: Icons.shopping_bag_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.lg),
          child: PrimaryButton(
            label: 'Place order · ${fmt.format(total)}',
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
                    Text('Fulfillment', style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    SegmentedButton<FulfillmentType>(
                      segments: const [
                        ButtonSegment(
                          value: FulfillmentType.pickup,
                          label: Text('Pickup'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                        ButtonSegment(
                          value: FulfillmentType.delivery,
                          label: Text('Delivery'),
                          icon: Icon(Icons.delivery_dining_outlined),
                        ),
                      ],
                      selected: {_fulfillment},
                      onSelectionChanged: (set) =>
                          _onFulfillmentChanged(set.first),
                    ),
                    if (_fulfillment == FulfillmentType.delivery) ...[
                      const SizedBox(height: BananSpacing.xl),
                      Text(
                        'Delivery address',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _recipient,
                        decoration:
                            const InputDecoration(labelText: 'Recipient'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _line1,
                        decoration: const InputDecoration(
                          labelText: 'Address line',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: BananSpacing.md),
                      TextFormField(
                        controller: _city,
                        decoration:
                            const InputDecoration(labelText: 'City'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text('Save', style: theme.textTheme.titleLarge),
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
                    if (membership != null && membership.balance > 0) ...[
                      const SizedBox(height: BananSpacing.lg),
                      _PointsRedeemer(
                        balance: membership.balance,
                        max: maxRedeemable,
                        value: pointsActuallyUsed,
                        vndPerPoint: _vndPerPoint,
                        onChanged: (n) => setState(() => _pointsToRedeem = n),
                        fmt: fmt,
                      ),
                    ],
                    const SizedBox(height: BananSpacing.xl),
                    Text('Payment', style: theme.textTheme.titleLarge),
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
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        helperText: 'Birthday name, dietary needs, etc.',
                      ),
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

class _CouponField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        ? 'Free delivery'
                        : '−${fmt.format(applied!.discount)} off',
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
                decoration: const InputDecoration(
                  labelText: 'Coupon code',
                  prefixIcon: Icon(Icons.local_offer_outlined, size: 20),
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
                  : const Text('Apply'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Text(
                'Redeem points  ·  $balance available',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              '−${fmt.format(value * vndPerPoint)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (maxClamped == 0)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.xs),
            child: Text(
              'Order subtotal is too low to redeem points yet.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Slider(
            min: 0,
            max: maxClamped.toDouble(),
            divisions: maxClamped,
            value: value.toDouble().clamp(0, maxClamped.toDouble()),
            label: '$value pts',
            onChanged: (v) => onChanged(v.round()),
          ),
      ],
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({
    required this.fulfillment,
    required this.selected,
    required this.onChanged,
  });

  final FulfillmentType fulfillment;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(PaymentMethod, IconData, String)>[
      if (fulfillment == FulfillmentType.pickup)
        (PaymentMethod.cash, Icons.payments_outlined, 'Pay at the counter'),
      (PaymentMethod.stripe, Icons.credit_card, 'Visa, Mastercard, Apple Pay'),
      (PaymentMethod.vnpay, Icons.account_balance_outlined,
          'Vietnamese bank cards'),
      (PaymentMethod.momo, Icons.qr_code_2_outlined, 'MoMo wallet'),
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

class _Summary extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Summary', style: theme.textTheme.titleLarge),
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
          _Line(label: 'Subtotal', value: fmt.format(cart.subtotal)),
          if (couponDiscount > 0)
            _Line(
              label: 'Coupon',
              value: '−${fmt.format(couponDiscount)}',
              accent: true,
            ),
          if (pointsDiscount > 0)
            _Line(
              label: 'Points',
              value: '−${fmt.format(pointsDiscount)}',
              accent: true,
            ),
          _Line(label: 'Delivery fee', value: fmt.format(fee)),
          const SizedBox(height: BananSpacing.sm),
          _Line(label: 'Total', value: fmt.format(total), bold: true),
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
