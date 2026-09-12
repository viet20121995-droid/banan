// Local-only demo: real counter form and receipt widgets, in-memory API.
// Run with: flutter run -d chrome -t tool/receipt_demo.dart
import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_data/src/dtos/order_dto.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:banan_merchant/features/orders_mgmt/channel_order_screens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

const demoProduct = Product(
  id: 'demo-cake',
  storeId: 'demo-store',
  categoryId: 'cakes',
  name: 'Signature Strawberry Cake',
  slug: 'demo-cake',
  description: 'Bánh kem dâu tây',
  basePrice: 929000,
  images: [],
  variants: [
    ProductVariant(
      id: 'demo-18',
      size: '18 cm',
      flavor: 'Classic',
      priceDelta: 0,
    ),
  ],
);

Map<String, dynamic> demoOrderJson({
  String status = 'CAPTURED',
  int count = 1,
  bool discounts = false,
}) =>
    {
      'id': 'demo-order',
      'code': 'BAN-DEMO-001',
      'customerId': 'demo-customer',
      'storeId': 'demo-store',
      'store': {
        'name': 'Banan · Ngô Quang Huy',
        'address': '12 Ngô Quang Huy, P. Thảo Điền, TP. Thủ Đức',
        'phone': '0867 540 939',
      },
      'source': 'COUNTER',
      'settlementMode': 'PAID_AT_COUNTER',
      'fulfillmentType': 'PICKUP',
      'status': 'SENT_TO_KITCHEN',
      'subtotal': 929000 * count,
      'deliveryFee': discounts ? 30000 : 0,
      'total': 929000 * count - (discounts ? 50000 : 0),
      'couponDiscount': discounts ? 80000 : 0,
      'createdAt': '2026-09-12T13:15:00Z',
      'updatedAt': '2026-09-12T13:15:00Z',
      'scheduledFor': '2026-09-13T06:15:00Z',
      'items': [
        for (var i = 0; i < count; i++)
          {
            'id': 'line-$i',
            'productId': 'demo-cake',
            'productName': demoProduct.name,
            'quantity': 1,
            'unitPrice': 929000,
            'lineTotal': 929000,
            'variantLabel': '18 cm · Classic',
            'customMessage': 'Happy Birthday, Banan!',
          },
      ],
      'payments': [
        {
          'id': 'demo-payment',
          'provider': status == 'INITIATED' ? 'NINEPAY' : 'CASH',
          'status': status,
          'amount': 929000 * count - (discounts ? 50000 : 0),
          'createdAt': '2026-09-12T13:15:00Z',
        }
      ],
      'statusEvents': <Map<String, dynamic>>[],
      'refunds': <Map<String, dynamic>>[],
    };

class DemoCatalog implements CatalogRepository {
  @override
  Future<Result<ProductPage, AppFailure>> merchantProducts({
    String? q,
    int page = 1,
    int perPage = 50,
  }) async =>
      const Result.success(
        ProductPage(items: [demoProduct], page: 1, perPage: 50, total: 1),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReceiptDemo extends StatefulWidget {
  const ReceiptDemo({super.key});
  @override
  State<ReceiptDemo> createState() => _ReceiptDemoState();
}

class _ReceiptDemoState extends State<ReceiptDemo> {
  final _dio = Dio();
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/merchant/orders/counter') {
            final body = options.data as Map<String, dynamic>;
            final data = demoOrderJson(
              status: body['payment'] == 'PAID_AT_COUNTER'
                  ? 'CAPTURED'
                  : 'AUTHORIZED',
            );
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'data': data},
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{},
              ),
            );
          }
        },
      ),
    );
    _router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const CounterOrderScreen()),
        GoRoute(
          path: '/orders/:id',
          builder: (_, __) => Scaffold(
            appBar:
                AppBar(title: const Text('Đơn ví dụ · Không ghi dữ liệu thật')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: OrderReceipt(
                order: OrderDto.fromJson(demoOrderJson()).toDomain(),
              ),
            ),
          ),
        ),
        // Static paper (no print animation) — for headless screenshots.
        GoRoute(
          path: '/paper/:state',
          builder: (_, state) {
            final value = state.pathParameters['state'];
            return Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ReceiptPaper(
                    order: OrderDto.fromJson(
                      demoOrderJson(
                        status: value == 'pending' ? 'INITIATED' : 'CAPTURED',
                        count: value == 'long' ? 24 : 1,
                        discounts: value == 'discounts',
                      ),
                    ).toDomain(),
                  ),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/preview/:state',
          builder: (_, state) {
            final value = state.pathParameters['state'];
            return Scaffold(
              appBar: AppBar(title: const Text('Banan · Hóa đơn ví dụ')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: OrderReceipt(
                  order: OrderDto.fromJson(
                    demoOrderJson(
                      status: value == 'pending'
                          ? 'INITIATED'
                          : value == 'refund'
                              ? 'REFUNDED'
                              : 'CAPTURED',
                      count: value == 'long' ? 24 : 1,
                      discounts: value == 'discounts',
                    ),
                  ).toDomain(),
                  reload: () async =>
                      OrderDto.fromJson(demoOrderJson()).toDomain(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(_dio),
          catalogRepositoryProvider.overrideWithValue(DemoCatalog()),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthSession(
                accessToken: 'demo',
                refreshToken: 'demo',
                user: User(
                  id: 'demo-user',
                  email: 'demo@banan.local',
                  fullName: 'Banan Demo',
                  role: Role.merchantOwner,
                  storeId: 'demo-store',
                  membershipTier: MembershipTier.bronze,
                  pointsBalance: 0,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xfff3f5f4),
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xff216940)),
          ),
          routerConfig: _router,
        ),
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  runApp(const ReceiptDemo());
}
