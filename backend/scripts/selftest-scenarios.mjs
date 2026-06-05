// End-to-end multi-actor scenario test: Customer ↔ Merchant ↔ Kitchen,
// notifications per actor, and customer-facing email triggers.
// Assumes a local backend on :3000 with the dev seed (…@banan.local / banan123).
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const sec = (t) => console.log('\n▶ ' + t);

async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let b = null; try { b = await r.json(); } catch { /* 204 */ }
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data, meta: b?.meta, body: b };
}
const login = async (email, pw) => (await j('POST', '/auth/login', { emailOrPhone: email, password: pw })).data?.accessToken;
const notifTotal = async (tok) => { const r = await j('GET', '/me/notifications?perPage=200', null, tok); return r.meta?.total ?? (Array.isArray(r.data) ? r.data.length : 0); };
const has = (resp, s) => JSON.stringify(resp.body ?? resp.data ?? '').includes(s);
const t = new Date(Date.now() + 86400000); t.setUTCHours(4, 0, 0, 0); const SCHED = t.toISOString();

(async () => {
  // ── Setup ────────────────────────────────────────────────────────────────
  sec('Setup');
  const mtok = await login('merchant@banan.local', 'banan123');
  const ktok = await login('kitchen@banan.local', 'banan123');
  ok('Merchant login', !!mtok);
  ok('Kitchen login', !!ktok);
  const email = `scenario-${Date.now()}@example.com`;
  let r = await j('POST', '/auth/register', { email, password: 'banan123', fullName: 'Scenario Khach', phone: '09' + String(Date.now()).slice(-8) });
  const ctok = r.data?.accessToken;
  ok('Register khách (email thật)', !!ctok);
  r = await j('GET', '/products?perPage=1');
  const pid = Array.isArray(r.data) ? r.data[0]?.id : r.data?.items?.[0]?.id;
  ok('Lấy được productId', !!pid);
  const placePickup = () => j('POST', '/orders', { items: [{ productId: pid, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, ctok);

  // ── 1) Customer ↔ Merchant ────────────────────────────────────────────────
  sec('1) Khách ↔ Merchant');
  const mBefore = await notifTotal(mtok);
  r = await placePickup();
  const oid = r.data?.order?.id, ocode = r.data?.order?.code;
  ok('Khách đặt đơn (' + (ocode || '?') + ')', r.status < 300 && !!oid);
  const mq = await j('GET', '/merchant/orders?perPage=50', null, mtok);
  ok('Merchant thấy đơn trong hàng chờ', has(mq, ocode));
  ok('Merchant nhận thông báo "đơn mới"', (await notifTotal(mtok)) > mBefore);
  const r2 = await placePickup();
  const cx = await j('POST', `/orders/${r2.data?.order?.id}/cancel`, {}, ctok);
  ok('Khách hủy đơn của mình', cx.status < 300 && has(cx, 'CANCELLED'));

  // ── 2) Merchant ↔ Kitchen ─────────────────────────────────────────────────
  sec('2) Merchant ↔ Bếp');
  ok('Merchant nhận đơn (ACCEPTED)', has(await j('POST', `/merchant/orders/${oid}/transition`, { toStatus: 'ACCEPTED' }, mtok), 'ACCEPTED'));
  const kBefore = await notifTotal(ktok);
  const tk = await j('POST', `/merchant/orders/${oid}/transfer-to-kitchen`, { note: 'scenario' }, mtok);
  ok('Đẩy sang bếp (SENT_TO_KITCHEN)', has(tk, 'SENT_TO_KITCHEN'));
  ok('  → kitchenStatus PENDING_ACK', has(tk, 'PENDING_ACK'));
  ok('Bếp thấy đơn trong hàng chờ', has(await j('GET', '/kitchen/orders?perPage=50', null, ktok), ocode));
  ok('Bếp nhận thông báo "đơn từ merchant"', (await notifTotal(ktok)) > kBefore);

  // ── 3) Kitchen → Merchant → Customer ──────────────────────────────────────
  sec('3) Bếp → Merchant → Khách');
  const cBefore = await notifTotal(ctok);
  ok('Bếp PREPARING', has(await j('POST', `/kitchen/orders/${oid}/transition`, { toKitchenStatus: 'PREPARING' }, ktok), 'PREPARING'));
  ok('Bếp READY_DISPATCH', has(await j('POST', `/kitchen/orders/${oid}/transition`, { toKitchenStatus: 'READY_DISPATCH' }, ktok), 'READY_DISPATCH'));
  ok('Bếp dispatch → READY_FOR_PICKUP', has(await j('POST', `/kitchen/orders/${oid}/dispatch`, {}, ktok), 'READY_FOR_PICKUP'));
  const cMid = await notifTotal(ctok);
  ok('Khách nhận thông báo cập nhật trạng thái', cMid > cBefore);
  ok('Merchant hoàn tất (COMPLETED)', has(await j('POST', `/merchant/orders/${oid}/transition`, { toStatus: 'COMPLETED' }, mtok), 'COMPLETED'));
  ok('Khách nhận thông báo hoàn tất', (await notifTotal(ctok)) > cMid);

  // ── 4) Notifications inbox ────────────────────────────────────────────────
  sec('4) Thông báo (inbox + đánh dấu đã đọc)');
  const inbox = await j('GET', '/me/notifications?perPage=10', null, ctok);
  const list = Array.isArray(inbox.data) ? inbox.data : [];
  ok('Khách có danh sách thông báo', list.length > 0);
  if (list.length) ok('Đánh dấu đã đọc (204)', (await j('POST', '/me/notifications/read', { ids: [list[0].id] }, ctok)).status === 204);

  // ── 5) Email tới khách (kích hoạt; xác minh qua log backend) ───────────────
  sec('5) Email gửi tới khách');
  ok('Forgot-password (email thật)', (await j('POST', '/auth/forgot-password', { email })).status < 300);
  ok('Contact form', (await j('POST', '/contact', { name: 'Scenario', email, message: 'Test lien he' })).status < 300);
  ok('Newsletter subscribe', (await j('POST', '/newsletter/subscribe', { email })).status < 300);
  console.log('   (email xác nhận đơn đã gửi trong lúc đổi trạng thái ở phần 2-3)');

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  console.log('REAL_EMAIL=' + email);
  process.exit(fail ? 1 : 0);
})();
