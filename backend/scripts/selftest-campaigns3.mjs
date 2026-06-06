// Phase-3 test: loyalty point redemption at checkout + MEMBERSHIP_BENEFIT
// (per-tier discount). Uses docker exec psql to seed points / tier.
import { execSync } from 'node:child_process';
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const sqlQ = (q) => execSync(`docker exec banan-postgres psql -U banan -d banan -t -c "${q}"`, { stdio: 'pipe' }).toString().trim();
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const login = async (e, p) => (await j('POST', '/auth/login', { emailOrPhone: e, password: p })).data?.accessToken;
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const near = (a, b) => Math.abs(a - b) <= 2;
let seq = 0;
const reg = async () => { seq++; const phone = '09' + String(Date.now() * 10 + seq).slice(-8); const r = await j('POST', '/auth/register', { email: `p3-${Date.now()}-${seq}@example.com`, password: 'banan123', fullName: 'P3', phone }); return { tok: r.data?.accessToken, userId: r.data?.user?.id }; };

(async () => {
  const admin = await login('admin@banan.local', 'banan123');
  ok('admin login', !!admin);
  let r = await j('GET', '/products?perPage=5');
  const p0 = arr(r.data)[0];
  ok('got product', !!p0?.id);

  // Clean slate: remove any active campaign so redemption is isolated.
  for (const c of arr((await j('GET', '/merchant/campaigns', null, admin)).data)) await j('DELETE', `/merchant/campaigns/${c.id}`, null, admin);

  const place = async (tok, points = 0) => {
    const body = { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED };
    if (points > 0) body.pointsToRedeem = points;
    const res = await j('POST', '/orders', body, tok);
    return { total: Number(res.data?.order?.total), sub: Number(res.data?.order?.subtotal), pts: res.data?.order?.pointsRedeemed, status: res.status };
  };
  const bal = (uid) => Number(sqlQ(`SELECT \\"pointsBalance\\" FROM \\"User\\" WHERE id = '${uid}'`));
  const mk = (p) => j('POST', '/merchant/campaigns', p, admin);
  const del = (id) => j('DELETE', `/merchant/campaigns/${id}`, null, admin);

  // ── ĐỔI ĐIỂM ─────────────────────────────────────────────────────────────
  {
    const { tok, userId } = await reg();
    sqlQ(`UPDATE \\"User\\" SET \\"pointsBalance\\" = 500 WHERE id = '${userId}'`);
    const o = await place(tok, 200); // 200 điểm × 100đ = 20.000đ
    ok(`ĐỔI ĐIỂM: 200 điểm -> giảm 20.000đ (thực ${o.sub - o.total}đ)`, near(o.sub - o.total, 20000));
    ok('  order.pointsRedeemed = 200', o.pts === 200);
    ok('  số dư 500 -> 300', bal(userId) === 300);
    const o2 = await place(tok, 1000); // chỉ còn 300 -> cap 300 = 30.000đ
    ok(`  đổi quá số dư -> cap còn 300 điểm (giảm ${o2.sub - o2.total}đ)`, near(o2.sub - o2.total, 30000));
    ok('  số dư 300 -> 0', bal(userId) === 0);
    const o3 = await place(tok, 100); // hết điểm -> không giảm
    ok('  hết điểm -> không giảm', near(o3.total, o3.sub) && o3.pts === 0);
  }

  // ── ƯU ĐÃI THEO HẠNG (MEMBERSHIP_BENEFIT) ────────────────────────────────
  {
    const c = await mk({ type: 'MEMBERSHIP_BENEFIT', name: 'Hạng thành viên', config: { kind: 'PERCENT', tierValues: { GOLD: 5, PLATINUM: 10 } } });
    ok('tạo MEMBERSHIP_BENEFIT', !!c.data?.id);

    const gold = await reg();
    sqlQ(`UPDATE \\"User\\" SET \\"membershipTier\\" = 'GOLD' WHERE id = '${gold.userId}'`);
    const og = await place(gold.tok);
    ok(`  GOLD -> giảm 5% (${og.sub - og.total}đ ~ ${Math.round(og.sub * 0.05)}đ)`, near(og.sub - og.total, Math.round(og.sub * 0.05)));

    const plat = await reg();
    sqlQ(`UPDATE \\"User\\" SET \\"membershipTier\\" = 'PLATINUM' WHERE id = '${plat.userId}'`);
    const op = await place(plat.tok);
    ok(`  PLATINUM -> giảm 10% (${op.sub - op.total}đ ~ ${Math.round(op.sub * 0.10)}đ)`, near(op.sub - op.total, Math.round(op.sub * 0.10)));

    const silver = await reg(); // mặc định SILVER
    const os = await place(silver.tok);
    ok('  SILVER -> không giảm (tierValues không có SILVER)', near(os.total, os.sub));

    await del(c.data.id);
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
