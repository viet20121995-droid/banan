// Browser-only: pumping the whole app pulls in locale_store / web_storage /
// pwa_install / push_registration, which import dart:js_interop
// unconditionally, so this cannot compile on the VM. Marked rather than deleted
// — it tests real behaviour, it just needs `flutter test --platform chrome`.
// The lasting fix is conditional imports for those web-only files (main.dart
// already does it for url_strategy), which would make the app VM-testable.
@TestOn('browser')
library;

import 'package:banan_customer/app/app.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
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
  testWidgets('Customer app shows login when no session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_InMemoryTokenStorage()),
        ],
        child: const BananCustomerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Banan'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
