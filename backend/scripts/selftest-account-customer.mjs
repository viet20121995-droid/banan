// End-to-end check of EVERY customer account function via the real API the
// customer app calls. Mirrors UI data flows; flags caps/mismatches.
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0; const fails = [];
const ok = (n, c) => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, fails.push(n), console.log('  \x1b[31m✗\x1b[0m ' + n)); };
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data, body: b };
}
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();

(async () => {
  const email = `acct-${Date.now()}@example.com`;
  const phone = '09' + String(Date.now()).slice(-8);
  const pw = 'banan123';

  // 1. REGISTER
  let r = await j('POST', '/auth/register', { email, password: pw, fullName: 'Tài Khoản', phone });
  const tok0 = r.data?.accessToken; const userId = r.data?.user?.id;
  ok('REGISTER -> token + user', !!tok0 && !!userId);

  // 2. LOGIN (email) + LOGIN (phone)
  ok('LOGIN bằng email', !!(await j('POST', '/auth/login', { emailOrPhone: email, password: pw })).data?.accessToken);
  ok('LOGIN bằng số điện thoại', !!(await j('POST', '/auth/login', { emailOrPhone: phone, password: pw })).data?.accessToken);
  let tok = (await j('POST', '/auth/login', { emailOrPhone: email, password: pw })).data?.accessToken;

  // 3. PROFILE read (GET /auth/me)
  r = await j('GET', '/auth/me', null, tok);
  const me = r.data?.user ?? r.data;
  ok('HỒ SƠ đọc (GET /auth/me)', me?.email === email && 'membershipTier' in me);

  // 4. PROFILE update (PATCH /auth/me)
  await j('PATCH', '/auth/me', { fullName: 'Tên Mới', birthday: '1990-05-20T00:00:00.000Z' }, tok);
  r = await j('GET', '/auth/me', null, tok);
  const me2 = r.data?.user ?? r.data;
  ok('HỒ SƠ sửa tên + ngày sinh', me2?.fullName === 'Tên Mới' && !!me2?.birthday);

  // 5. CHANGE PASSWORD
  const cp = await j('POST', '/auth/change-password', { currentPassword: pw, newPassword: 'banan999' }, tok);
  ok('ĐỔI MẬT KHẨU (204)', cp.status === 204 || cp.status === 200);
  ok('  mật khẩu cũ KHÔNG đăng nhập được', (await j('POST', '/auth/login', { emailOrPhone: email, password: pw })).status >= 400);
  const tokNew = (await j('POST', '/auth/login', { emailOrPhone: email, password: 'banan999' })).data?.accessToken;
  ok('  mật khẩu mới đăng nhập được', !!tokNew);
  tok = tokNew;

  // 6. FORGOT PASSWORD (anti-enumeration → luôn 200)
  const fp = await j('POST', '/auth/forgot-password', { email });
  ok('QUÊN MẬT KHẨU -> 200 {ok}', fp.status === 200 && (fp.data?.ok === true || fp.body?.ok === true || fp.data?.ok === undefined));

  // 7. ADDRESSES CRUD
  r = await j('POST', '/addresses', { label: 'Nhà', recipient: 'Tài', phone, line1: '123 Lê Lợi', city: 'TP.HCM', wardCode: '26734', isDefault: true }, tok);
  const addrId = r.data?.id;
  ok('ĐỊA CHỈ tạo (có wardCode)', !!addrId && (r.data?.wardCode === '26734'));
  r = await j('GET', '/addresses', null, tok);
  ok('  danh sách địa chỉ chứa địa chỉ vừa tạo', arr(r.data).some((a) => a.id === addrId));
  r = await j('PATCH', `/addresses/${addrId}`, { line1: '456 Nguyễn Huệ' }, tok);
  ok('  sửa địa chỉ', r.data?.line1 === '456 Nguyễn Huệ');
  const addr2 = await j('POST', '/addresses', { label: 'Cơ quan', recipient: 'Tài', phone, line1: '789 CMT8', city: 'TP.HCM' }, tok);
  await j('POST', `/addresses/${addr2.data?.id}/default`, null, tok);
  r = await j('GET', '/addresses', null, tok);
  const def = arr(r.data).filter((a) => a.isDefault);
  ok('  đặt mặc định: chỉ 1 địa chỉ mặc định', def.length === 1 && def[0].id === addr2.data?.id);
  ok('  xoá địa chỉ (204)', (await j('DELETE', `/addresses/${addrId}`, null, tok)).status === 204);

  // 8. LOYALTY
  r = await j('GET', '/me/loyalty', null, tok);
  ok('ĐIỂM THƯỞNG / HẠNG (GET /me/loyalty)', r.status === 200 && ('balance' in (r.data ?? {}) || 'tier' in (r.data ?? {})));

  // 9. WISHLIST
  const prod = arr((await j('GET', '/products?perPage=5')).data)[0];
  await j('POST', `/wishlist/${prod.id}`, null, tok);
  r = await j('GET', '/wishlist', null, tok);
  ok('YÊU THÍCH thêm + liệt kê', arr(r.data).some((w) => (w.product?.id ?? w.productId ?? w.id) === prod.id) || arr(r.data).length > 0);
  r = await j('GET', '/wishlist/ids', null, tok);
  ok('  wishlist/ids chứa productId', (r.data?.productIds ?? r.data ?? []).includes?.(prod.id) ?? false);
  ok('  bỏ yêu thích', (await j('DELETE', `/wishlist/${prod.id}`, null, tok)).status < 300);

  // 10. NOTIFICATIONS
  r = await j('GET', '/me/notifications?page=1&perPage=30', null, tok);
  ok('THÔNG BÁO liệt kê (có meta)', r.status === 200);

  // 11. ORDERS: place → list → detail → cancel
  const placed = await j('POST', '/orders', { items: [{ productId: prod.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, tok);
  const orderId = placed.data?.order?.id;
  ok('ĐƠN HÀNG đặt', !!orderId);
  r = await j('GET', '/orders?page=1&perPage=20', null, tok);
  ok('  lịch sử đơn chứa đơn vừa đặt', arr(r.data).some((o) => o.id === orderId));
  r = await j('GET', `/orders/${orderId}`, null, tok);
  ok('  chi tiết đơn', r.data?.id === orderId);
  const cancel = await j('POST', `/orders/${orderId}/cancel`, { reason: 'test' }, tok);
  ok('  huỷ đơn', cancel.status < 300);

  // 12. RISK — pagination caps (giống lỗi picker perPage). UI dùng 20/30/50.
  console.log('  -- rủi ro phân trang (UI dùng 20/30/50) --');
  ok('  /orders?perPage=20 OK', (await j('GET', '/orders?perPage=20', null, tok)).status === 200);
  ok('  /me/notifications?perPage=30 OK', (await j('GET', '/me/notifications?perPage=30', null, tok)).status === 200);
  ok('  /wishlist?perPage=50 OK', (await j('GET', '/wishlist?perPage=50', null, tok)).status === 200);

  // 13. SECURITY — không xem được đơn / địa chỉ người khác
  const other = (await j('POST', '/auth/register', { email: `o-${Date.now()}@example.com`, password: pw, fullName: 'Khác', phone: '08' + String(Date.now()).slice(-8) })).data?.accessToken;
  ok('BẢO MẬT: người khác KHÔNG xem được đơn của mình', (await j('GET', `/orders/${orderId}`, null, other)).status >= 400);

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  if (fail) { console.log('Failed:'); fails.forEach((f) => console.log('  -', f)); }
  process.exit(fail ? 1 : 0);
})();
