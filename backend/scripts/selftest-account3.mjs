// Test the newest customer modules: gender, BRONZE base tier, voucher wallet.
import { execSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const sql = (q) => execSync(`docker exec banan-postgres psql -U banan -d banan -t -c "${q}"`, { stdio: 'pipe' }).toString().trim();
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();
let seq = 0;
const reg = async () => { seq++; const r = await j('POST', '/auth/register', { email: `a3-${Date.now()}-${seq}@example.com`, password: 'banan123', fullName: 'A3', phone: '09' + String(Date.now() * 10 + seq).slice(-8) }); return { tok: r.data?.accessToken, userId: r.data?.user?.id }; };
const mkCoupon = (code, daysStart, daysEnd) => sql(`INSERT INTO \\"Coupon\\" (id,code,type,value,\\"startsAt\\",\\"endsAt\\",\\"perUserLimit\\",\\"isActive\\",redemptions,\\"createdAt\\") VALUES ('${randomUUID()}','${code}','PERCENT',10,NOW()+INTERVAL '${daysStart} day',NOW()+INTERVAL '${daysEnd} day',1,true,0,NOW())`);

(async () => {
  const p0 = arr((await j('GET', '/products?perPage=3')).data)[0];
  ok('got product', !!p0?.id);

  // ── GIỚI TÍNH ──────────────────────────────────────────────────────────
  {
    const a = await reg();
    await j('PATCH', '/auth/me', { gender: 'FEMALE' }, a.tok);
    ok('GIỚI TÍNH: đặt FEMALE', (await j('GET', '/auth/me', null, a.tok)).data?.user?.gender === 'FEMALE');
    await j('PATCH', '/auth/me', { gender: 'OTHER' }, a.tok);
    ok('  đổi sang OTHER', (await j('GET', '/auth/me', null, a.tok)).data?.user?.gender === 'OTHER');
    ok('  giá trị sai bị từ chối (400)', (await j('PATCH', '/auth/me', { gender: 'XYZ' }, a.tok)).status === 400);
  }

  // ── HẠNG BRONZE (mặc định) + 4 ngưỡng ────────────────────────────────────
  {
    const b = await reg();
    ok('HẠNG: khách mới = BRONZE', (await j('GET', '/auth/me', null, b.tok)).data?.user?.membershipTier === 'BRONZE');
    const loy = await j('GET', '/me/loyalty', null, b.tok);
    ok('  /me/loyalty trả tier BRONZE', loy.data?.tier === 'BRONZE');
    const th = loy.data?.thresholds ?? {};
    ok('  có đủ 4 ngưỡng (bronze/silver/gold/platinum)', 'bronze' in th && 'silver' in th && 'gold' in th && 'platinum' in th);
  }

  // ── VÍ VOUCHER (khả dụng / đã dùng / hết hạn) ────────────────────────────
  {
    const code = 'WALLET' + String(Date.now()).slice(-6);
    const expCode = 'EXP' + String(Date.now()).slice(-6);
    mkCoupon(code, -1, 30);      // active now
    mkCoupon(expCode, -60, -1);  // already expired
    const c = await reg();
    let w = (await j('GET', '/coupons/mine', null, c.tok)).data;
    ok('VÍ: có nhóm available/used/expired', !!w && Array.isArray(w.available) && Array.isArray(w.used) && Array.isArray(w.expired));
    ok('  voucher khả dụng chứa code mới', w.available.some((v) => v.code === code));
    ok('  voucher hết hạn chứa expired code', w.expired.some((v) => v.code === expCode));
    ok('  chưa dùng -> không ở "đã dùng"', !w.used.some((v) => v.code === code));
    // dùng nó
    const o = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', couponCode: code, scheduledFor: SCHED }, c.tok);
    ok('  đặt đơn với voucher thành công', !!o.data?.order?.id);
    w = (await j('GET', '/coupons/mine', null, c.tok)).data;
    ok('  sau khi dùng -> "đã dùng" chứa code', w.used.some((v) => v.code === code));
    ok('  hết lượt (perUserLimit 1) -> rời "khả dụng"', !w.available.some((v) => v.code === code));
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
