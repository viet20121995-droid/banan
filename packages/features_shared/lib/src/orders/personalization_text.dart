/// Text helpers for `OrderItem.personalization` shared by the merchant and
/// kitchen apps (boards, detail pages, printed tickets).
///
/// Birthday cakes store the wizard payload
/// `{ textOnCake, candleType, candleCount, candleNumber, note }`; macaron
/// sets store `{ flavors: { Jasmine: 3, Lemon: 2 } }`.
library;

/// Candle instruction for the baker: "3 nến xoắn", "nến số 25", "5 nến".
/// Backward-compat: a legacy payload with `candleCount` but no `candleType`
/// is treated as regular candles.
String? candleTicketLabel(Map<String, dynamic> p) {
  final count = (p['candleCount'] as num?)?.toInt();
  final number = (p['candleNumber'] as num?)?.toInt();
  final type =
      (p['candleType'] as String?) ?? (count != null ? 'regular' : null);
  switch (type) {
    case 'number':
      if (number == null) return null;
      return 'nến số $number';
    case 'spiral':
      if (count == null) return null;
      return '$count nến xoắn';
    case 'regular':
      if (count == null) return null;
      return '$count nến';
    default:
      return null;
  }
}

/// One line with everything the kitchen must do for the item:
/// `Chữ: "Happy birthday" · nến số 30 · Vị: 3× Jasmine, 2× Lemon`.
String personalizationText(Map<String, dynamic> p) {
  final parts = <String>[];
  final t = p['textOnCake'];
  if (t is String && t.isNotEmpty) parts.add('Chữ: "$t"');
  final candle = candleTicketLabel(p);
  if (candle != null) parts.add(candle);
  final note = p['note'];
  if (note is String && note.isNotEmpty) parts.add('Ghi chú: $note');
  final flavors = p['flavors'];
  if (flavors is Map && flavors.isNotEmpty) {
    parts.add(
      'Vị: ${flavors.entries.map((e) => '${e.value}× ${e.key}').join(', ')}',
    );
  }
  return parts.join(' · ');
}
