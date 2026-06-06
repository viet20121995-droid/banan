// HTML/JS template strings are built by adjacent-string concatenation and
// StringBuffer cascades — the whitespace/comma/interpolation lints don't
// apply meaningfully to inline markup.
// ignore_for_file: missing_whitespace_between_adjacent_strings, require_trailing_commas, prefer_interpolation_to_compose_strings, avoid_single_cascade_in_expression_statements
import 'dart:js_interop';

import 'package:banan_domain/banan_domain.dart';
import 'package:intl/intl.dart';

@JS('eval')
external JSAny? _eval(String code);

final _fmt =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Human-readable one-line of a cart/order personalization payload.
String _persText(Map<String, dynamic> p) {
  final parts = <String>[];
  final t = p['textOnCake'];
  if (t is String && t.isNotEmpty) parts.add('Chữ: "$t"');
  final c = p['candleCount'];
  if (c != null) parts.add('$c nến');
  final note = p['note'];
  if (note is String && note.isNotEmpty) parts.add('Ghi chú: $note');
  final flavors = p['flavors'];
  if (flavors is Map && flavors.isNotEmpty) {
    parts.add('Vị: ' +
        flavors.entries.map((e) => '${e.value}× ${e.key}').join(', '));
  }
  return parts.join(' · ');
}

void _printHtml(String inner, {required String title}) {
  final doc = '<html><head><meta charset="utf-8"><title>${_esc(title)}</title>'
      '<style>'
      'body{font-family:system-ui,Arial,sans-serif;padding:16px;max-width:380px;'
      'margin:0 auto;color:#111}'
      'h1{font-size:18px;margin:0 0 4px}'
      'h2{font-size:13px;margin:12px 0 4px;border-bottom:1px dashed #999;'
      'padding-bottom:2px;text-transform:uppercase;color:#444}'
      '.row{display:flex;justify-content:space-between;font-size:13px;margin:2px 0}'
      '.muted{color:#666;font-size:12px}'
      '.big{font-size:16px;font-weight:700}'
      '.item{margin:6px 0}'
      '.pers{color:#a0522d;font-size:12px;margin:2px 0 2px 10px}'
      '@media print{button{display:none}}'
      '</style></head><body>$inner'
      '<script>setTimeout(function(){window.print();},250);</script>'
      '</body></html>';
  final escaped = doc
      .replaceAll(r'\', r'\\')
      .replaceAll('`', r'\`')
      .replaceAll(r'$', r'\$');
  _eval(
    '(function(){var w=window.open("","_blank","width=440,height=680");'
    'if(!w)return;w.document.open();w.document.write(`$escaped`);'
    'w.document.close();w.focus();})();',
  );
}

/// Customer receipt — items + prices + total.
void printReceipt(Order order) {
  final b = StringBuffer()
    ..write('<h1>Banan Fukuoka Saigon</h1>')
    ..write('<div class="muted">Phiếu thanh toán</div>')
    ..write(
        '<div class="row"><span>Mã đơn</span><span class="big">${_esc(order.code)}</span></div>')
    ..write(
        '<div class="muted">${DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())}</div>')
    ..write(
        '<div class="muted">${order.fulfillmentType == FulfillmentType.delivery ? 'Giao hàng' : 'Tự đến lấy'}</div>');
  if (order.address != null) {
    b.write(
        '<div class="muted">${_esc(order.address!.recipient)} · ${_esc(order.address!.phone)}<br>${_esc(order.address!.oneLine)}</div>');
  }
  b.write('<h2>Món</h2>');
  for (final it in order.items) {
    b
      ..write('<div class="item"><div class="row">'
          '<span>${it.quantity}× ${_esc(it.productName)}</span>'
          '<span>${_fmt.format(it.lineTotal)}</span></div>');
    if ((it.variantLabel ?? '').isNotEmpty) {
      b.write('<div class="muted">${_esc(it.variantLabel!)}</div>');
    }
    if (it.personalization != null && it.personalization!.isNotEmpty) {
      final t = _persText(it.personalization!);
      if (t.isNotEmpty) b.write('<div class="pers">${_esc(t)}</div>');
    }
    b.write('</div>');
  }
  b
    ..write('<h2></h2>')
    ..write(
        '<div class="row"><span>Tạm tính</span><span>${_fmt.format(order.subtotal)}</span></div>');
  if (order.campaignDiscount > 0) {
    b.write(
        '<div class="row"><span>Khuyến mãi</span><span>−${_fmt.format(order.campaignDiscount)}</span></div>');
  }
  if (order.deliveryFee > 0) {
    b.write(
        '<div class="row"><span>Phí giao</span><span>${_fmt.format(order.deliveryFee)}</span></div>');
  }
  b
    ..write(
        '<div class="row big"><span>Tổng</span><span>${_fmt.format(order.total)}</span></div>')
    ..write(
        '<div class="muted" style="text-align:center;margin-top:16px">Cảm ơn quý khách!</div>');
  _printHtml(b.toString(), title: 'Phiếu ${order.code}');
}

/// Kitchen ticket — items + personalization, no prices.
void printKitchenTicket(Order order) {
  final b = StringBuffer()
    ..write('<h1>PHIẾU BẾP</h1>')
    ..write('<div class="row big"><span>${_esc(order.code)}</span>'
        '<span>${order.fulfillmentType == FulfillmentType.delivery ? 'GIAO' : 'LẤY'}</span></div>')
    ..write(
        '<div class="muted">${DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())}</div>')
    ..write('<h2>Cần làm</h2>');
  for (final it in order.items) {
    b.write('<div class="item big">${it.quantity}× ${_esc(it.productName)}</div>');
    if ((it.variantLabel ?? '').isNotEmpty) {
      b.write('<div class="muted">${_esc(it.variantLabel!)}</div>');
    }
    if (it.personalization != null && it.personalization!.isNotEmpty) {
      final t = _persText(it.personalization!);
      if (t.isNotEmpty) b.write('<div class="pers">★ ${_esc(t)}</div>');
    }
    if ((it.customMessage ?? '').isNotEmpty) {
      b.write('<div class="pers">"${_esc(it.customMessage!)}"</div>');
    }
  }
  if ((order.notes ?? '').isNotEmpty) {
    b.write('<h2>Ghi chú đơn</h2><div>${_esc(order.notes!)}</div>');
  }
  _printHtml(b.toString(), title: 'Bếp ${order.code}');
}
