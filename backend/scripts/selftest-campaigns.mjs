// Phase-1 promotion-engine test: PRODUCT_DISCOUNT, CATEGORY_DISCOUNT,
// FLASH_SALE, HAPPY_HOUR auto-applied at checkout + admin CRUD.
// Assumes local backend on :3000 with dev seed (admin@banan.local / banan123).
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };

async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data, body: b };
}
const login = async (e, p) => (await j('POST', '/auth/login', { emailOrPhone: e, password: p })).data?.accessToken;
const t = new Date(Date.now() + 86400000); t.setUTCHours(4, 0, 0, 0); const SCHED = t.toISOString();

(async () => {
  const admin = await login('admin@banan.local', 'banan123');
  ok('admin login', !!admin);

  // A product + its category.
  let r = await j('GET', '/products?perPage=5');
  const list = Array.isArray(r.data) ? r.data : (r.data?.items ?? []);
  const p0 = list[0];
  ok('got product', !!p0?.id);
  let categoryId = p0.categoryId;
  if (!categoryId) {
    const det = await j('GET', `/products/${p0.id}`);
    categoryId = det.data?.categoryId ?? det.data?.category?.id;
  }
  ok('got categoryId', !!categoryId);

  // Fresh customer (0 points → no loyalty perk muddying totals).
  const email = `camp-${Date.now()}@example.com`;
  const ctok = (await j('POST', '/auth/register', { email, password: 'banan123', fullName: 'Camp Tester', phone: '09' + String(Date.now()).slice(-8) })).data?.accessToken;
  ok('register customer', !!ctok);

  const place = async () => {
    const res = await j('POST', '/orders', { items: [{ productId: p0.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, ctok);
    return { total: Number(res.data?.order?.total), sub: Number(res.data?.order?.subtotal) };
  };

  // Baseline (no campaign).
  const base = await place();
  ok('baseline order placed', base.total > 0);
  const SUB = base.sub;

  const campaigns = [];
  const mkCampaign = async (payload) => {
    const res = await j('POST', '/merchant/campaigns', payload, admin);
    if (res.data?.id) campaigns.push(res.data.id);
    return res;
  };
  const expectDiscount = async (label, payload, pct) => {
    const c = await mkCampaign(payload);
    ok(`tạo ${label}`, !!c.data?.id);
    const after = await place();
    const disc = base.total - after.total;
    const want = Math.round(SUB * pct / 100);
    ok(`  ${label}: giảm ${disc}₫ (mong ${want}₫)`, Math.abs(disc - want) <= 1);
    // deactivate so it doesn't interfere with the next test
    await j('PATCH', `/merchant/campaigns/${c.data.id}`, { isActive: false }, admin);
    const afterOff = await place();
    ok(`  ${label}: tắt -> hết giảm`, Math.abs(afterOff.total - base.total) <= 1);
    return c.data.id;
  };

  await expectDiscount('PRODUCT_DISCOUNT 20%', { type: 'PRODUCT_DISCOUNT', name: 'SP 20%', config: { kind: 'PERCENT', value: 20, productIds: [p0.id] } }, 20);
  await expectDiscount('CATEGORY_DISCOUNT 10%', { type: 'CATEGORY_DISCOUNT', name: 'DM 10%', config: { kind: 'PERCENT', value: 10, categoryIds: [categoryId] } }, 10);
  await expectDiscount('FLASH_SALE 15% (window now)', { type: 'FLASH_SALE', name: 'Flash 15%', startsAt: new Date(Date.now() - 3600000).toISOString(), endsAt: new Date(Date.now() + 3600000).toISOString(), config: { kind: 'PERCENT', value: 15 } }, 15);
  await expectDiscount('HAPPY_HOUR 10% (00:00-23:59)', { type: 'HAPPY_HOUR', name: 'HH 10%', config: { kind: 'PERCENT', value: 10, startTime: '00:00', endTime: '23:59' } }, 10);

  // FLASH_SALE outside its window → NO discount.
  const expired = await mkCampaign({ type: 'FLASH_SALE', name: 'Flash het han', startsAt: new Date(Date.now() - 7200000).toISOString(), endsAt: new Date(Date.now() - 3600000).toISOString(), config: { kind: 'PERCENT', value: 50 } });
  const afterExpired = await place();
  ok('FLASH_SALE ngoài cửa sổ -> KHÔNG giảm', Math.abs(afterExpired.total - base.total) <= 1);

  // FIXED-kind discount.
  const fixedC = await mkCampaign({ type: 'PRODUCT_DISCOUNT', name: 'SP -20k', config: { kind: 'FIXED', value: 20000, productIds: [p0.id] } });
  const afterFixed = await place();
  ok('PRODUCT_DISCOUNT FIXED -20k', Math.abs((base.total - afterFixed.total) - Math.min(20000, SUB)) <= 1);
  await j('PATCH', `/merchant/campaigns/${fixedC.data.id}`, { isActive: false }, admin);

  // Admin CRUD.
  r = await j('GET', '/merchant/campaigns', null, admin);
  ok('admin list campaigns', Array.isArray(r.data) && r.data.length >= campaigns.length);
  if (campaigns.length) {
    const del = await j('DELETE', `/merchant/campaigns/${campaigns[0]}`, null, admin);
    ok('admin delete campaign', del.status < 300);
  }
  // non-admin blocked
  r = await j('GET', '/merchant/campaigns', null, ctok);
  ok('khách bị chặn khỏi /merchant/campaigns (403)', r.status === 403);

  // cleanup remaining
  for (const id of campaigns.slice(1)) await j('DELETE', `/merchant/campaigns/${id}`, null, admin);
  await j('DELETE', `/merchant/campaigns/${fixedC.data?.id}`, null, admin);

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
