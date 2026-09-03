import 'dart:async';

import 'package:banan_core/banan_core.dart';
import 'package:banan_customer/features/cart/cart_controller.dart';
import 'package:banan_customer/features/checkout/checkout_screen.dart';
import 'package:banan_customer/features/checkout/fulfillment_preference.dart';
import 'package:banan_customer/features/locations/locations_screen.dart'
    show storesListProvider;
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vietnamese string table — the copy asserted below is the VI default.
const AppStrings s = viStrings;

// ── Fixtures ────────────────────────────────────────────────────────────

const _wards = <HcmWard>[
  HcmWard(
    code: 'sai-gon',
    name: 'Phường Sài Gòn',
    lat: 10.777,
    lng: 106.7019,
    oldArea: 'Bến Nghé, Đa Kao, Nguyễn Thái Bình · Q1',
  ),
  HcmWard(
    code: 'cau-ong-lanh',
    name: 'Phường Cầu Ông Lãnh',
    lat: 10.7679,
    lng: 106.6925,
    oldArea: 'Nguyễn Cư Trinh, Cầu Kho, Cô Giang · Q1',
    legacyCodes: ['cau-kho'],
  ),
  HcmWard(
    code: 'an-phu-dong',
    name: 'Phường An Phú Đông',
    lat: 10.861,
    lng: 106.6918,
    oldArea: 'Thạnh Lộc, An Phú Đông · Quận 12',
  ),
  HcmWard(
    code: 'trung-my-tay',
    name: 'Phường Trung Mỹ Tây',
    oldArea: 'Tân Chánh Hiệp, Trung Mỹ Tây · Quận 12',
    serviceable: false,
  ),
];

const _store = Store(
  id: 'store-1',
  name: 'Banan Sài Gòn',
  slug: 'banan-sai-gon',
  address: '1 Nguyễn Huệ',
  phone: '0900000000',
  openingHours: {},
  wardCode: 'sai-gon',
);

const _cartItem = CartItem(
  productId: 'p1',
  variantId: 'v1',
  productName: 'Bánh kem test',
  variantLabel: 'Nhỏ',
  unitPrice: 100000,
  quantity: 1,
);

class _FakeGeoApi implements GeoApi {
  _FakeGeoApi({this.quoteFails = false});

  /// When true every quote round-trip fails — simulates a network/API error
  /// so the checkout must treat the fee as unknown and block submit.
  final bool quoteFails;

  @override
  Future<Result<List<HcmWard>, AppFailure>> hcmWards() async =>
      const Result.success(_wards);

