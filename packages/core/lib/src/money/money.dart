import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// Minor-unit-safe money value object. Stored as integer minor units to avoid
/// floating-point rounding (Dart `double` is unsafe for currency math).
///
/// VND has 0 minor digits, so a minor-unit `100000` is `100,000 VND`.
/// USD has 2 minor digits, so a minor-unit `1234` is `12.34 USD`.
@immutable
class Money implements Comparable<Money> {
  const Money({required this.minorUnits, required this.currency});

  /// Construct from a major-unit decimal — e.g. `Money.fromMajor(12.34, 'USD')`.
  factory Money.fromMajor(num major, String currency) {
    final fraction = _fractionDigitsFor(currency);
    final factor = _pow10(fraction);
    return Money(
      minorUnits: (major * factor).round(),
      currency: currency,
    );
  }

  factory Money.zero(String currency) =>
      Money(minorUnits: 0, currency: currency);

  final int minorUnits;
  final String currency;

  int get fractionDigits => _fractionDigitsFor(currency);
  num get major => minorUnits / _pow10(fractionDigits);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currency: currency,
    );
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currency: currency,
    );
  }

  Money operator *(num factor) =>
      Money(minorUnits: (minorUnits * factor).round(), currency: currency);

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Cannot mix currencies: $currency vs ${other.currency}',
    );
  }

  String format({String? locale}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: _symbolFor(currency),
      decimalDigits: fractionDigits,
    );
    return formatter.format(major);
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money &&
          other.minorUnits == minorUnits &&
          other.currency == currency);

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '$minorUnits $currency';

  static int _fractionDigitsFor(String currency) {
    switch (currency.toUpperCase()) {
      case 'VND':
      case 'JPY':
      case 'KRW':
        return 0;
      default:
        return 2;
    }
  }

  static int _pow10(int n) {
    var v = 1;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  static String _symbolFor(String currency) {
    switch (currency.toUpperCase()) {
      case 'VND':
        return '₫';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }
}
