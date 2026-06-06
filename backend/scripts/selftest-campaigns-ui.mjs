// Verify the ADMIN UI "chọn món/danh mục" pickers feed IDs that actually match
// what the checkout engine checks. Mirrors the exact data sources the merchant
// screen uses: products via /products/merchant/list, categories via /categories.
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
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

(async () => {
  const admin = await login('admin@banan.local', 'banan123');
  ok('admin login', !!admin);

  // 1. EXACT picker source: products via /products/merchant/list.
  let r = await j('GET', '/products/merchant/list?perPage=200', null, admin);
  const mItems = arr(r.data);
  ok(`picker SP: /products/merchant/list tra ${mItems.length} mon`, mItems.length > 0);
  const pm = mItems[0];
  ok('  mon picker co .id', !!pm?.id);

  // 2. The id the picker stores must exist in the CUSTOMER catalog (the id an
  //    order actually carries) — i.e. same Product.id namespace.
  r = await j('GET', '/products?perPage=200');
  const cItems = arr(r.data);
  const inCustomer = cItems.find((p) => p.id === pm.id);
  ok('  ID tu picker merchant CO trong catalog khach (cung Product.id)', !!inCustomer);

  // 3. EXACT picker source: categories via /categories.
  r = await j('GET', '/categories', null, admin);
  const cats = arr(r.data);
  ok(`picker DM: /categories tra ${cats.length} danh muc`, cats.length > 0);
  let catId = pm.categoryId ?? inCustomer?.categoryId;
  if (!catId) { const det = await j('GET', `/products/${pm.id}`); catId = det.data?.categoryId ?? det.data?.category?.id; }
  ok('  category cua mon CO trong picker /categories', cats.some((c) => c.id === catId));

  // Helpers to place an order as a real customer (id from customer catalog).
  const ctok = (await j('POST', '/auth/register', { email: `ui-${Date.now()}@example.com`, password: 'banan123', fullName: 'UI', phone: '09' + String(Date.now()).slice(-8) })).data?.accessToken;
  const place = async () => { const res = await j('POST', '/orders', { items: [{ productId: pm.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, ctok); return { total: Number(res.data?.order?.total), sub: Number(res.data?.order?.subtotal), info: res.data?.order?.campaignInfo }; };
  const mk = (p) => j('POST', '/merchant/campaigns', p, admin);
  const del = (id) => j('DELETE', `/merchant/campaigns/${id}`, null, admin);

  const baseline = await place();
  ok('dat don baseline', baseline.total > 0);

  // 4. PRODUCT_DISCOUNT built from the PICKER's product id → must discount the order.
  {
    const c = await mk({ type: 'PRODUCT_DISCOUNT', name: 'UI SP 20%', config: { kind: 'PERCENT', value: 20, productIds: [pm.id] } });
    const o = await place();
    ok(`CHỌN MÓN: campaign theo id picker -> don GIAM 20% (${baseline.total - o.total}₫)`, near(baseline.total - o.total, Math.round(baseline.sub * 0.2)));
    ok('  campaignInfo ghi ten campaign', Array.isArray(o.info) && o.info.some((x) => x.type === 'PRODUCT_DISCOUNT'));
    await del(c.data.id);
  }

  // 5. CATEGORY_DISCOUNT built from the PICKER's category id → must discount the order.
  if (catId) {
    const c = await mk({ type: 'CATEGORY_DISCOUNT', name: 'UI DM 10%', config: { kind: 'PERCENT', value: 10, categoryIds: [catId] } });
    const o = await place();
    ok(`CHỌN DANH MỤC: campaign theo id picker -> don GIAM 10% (${baseline.total - o.total}₫)`, near(baseline.total - o.total, Math.round(baseline.sub * 0.1)));
    await del(c.data.id);
  }

  // 6. Negative: a campaign scoped to a DIFFERENT product must NOT discount this order.
  {
    const other = cItems.find((p) => p.id !== pm.id);
    if (other) {
      const c = await mk({ type: 'PRODUCT_DISCOUNT', name: 'UI mon khac', config: { kind: 'PERCENT', value: 50, productIds: [other.id] } });
      const o = await place();
      ok('ĐÚNG MÓN: campaign cho mon KHAC -> don nay KHONG giam', near(o.total, baseline.total));
      await del(c.data.id);
    }
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