  @override
  Future<Result<DeliveryQuote, AppFailure>> deliveryQuote({
    String? wardCode,
    List<String> productIds = const [],
  }) async {
    if (quoteFails) {
      return const Result.failure(UnknownFailure(message: 'quote-down'));
    }
    final ward = _wards.cast<HcmWard?>().firstWhere(
          (w) => w?.matchesCode(wardCode) ?? false,
          orElse: () => null,
        );
    return Result.success(
      DeliveryQuote(
        totalVnd: 30000,
        wardKnown: wardCode != null,
        tier: DeliveryFeeTier.standard,
        wardMatch: DeliveryWardMatch.other,
        hasBirthdayCake: false,
        serviceable: ward == null || ward.serviceable,
        store: const RoutedStore(
          id: 'store-1',
          name: 'Banan Sài Gòn',
          address: '1 Nguyễn Huệ',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.delay = Duration.zero});

  final Duration delay;
  int placeOrderCalls = 0;

  @override
  Future<Result<PlaceOrderResult, AppFailure>> placeOrder(
    NewOrder draft,
  ) async {
    placeOrderCalls += 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    // A failure keeps the flow inside the screen (no router needed) while
    // still counting as a completed place-order round-trip.
    return const Result.failure(ValidationFailure(message: 'test-rejected'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) async =>
      const Result<List<Product>, AppFailure>.success(<Product>[]);
}

// ── Harness ─────────────────────────────────────────────────────────────

({ProviderContainer container, _FakeOrderRepository orders}) _buildContainer({
  Duration placeDelay = Duration.zero,
  List<Store>? stores,
  bool quoteFails = false,
}) {
  final orders = _FakeOrderRepository(delay: placeDelay);
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      hcmWardsProvider.overrideWith((ref) async => _wards),
      storesListProvider.overrideWith((ref) async => stores ?? [_store]),
      geoApiProvider.overrideWithValue(_FakeGeoApi(quoteFails: quoteFails)),
      orderRepositoryProvider.overrideWithValue(orders),
      catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
    ],
  );
  return (container: container, orders: orders);
}

Future<void> _pumpCheckout(
  WidgetTester tester,
  ProviderContainer container, {
  FulfillmentType fulfillment = FulfillmentType.pickup,
}) async {
  container.read(cartControllerProvider.notifier).add(_cartItem);
  container.read(fulfillmentPreferenceProvider.notifier).state = fulfillment;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckoutScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPlaceOrder(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

/// Scrolls [target] into the hit-testable area of the main list, then taps.
Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _formField(int index) => find.byType(TextFormField).at(index);

bool _visibleInViewport(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder.first);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return rect.top < size.height && rect.bottom > 0;
}

void main() {
  group('checkout submit validation', () {
    testWidgets('guest with empty name/phone: no API call, focus on contact',
        (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(tester, h.container);

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      // Inline errors painted + the shared "check the marked fields" banner.
      expect(find.text(s.checkMarkedFields), findsWidgets);
      expect(find.text(s.required), findsWidgets);
      // The first invalid field (guest name) got the caret.
      final firstEditable =
          tester.widget<EditableText>(find.byType(EditableText).first);
      expect(firstEditable.focusNode.hasFocus, isTrue);
    });

    testWidgets('delivery with empty address: scrolls to the address section',
        (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(
        tester,
        h.container,
        fulfillment: FulfillmentType.delivery,
      );

      // Guest contact OK so the first failure is the address block.
      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      // Recipient field (index 3: name, phone, email, recipient) is now
      // inside the viewport after the auto-scroll and shows its error.
      expect(_visibleInViewport(tester, _formField(3)), isTrue);
      expect(find.text(s.required), findsWidgets);
    });

    testWidgets('delivery without ward: ward picker shows its own error',
        (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(
        tester,
        h.container,
        fulfillment: FulfillmentType.delivery,
      );

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');
      await tester.enterText(_formField(3), 'Người nhận');
      await tester.enterText(_formField(4), '0907654321');
      await tester.enterText(_formField(5), '12 Lê Lợi');

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      expect(find.text(s.wardRequired), findsOneWidget);
      expect(
        _visibleInViewport(tester, find.text(s.wardRequired)),
        isTrue,
      );
    });

    testWidgets(
        'delivery to Q12: picker finds it via "Q12", hides the ward outside '
        'the zone, and the order goes through', (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(
        tester,
        h.container,
        fulfillment: FulfillmentType.delivery,
      );

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');
      await tester.enterText(_formField(3), 'Người nhận');
      await tester.enterText(_formField(4), '0907654321');
      await tester.enterText(_formField(5), '12 TL08');

      // Open the shared ward picker sheet and search with the old-district
      // shorthand. Serviceable An Phú Đông matches; Trung Mỹ Tây is still
      // outside the delivery zone so the picker hides it entirely.
      await _scrollToAndTap(tester, find.text(s.chooseWard));
      await tester.enterText(find.byType(TextField).last, 'Q12');
      await tester.pumpAndSettle();
      expect(find.text('Phường An Phú Đông'), findsOneWidget);
      expect(find.text('Phường Trung Mỹ Tây'), findsNothing);
      await tester.tap(find.text('Phường An Phú Đông'));
      await tester.pumpAndSettle();

      await _tapPlaceOrder(tester);

      // Fully valid delivery order — the round-trip reaches the repository.
      expect(h.orders.placeOrderCalls, 1);
      expect(find.text('test-rejected'), findsWidgets);
    });

    testWidgets('pickup with no branch available: blocked with picker error',
        (tester) async {
      final h = _buildContainer(stores: const []);
      addTearDown(h.container.dispose);
      await _pumpCheckout(tester, h.container);

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      expect(find.text(s.pickupStoreRequired), findsOneWidget);
      expect(
        _visibleInViewport(tester, find.text(s.pickupStoreRequired)),
        isTrue,
      );
    });

    testWidgets('VAT on with empty company fields: scrolls to the VAT block',
        (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(tester, h.container);

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');

      await _scrollToAndTap(tester, find.text(s.vatTitle));

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      // The company-name field shows a required error and is in view.
      expect(find.text(s.required), findsWidgets);
      expect(
        _visibleInViewport(tester, find.text(s.companyName)),
        isTrue,
      );
    });

    testWidgets('valid pickup order: placeOrder called exactly once',
        (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      await _pumpCheckout(tester, h.container);

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 1);
      // The fake rejects the order — its message lands in the banner, so
      // the request round-trip clearly completed.
      expect(find.text('test-rejected'), findsWidgets);
    });

    testWidgets(
        'saved address carrying a split pre-reform ward code: picker demands '
        'a fresh pick and submit is blocked', (tester) async {
      final h = _buildContainer();
      addTearDown(h.container.dispose);
      // `an-phu` (old Thủ Đức ward, split between An Khánh and Bình Trưng)
      // is not in the catalog and not a legacyCode of any ward — exactly
      // what an old address row carries.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            home: Scaffold(
              body: WardPickerField(
                selectedCode: 'an-phu',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.wardReselectRequired), findsOneWidget);
      // The legacy SAFE alias still resolves to its new ward.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            home: Scaffold(
              body: WardPickerField(
                selectedCode: 'cau-kho',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phường Cầu Ông Lãnh'), findsOneWidget);
      expect(find.text(s.wardReselectRequired), findsNothing);
    });

    testWidgets('delivery quote fails: submit blocked with quote error',
        (tester) async {
      final h = _buildContainer(quoteFails: true);
      addTearDown(h.container.dispose);
      await _pumpCheckout(
        tester,
        h.container,
        fulfillment: FulfillmentType.delivery,
      );

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');
      await tester.enterText(_formField(3), 'Người nhận');
      await tester.enterText(_formField(4), '0907654321');
      await tester.enterText(_formField(5), '12 Lê Lợi');

      // Pick a normally-serviceable ward; only the quote round-trip fails.
      await _scrollToAndTap(tester, find.text(s.chooseWard));
      await tester.enterText(find.byType(TextField).last, 'Sài Gòn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phường Sài Gòn').last);
      await tester.pumpAndSettle();

      await _tapPlaceOrder(tester);

      expect(h.orders.placeOrderCalls, 0);
      expect(find.text(s.quoteFailed), findsOneWidget);
    });

    testWidgets('spamming Đặt hàng while placing: only one request',
        (tester) async {
      final h = _buildContainer(placeDelay: const Duration(milliseconds: 300));
      addTearDown(h.container.dispose);
      await _pumpCheckout(tester, h.container);

      await tester.enterText(_formField(0), 'Nguyễn Văn A');
      await tester.enterText(_formField(1), '0901234567');

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump(const Duration(milliseconds: 50));
      // Two more taps while the first request is in flight.
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.orders.placeOrderCalls, 1);
    });
  });
}
