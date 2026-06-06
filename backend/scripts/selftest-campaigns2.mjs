// Phase-2 promotion test: BUY_X_GET_Y, FIRST_ORDER, BIRTHDAY, REACTIVATION.
// Uses docker exec psql to set birthday / backdate orders for the targeted
// campaigns. Assumes local backend on :3000 + dev seed.
import { execSync } from 'node:child_process';
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
const sql = (q) => execSync(`docker exec banan-postgres psql -U banan -d banan -c "${q}"`, { stdio: 'pipe' }).toString();

async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const login = async (e, p) => (await j('POST', '/auth/login', { emailOrPhone: e, password: p })).data?.accessToken;
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();

let seq = 0;
const reg = async () => {
  seq++;
  const phone = '09' + String(Date.now() * 10 + seq).slice(-8);
  const r = await j('POST', '/auth/register', { email: `p2-${Date.now()}-${seq}@example.com`, password: 'banan123', fullName: 'P2 Tester', phone });
  return { tok: r.data?.accessToken, userId: r.data?.user?.id };
};

(async () => {
  const admin = await login('admin@banan.local', 'banan123');
  ok('admin login', !!admin);
  const r = await j('GET', '/products?perPage=5');
  const list = Array.isArray(r.data) ? r.data : (r.data?.items ?? []);
  const p0 = list[0];
  ok('got product', !!p0?.id);

  const place = async (tok, qty = 1) => {
    const res = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: qty }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, tok);
    return { total: Number(res.data?.order?.total), sub: Number(res.data?.order?.subtotal), status: res.status };
  };
  const mk = (payload) => j('POST', '/merchant/campaigns', payload, admin);
  const del = (id) => j('DELETE', `/merchant/campaigns/${id}`, null, admin);
  const near = (a, b) => Math.abs(a - b) <= 2;

  // ── FIRST_ORDER 10% ────────────────────────────────────────────────────
  {
    const c = await mk({ type: 'FIRST_ORDER', name: 'Đơn đầu 10%', config: { kind: 'PERCENT', value: 10 } });
    ok('tạo FIRST_ORDER', !!c.data?.id);
    const { tok } = await reg();
    const o1 = await place(tok);
    ok(`  FIRST_ORDER: đơn ĐẦU giảm 10% (${o1.sub - o1.total}₫ ~ ${Math.round(o1.sub * 0.1)}₫)`, near(o1.sub - o1.total, Math.round(o1.sub * 0.1)));
    const o2 = await place(tok);
    ok('  FIRST_ORDER: đơn THỨ HAI không giảm', near(o2.total, o2.sub));
    await del(c.data.id);
  }

  // ── BUY_X_GET_Y (mua 2 tặng 1) ───────────────────────────────────────────
  {
    const c = await mk({ type: 'BUY_X_GET_Y', name: 'Mua 2 tặng 1', config: { buyQty: 2, getQty: 1, getDiscountPct: 100, productIds: [p0.id] } });
    ok('tạo BUY_X_GET_Y', !!c.data?.id);
    const { tok } = await reg();
    const o = await place(tok, 3); // 3 units → 1 free
    const unit = o.sub / 3;
    ok(`  BXGY: mua 3 -> tặng 1 (giảm ${o.sub - o.total}₫ ~ ${Math.round(unit)}₫)`, near(o.sub - o.total, Math.round(unit)));
    const o2units = await place(tok, 2); // only 2 → not enough for bundle of 3
    ok('  BXGY: mua 2 -> chưa đủ, không giảm', near(o2units.total, o2units.sub));
    await del(c.data.id);
  }

  // ── BIRTHDAY 10% (set birthday = hôm nay) ─────────────────────────────────
  {
    const c = await mk({ type: 'BIRTHDAY', name: 'Sinh nhật 10%', config: { kind: 'PERCENT', value: 10, windowDays: 7 } });
    ok('tạo BIRTHDAY', !!c.data?.id);
    const { tok, userId } = await reg();
    ok('  có userId để set birthday', !!userId);
    sql(`UPDATE \\"User\\" SET \\"birthday\\" = NOW() WHERE id = '${userId}'`);
    const o = await place(tok);
    ok(`  BIRTHDAY: trong tuần sinh nhật giảm 10% (${o.sub - o.total}₫)`, near(o.sub - o.total, Math.round(o.sub * 0.1)));
    // a customer without birthday set → no discount
    const other = await reg();
    const o2 = await place(other.tok);
    ok('  BIRTHDAY: khách không có ngày sinh -> không giảm', near(o2.total, o2.sub));
    await del(c.data.id);
  }

  // ── REACTIVATION 15% (đơn cuối > 60 ngày) ────────────────────────────────
  {
    const c = await mk({ type: 'REACTIVATION', name: 'Kéo lại 15%', config: { kind: 'PERCENT', value: 15, inactiveDays: 60 } });
    ok('tạo REACTIVATION', !!c.data?.id);
    const { tok, userId } = await reg();
    await place(tok); // first order (full price — reactivation needs a PAST order)
    sql(`UPDATE \\"Order\\" SET \\"createdAt\\" = NOW() - INTERVAL '90 days' WHERE \\"customerId\\" = '${userId}'`);
    const o = await place(tok);
    ok(`  REACTIVATION: lâu không mua giảm 15% (${o.sub - o.total}₫ ~ ${Math.round(o.sub * 0.15)}₫)`, near(o.sub - o.total, Math.round(o.sub * 0.15)));
    // a brand-new customer → not "re-activation" (no past order)
    const fresh = await reg();
    const o2 = await place(fresh.tok);
    ok('  REACTIVATION: khách mới (chưa từng mua) -> không giảm', near(o2.total, o2.sub));
    await del(c.data.id);
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
