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

/// English / Japanese checkout must not leak Vietnamese UI copy. Ward names
/// are proper nouns and stay Vietnamese.
final _vietnamese = RegExp(
  '[ăâđêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]',
  caseSensitive: false,
);

const _ward = HcmWard(
  code: 'sai-gon',
  name: 'Phường Sài Gòn',
  lat: 10.777,
  lng: 106.7019,
  oldArea: 'Ben Nghe · Q1',
);

const _store = Store(
  id: 'store-1',
  name: 'Banan Test',
  slug: 'banan-test',
  address: '1 Test Street',
  phone: '0900000000',
  openingHours: {},
  wardCode: 'sai-gon',
);

class _FakeGeoApi implements GeoApi {
  @override
  Future<Result<List<HcmWard>, AppFailure>> hcmWards() async =>
      const Result.success([_ward]);

  @override
  Future<Result<DeliveryQuote, AppFailure>> deliveryQuote({
    String? wardCode,
    List<String> productIds = const [],
  }) async =>
      Result.success(
        DeliveryQuote(
          totalVnd: 30000,
          wardKnown: wardCode != null,
          tier: DeliveryFeeTier.standard,
          wardMatch: DeliveryWardMatch.other,
          hasBirthdayCake: false,
          store: const RoutedStore(
            id: 'store-1',
            name: 'Banan Test',
            address: '1 Test Street',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) async =>
      const Result<List<Product>, AppFailure>.success(<Product>[]);
}

List<String> _vietnameseOnScreen(WidgetTester tester) => [
      for (final w in tester.allWidgets)
        if (w is RichText)
          w.text.toPlainText()
        else if (w is EditableText)
          w.controller.text,
    ]
        .where((t) => _vietnamese.hasMatch(t) && !t.contains('Phường'))
        .toSet()
        .toList();

Future<void> _pump(
  WidgetTester tester,
  AppLocale locale,
  FulfillmentType fulfillment,
) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      localeProvider.overrideWith((ref) => locale),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      hcmWardsProvider.overrideWith((ref) async => [_ward]),
      storesListProvider.overrideWith((ref) async => [_store]),
      geoApiProvider.overrideWithValue(_FakeGeoApi()),
      catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
    ],
  );
  addTearDown(container.dispose);
  container.read(cartControllerProvider.notifier).add(
        const CartItem(
          productId: 'p1',
          variantId: 'v1',
          productName: 'Test Cake',
          variantLabel: '16cm',
          unitPrice: 100000,
          quantity: 1,
        ),
      );
  container.read(fulfillmentPreferenceProvider.notifier).state = fulfillment;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckoutScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in [AppLocale.en, AppLocale.ja]) {
    for (final f in FulfillmentType.values) {
      testWidgets('checkout in ${locale.name} (${f.name}) has no Vietnamese',
          (tester) async {
        await _pump(tester, locale, f);
        expect(_vietnameseOnScreen(tester), isEmpty);
        // Submitting the empty form surfaces every validation message too.
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        expect(_vietnameseOnScreen(tester), isEmpty);
      });
    }
  }

  testWidgets('the scan does catch Vietnamese (control: vi checkout)',
      (tester) async {
    await _pump(tester, AppLocale.vi, FulfillmentType.delivery);
    expect(_vietnameseOnScreen(tester), isNotEmpty);
  });

  test('catalog copy follows the language, unknown text stays as stored', () {
    final c = ProviderContainer(
      overrides: [
        catalogTranslationsProvider.overrideWithValue({
          'Đá': {'en': 'Ice', 'ja': '氷'},
          'Không đá': {'en': 'No ice', 'ja': '氷なし'},
        }),
        localeProvider.overrideWith((ref) => AppLocale.ja),
      ],
    );
    addTearDown(c.dispose);
    final tr = c.read(catalogTextProvider);
    expect(tr('Đá: Không đá'), '氷: 氷なし');
    expect(tr('Mô tả mới'), 'Mô tả mới');
    c.read(localeProvider.notifier).state = AppLocale.vi;
    expect(c.read(catalogTextProvider)('Đá'), 'Đá');
  });
}
