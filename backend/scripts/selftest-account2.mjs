// Test the NEW account features: notification prefs, email change (request +
// confirm), account deletion (anonymise + keep order history).
import { execSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const sql = (q) => execSync(`docker exec banan-postgres psql -U banan -d banan -t -c "${q}"`, { stdio: 'pipe' }).toString().trim();
const sha = (s) => createHash('sha256').update(s).digest('hex');
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();
let seq = 0;
const reg = async () => { seq++; const email = `acc2-${Date.now()}-${seq}@example.com`; const r = await j('POST', '/auth/register', { email, password: 'banan123', fullName: 'Acc2', phone: '09' + String(Date.now() * 10 + seq).slice(-8) }); return { tok: r.data?.accessToken, userId: r.data?.user?.id, email }; };

(async () => {
  const p0 = (await j('GET', '/products?perPage=3')).data?.items?.[0] ?? (await j('GET', '/products?perPage=3')).data?.[0];
  ok('got product', !!p0?.id);

  // ── PREFS ──────────────────────────────────────────────────────────────
  {
    const a = await reg();
    await j('PATCH', '/auth/me', { marketingOptIn: false, orderUpdatesOptIn: false }, a.tok);
    const me = (await j('GET', '/auth/me', null, a.tok)).data?.user;
    ok('TUỲ CHỌN: tắt marketing + order updates', me?.marketingOptIn === false && me?.orderUpdatesOptIn === false);
    await j('PATCH', '/auth/me', { marketingOptIn: true }, a.tok);
    ok('  bật lại marketing', (await j('GET', '/auth/me', null, a.tok)).data?.user?.marketingOptIn === true);
  }

  // ── ĐỔI EMAIL (request) ──────────────────────────────────────────────────
  const other = await reg(); // để test email trùng
  {
    const b = await reg();
    const newEmail = `new-${Date.now()}@example.com`;
    ok('ĐỔI EMAIL yêu cầu -> 200', (await j('POST', '/auth/change-email', { newEmail, password: 'banan123' }, b.tok)).status === 200);
    ok('  có bản ghi EmailChange', Number(sql(`SELECT count(*) FROM \\"EmailChange\\" WHERE \\"userId\\"='${b.userId}' AND \\"usedAt\\" IS NULL`)) >= 1);
    ok('  sai mật khẩu -> 401', (await j('POST', '/auth/change-email', { newEmail: 'x@y.com', password: 'wrong' }, b.tok)).status === 401);
    ok('  email đã dùng -> 409', (await j('POST', '/auth/change-email', { newEmail: other.email, password: 'banan123' }, b.tok)).status === 409);
  }

  // ── ĐỔI EMAIL (confirm — chèn token đã biết) ─────────────────────────────
  {
    const c = await reg();
    const raw = 'tok-' + Date.now();
    const target = `confirmed-${Date.now()}@example.com`;
    sql(`INSERT INTO \\"EmailChange\\" (id,\\"userId\\",\\"newEmail\\",\\"tokenHash\\",\\"expiresAt\\",\\"createdAt\\") VALUES ('${randomUUID()}','${c.userId}','${target}','${sha(raw)}',NOW()+INTERVAL '1 hour',NOW())`);
    ok('ĐỔI EMAIL xác nhận -> 200', (await j('POST', '/auth/change-email/confirm', { token: raw })).status === 200);
    ok('  đăng nhập bằng email MỚI được', !!(await j('POST', '/auth/login', { emailOrPhone: target, password: 'banan123' })).data?.accessToken);
    ok('  token sai -> 400', (await j('POST', '/auth/change-email/confirm', { token: 'bad' })).status === 400);
  }

  // ── XOÁ TÀI KHOẢN ────────────────────────────────────────────────────────
  {
    const d = await reg();
    await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, d.tok);
    await j('POST', '/addresses', { label: 'N', recipient: 'A', phone: '0900000001', line1: 'x', city: 'HCM' }, d.tok);
    ok('XOÁ TK: sai mật khẩu -> 401', (await j('POST', '/auth/delete-account', { password: 'wrong' }, d.tok)).status === 401);
    ok('XOÁ TK: đúng mật khẩu -> 204', (await j('POST', '/auth/delete-account', { password: 'banan123' }, d.tok)).status === 204);
    ok('  email cũ KHÔNG đăng nhập được', (await j('POST', '/auth/login', { emailOrPhone: d.email, password: 'banan123' })).status >= 400);
    ok('  địa chỉ đã xoá sạch', Number(sql(`SELECT count(*) FROM \\"Address\\" WHERE \\"userId\\"='${d.userId}'`)) === 0);
    ok('  đơn hàng vẫn còn (lịch sử)', Number(sql(`SELECT count(*) FROM \\"Order\\" WHERE \\"customerId\\"='${d.userId}'`)) >= 1);
    ok('  user đã ẩn danh', sql(`SELECT \\"fullName\\" FROM \\"User\\" WHERE id='${d.userId}'`).includes('xo'));
    ok('  user đã vô hiệu (isActive=false)', sql(`SELECT \\"isActive\\" FROM \\"User\\" WHERE id='${d.userId}'`).startsWith('f'));
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
