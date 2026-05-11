import 'package:banan_core/banan_core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('success.when calls success branch', () {
      const result = Result<int, AppFailure>.success(42);
      expect(
        result.when(success: (v) => 'ok:$v', failure: (_) => 'fail'),
        'ok:42',
      );
    });

    test('failure.when calls failure branch', () {
      const result = Result<int, AppFailure>.failure(NetworkFailure());
      expect(
        result.when(success: (_) => 'ok', failure: (f) => f.code),
        'NETWORK',
      );
    });

    test('valueOrNull / failureOrNull', () {
      const ok = Result<int, AppFailure>.success(7);
      expect(ok.valueOrNull, 7);
      expect(ok.failureOrNull, isNull);

      const bad = Result<int, AppFailure>.failure(TimeoutFailure());
      expect(bad.valueOrNull, isNull);
      expect(bad.failureOrNull?.code, 'TIMEOUT');
    });

    test('map preserves failure', () {
      final r = const Result<int, AppFailure>.success(5).map((v) => v * 2);
      expect(r.valueOrNull, 10);

      final f = const Result<int, AppFailure>.failure(UnknownFailure())
          .map((v) => v * 2);
      expect(f.failureOrNull?.code, 'UNKNOWN');
    });
  });

  group('Money', () {
    test('VND has no fractional digits', () {
      final m = Money.fromMajor(150000, 'VND');
      expect(m.minorUnits, 150000);
      expect(m.fractionDigits, 0);
    });

    test('addition rejects mixed currencies', () {
      final vnd = Money.fromMajor(100000, 'VND');
      final usd = Money.fromMajor(10, 'USD');
      expect(() => vnd + usd, throwsA(isA<AssertionError>()));
    });
  });
}
