// Gift-order ("tặng quà khi đặt hàng") backend test.
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();

(async () => {
  const ctok = (await j('POST', '/auth/register', { email: `gift-${Date.now()}@example.com`, password: 'banan123', fullName: 'Gift', phone: '09' + String(Date.now()).slice(-8) })).data?.accessToken;
  const p0 = arr((await j('GET', '/products?perPage=5')).data)[0];
  ok('khách + sản phẩm', !!ctok && !!p0?.id);

  // Gift order
  const gift = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED, isGift: true, giftMessage: 'Chúc mừng sinh nhật! 🎂', giftRecipientName: 'Lan Anh', giftRecipientPhone: '0909000111', giftWrap: true, hidePrice: true }, ctok);
  const oid = gift.data?.order?.id;
  ok('Đặt ĐƠN QUÀ TẶNG', !!oid);
  const o = (await j('GET', `/orders/${oid}`, null, ctok)).data;
  ok('  isGift = true', o?.isGift === true);
  ok('  lời chúc lưu đúng', o?.giftMessage === 'Chúc mừng sinh nhật! 🎂');
  ok('  người nhận: tên', o?.giftRecipientName === 'Lan Anh');
  ok('  người nhận: SĐT', o?.giftRecipientPhone === '0909000111');
  ok('  gói quà = true', o?.giftWrap === true);
  ok('  ẩn giá = true', o?.hidePrice === true);

  // Non-gift order — gift fields must NOT leak
  const ng = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED, giftMessage: 'phải bị bỏ qua' }, ctok);
  const o2 = (await j('GET', `/orders/${ng.data?.order?.id}`, null, ctok)).data;
  ok('Đơn THƯỜNG: isGift=false + không dính lời chúc', o2?.isGift === false && !o2?.giftMessage && o2?.giftWrap === false && o2?.hidePrice === false);

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
