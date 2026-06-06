// Admin/merchant ↔ customer interaction flows: order-status email + in-app
// notification, merchant message, gift points, GIFT VOUCHER, broadcast.
import { execSync } from 'node:child_process';
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const near = (a, b) => Math.abs(a - b) <= 2;
const dryRunCount = () => { try { return Number(execSync('grep -cF "[email dry-run]" /tmp/banan-be.log', { stdio: 'pipe' }).toString().trim()); } catch { return 0; } };
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const login = async (e, p) => (await j('POST', '/auth/login', { emailOrPhone: e, password: p })).data?.accessToken;
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const notifs = async (tok) => { const r = await j('GET', '/me/notifications?perPage=10', null, tok); const d = r.data; return Array.isArray(d) ? d : (Array.isArray(d?.data) ? d.data : (Array.isArray(d?.items) ? d.items : [])); };
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();

(async () => {
  const admin = await login('admin@banan.local', 'banan123');
  const merchant = await login('merchant@banan.local', 'banan123');
  ok('admin + merchant login', !!admin && !!merchant);
  const p0 = arr((await j('GET', '/products?perPage=5')).data)[0];

  // Customer + an order (so customer is "served").
  const email = `intx-${Date.now()}@example.com`;
  const ctok = (await j('POST', '/auth/register', { email, password: 'banan123', fullName: 'Intx', phone: '09' + String(Date.now()).slice(-8) })).data?.accessToken;
  const cid = (await j('GET', '/auth/me', null, ctok)).data?.user?.id;
  const oid = (await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, ctok)).data?.order?.id;
  ok('khách + đơn hàng', !!cid && !!oid);

  // 1. ORDER STATUS → in-app notification + email
  const before = (await notifs(ctok)).length;
  const mailBefore = dryRunCount();
  await j('POST', `/merchant/orders/${oid}/transition`, { toStatus: 'ACCEPTED' }, merchant);
  await new Promise((r) => setTimeout(r, 1200)); // email is fire-and-forget
  const afterN = await notifs(ctok);
  ok('ĐƠN: ACCEPTED → khách nhận thông báo in-app', afterN.length > before);
  ok('  → email trạng thái đơn gửi đi (dry-run log tăng)', dryRunCount() > mailBefore);

  // 2. MERCHANT MESSAGE (admin → 1 khách)
  await j('POST', `/merchant/customers/${cid}/notify`, { title: 'Lời cảm ơn', body: 'Cảm ơn bạn đã ủng hộ Banan!' }, admin);
  ok('NHẮN TIN: khách nhận thông báo merchant.message', (await notifs(ctok)).some((n) => n.type === 'merchant.message'));

  // 3. GIFT POINTS
  const pr = await j('POST', `/merchant/customers/${cid}/points`, { delta: 200, reason: 'tri ân khách hàng' }, admin);
  ok('TẶNG ĐIỂM: số dư +200', Number(pr.data?.balance) >= 200);
  ok('  → thông báo loyalty.adjustment', (await notifs(ctok)).some((n) => n.type === 'loyalty.adjustment'));

  // 4. GIFT VOUCHER (tặng voucher cá nhân 🎁)
  const gv = await j('POST', `/merchant/customers/${cid}/coupon`, { type: 'PERCENT', value: 15, days: 30 }, admin);
  const code = gv.data?.code;
  ok('TẶNG VOUCHER: trả về mã', !!code);
  ok('  → thông báo coupon.gift 🎁', (await notifs(ctok)).some((n) => n.type === 'coupon.gift'));
  const baseOrder = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, ctok);
  const subForVoucher = Number(baseOrder.data?.order?.subtotal);
  await j('POST', `/orders/${baseOrder.data?.order?.id}/cancel`, { reason: 'baseline' }, ctok);
  const used = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', couponCode: code, scheduledFor: SCHED }, ctok);
  ok('  voucher tặng DÙNG ĐƯỢC (giảm 15%)', near(subForVoucher - Number(used.data?.order?.total), Math.round(subForVoucher * 0.15)));
  const wallet = (await j('GET', '/coupons/mine', null, ctok)).data;
  ok('  voucher vào ví "đã dùng"', wallet?.used?.some((v) => v.code === code));

  // 5. BROADCAST (admin → nhiều khách)
  const bc = await j('POST', '/merchant/customers/broadcast', { title: 'Bánh mới ra lò 🍰', body: 'Ghé Banan thử vị mới nhé!' }, admin);
  ok('BROADCAST: gửi tới ≥1 khách', Number(bc.data?.sent) >= 1);
  ok('  → khách nhận thông báo merchant.broadcast', (await notifs(ctok)).some((n) => n.type === 'merchant.broadcast'));

  // 6. CONTACT FORM → email tới admin
  const mb = dryRunCount();
  const cf = await j('POST', '/contact', { name: 'Khách', email: 'guest@example.com', subject: 'Hỏi đặt bánh', message: 'Tôi muốn đặt bánh sinh nhật.' });
  await new Promise((r) => setTimeout(r, 1000));
  ok('FORM HỖ TRỢ: nhận yêu cầu + gửi email admin', cf.status < 300 && dryRunCount() > mb);

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
