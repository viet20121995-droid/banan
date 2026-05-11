import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_merchant/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryTokenStorage implements TokenStorage {
  StoredTokens? _tokens;
  @override
  Future<StoredTokens?> read() async => _tokens;
  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}

void main() {
  testWidgets('Merchant app shows login when no session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_InMemoryTokenStorage()),
        ],
        child: const BananMerchantApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Banan · Merchant'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
