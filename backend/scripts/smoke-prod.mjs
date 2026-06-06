// PRODUCTION smoke test — exercises the live customer surface with a
// throwaway account, then self-deletes it. No admin password needed.
// Reports per-feature; tolerates not-yet-deployed endpoints (404).
const BASE = 'https://api.banancakes.vn/api/v1';
let pass = 0, fail = 0, skip = 0; const notes = [];
const ok = (n, c, detail = '') => { c ? (pass++, console.log('  \x1b[32m✓\x1b[0m ' + n)) : (fail++, console.log('  \x1b[31m✗\x1b[0m ' + n + (detail ? '  — ' + detail : ''))); };
const nd = (n) => { skip++; console.log('  \x1b[33m•\x1b[0m ' + n + '  — CHƯA DEPLOY (404)'); notes.push(n); };
async function j(method, path, body, tok) {
  const r = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined });
  let b = null; try { b = await r.json(); } catch {}
  const data = b && typeof b === 'object' && 'data' in b ? b.data : b;
  return { status: r.status, data };
}
const arr = (d) => Array.isArray(d) ? d : (d?.items ?? []);
const sched = new Date(Date.now() + 86400000); sched.setUTCHours(4, 0, 0, 0); const SCHED = sched.toISOString();

(async () => {
  console.log('=== SMOKE TEST PRODUCTION (banancakes.vn) ===\n');
  const stamp = Date.now();
  const email = `smoke-${stamp}@example.com`;
  const phone = '09' + String(stamp).slice(-8);

  // REGISTER
  let r = await j('POST', '/auth/register', { email, password: 'Smoke12345', fullName: 'Smoke Test', phone });
  const tok = r.data?.accessToken; const userId = r.data?.user?.id;
  ok('Đăng ký tài khoản', !!tok && !!userId, `status ${r.status}`);
  if (!tok) { console.log('\nKhông đăng ký được — dừng.'); process.exit(1); }

  // PROFILE
  r = await j('GET', '/auth/me', null, tok);
  const me = r.data?.user ?? r.data;
  ok('Đọc hồ sơ (GET /auth/me)', me?.email === email);
  ok('  hạng mặc định = BRONZE', me?.membershipTier === 'BRONZE', `tier=${me?.membershipTier}`);

  // GENDER (module mới)
  r = await j('PATCH', '/auth/me', { gender: 'FEMALE', fullName: 'Smoke Nữ' }, tok);
  if (r.status === 400 && JSON.stringify(r.data).includes('gender')) nd('Giới tính (PATCH gender)');
  else ok('Giới tính: đặt FEMALE', (await j('GET', '/auth/me', null, tok)).data?.user?.gender === 'FEMALE');

  // NOTIF PREFS (module mới)
  r = await j('PATCH', '/auth/me', { marketingOptIn: false }, tok);
  const meP = (await j('GET', '/auth/me', null, tok)).data?.user;
  if (meP && 'marketingOptIn' in meP) ok('Tuỳ chọn thông báo (marketingOptIn)', meP.marketingOptIn === false);
  else nd('Tuỳ chọn thông báo');

  // ADDRESS + wardCode (bug đã sửa)
  r = await j('POST', '/addresses', { label: 'Nhà', recipient: 'Smoke', phone, line1: '1 Lê Lợi', city: 'TP.HCM', wardCode: '26734', isDefault: true }, tok);
  const addrId = r.data?.id;
  ok('Sổ địa chỉ: tạo', !!addrId);
  ok('  wardCode trả về đúng (bug đã sửa)', r.data?.wardCode === '26734', `wardCode=${r.data?.wardCode}`);
  if (addrId) ok('  xoá địa chỉ', (await j('DELETE', `/addresses/${addrId}`, null, tok)).status === 204);

  // LOYALTY
  r = await j('GET', '/me/loyalty', null, tok);
  ok('Điểm thưởng / hạng (GET /me/loyalty)', r.status === 200 && ('tier' in (r.data ?? {})));
  ok('  có ngưỡng Bronze (4 hạng)', !!(r.data?.thresholds && 'bronze' in r.data.thresholds));

  // VOUCHER WALLET (module mới)
  r = await j('GET', '/coupons/mine', null, tok);
  if (r.status === 404) nd('Ví voucher (GET /coupons/mine)');
  else ok('Ví voucher: 3 nhóm khả dụng/đã dùng/hết hạn', Array.isArray(r.data?.available) && Array.isArray(r.data?.used) && Array.isArray(r.data?.expired));

  // WISHLIST + ORDER
  const prod = arr((await j('GET', '/products?perPage=5')).data)[0];
  ok('Catalog: có sản phẩm', !!prod?.id);
  if (prod?.id) {
    await j('POST', `/wishlist/${prod.id}`, null, tok);
    ok('Yêu thích: thêm', arr((await j('GET', '/wishlist', null, tok)).data).length > 0);
    await j('DELETE', `/wishlist/${prod.id}`, null, tok);

    const placed = await j('POST', '/orders', { items: [{ productId: prod.id, quantity: 1 }], fulfillmentType: 'PICKUP', paymentMethod: 'CASH', scheduledFor: SCHED }, tok);
    const orderId = placed.data?.order?.id;
    ok('Đặt đơn (COD, lấy tại quầy)', !!orderId, `status ${placed.status}`);
    if (orderId) {
      ok('  đơn vào lịch sử', arr((await j('GET', '/orders?perPage=20', null, tok)).data).some((o) => o.id === orderId));
      ok('  huỷ đơn (dọn dẹp)', (await j('POST', `/orders/${orderId}/cancel`, { reason: 'smoke test cleanup' }, tok)).status < 300);
    }
  }

  // CHANGE EMAIL request (module mới) — chỉ kiểm tra nhận yêu cầu, không xác nhận
  r = await j('POST', '/auth/change-email', { newEmail: `smoke2-${stamp}@example.com`, password: 'Smoke12345' }, tok);
  if (r.status === 404) nd('Đổi email (POST /auth/change-email)');
  else ok('Đổi email: nhận yêu cầu (gửi link xác nhận)', r.status === 200);

  // DELETE ACCOUNT (module mới) — cũng là bước dọn dẹp
  r = await j('POST', '/auth/delete-account', { password: 'Smoke12345' }, tok);
  if (r.status === 404) { nd('Xoá tài khoản (POST /auth/delete-account) — KHÔNG dọn được tài khoản thử!'); }
  else {
    ok('Xoá tài khoản (dọn dẹp)', r.status === 204);
    ok('  email cũ không đăng nhập lại được', (await j('POST', '/auth/login', { emailOrPhone: email, password: 'Smoke12345' })).status >= 400);
  }

  console.log(`\n=== ${pass} PASS · ${fail} FAIL · ${skip} CHƯA DEPLOY ===`);
  if (notes.length) console.log('Cần deploy bản mới cho: ' + notes.join(', '));
  process.exit(fail ? 1 : 0);
})();
