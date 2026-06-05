// Self-test for the new account features. Assumes a local backend on :3000
// with the dev seed (admin@banan.local / banan123).
const BASE = 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const check = (name, cond) => { cond ? (pass++, console.log('  PASS', name)) : (fail++, console.log('  FAIL', name)); };

async function j(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let respBody = null;
  try { respBody = await res.json(); } catch { /* 204 etc */ }
  // Success responses are wrapped by EnvelopeInterceptor as { data: ... }.
  // Error responses are not, so fall back to the raw body.
  const data =
    respBody && typeof respBody === 'object' && 'data' in respBody
      ? respBody.data
      : respBody;
  return { status: res.status, data, body: respBody };
}

(async () => {
  let r = await j('POST', '/auth/login', { emailOrPhone: 'admin@banan.local', password: 'banan123' });
  check('admin login', r.status === 200 && !!r.data.accessToken);
  const adminTok = r.data.accessToken;

  r = await j('POST', '/auth/forgot-password', { email: 'customer@banan.local' });
  check('forgot-password (known) → 200 ok', r.status === 200 && r.data.ok === true);
  r = await j('POST', '/auth/forgot-password', { email: 'nobody-xyz@nowhere.test' });
  check('forgot-password (unknown) → 200 ok (no leak)', r.status === 200 && r.data.ok === true);
  r = await j('POST', '/auth/reset-password', { token: 'invalid-token-xxxxx', newPassword: 'whatever123' });
  check('reset-password invalid token → 400', r.status === 400);

  r = await j('GET', '/admin/stores', null, adminTok);
  const storeId = r.data?.[0]?.id;
  check('list stores', Array.isArray(r.data) && !!storeId);

  const email = 'selftest-' + Date.now() + '@banan.local';
  r = await j('POST', '/admin/users', { email, password: 'banan123', fullName: 'Self Test', role: 'MERCHANT_OWNER', storeId }, adminTok);
  check('admin create user → 201', r.status === 201 && !!r.data.id);
  const uid = r.data.id;

  r = await j('GET', '/admin/users/' + uid, null, adminTok);
  check('admin get user (isActive=true)', r.status === 200 && r.data.isActive === true);

  r = await j('PATCH', '/admin/users/' + uid, { fullName: 'Renamed', role: 'CUSTOMER' }, adminTok);
  check('admin update (rename + role→CUSTOMER clears store)', r.status === 200 && r.data.fullName === 'Renamed' && r.data.role === 'CUSTOMER' && r.data.storeId === null);

  r = await j('POST', '/auth/login', { emailOrPhone: email, password: 'banan123' });
  check('new user login', r.status === 200 && !!r.data.accessToken);
  const uTok = r.data.accessToken;

  r = await j('POST', '/auth/change-password', { currentPassword: 'wrong', newPassword: 'newpass123' }, uTok);
  check('change-password wrong current → 401', r.status === 401);
  r = await j('POST', '/auth/change-password', { currentPassword: 'banan123', newPassword: 'newpass123' }, uTok);
  check('change-password correct → 204', r.status === 204);
  r = await j('POST', '/auth/login', { emailOrPhone: email, password: 'newpass123' });
  check('login with new password', r.status === 200);

  r = await j('POST', '/admin/users/' + uid + '/reset-password', { password: 'admset123' }, adminTok);
  check('admin reset-password → ok', r.status === 201 && r.data.ok === true);
  r = await j('POST', '/auth/login', { emailOrPhone: email, password: 'admset123' });
  check('login after admin reset', r.status === 200);

  r = await j('DELETE', '/admin/users/' + uid, null, adminTok);
  check('admin deactivate → ok', r.status === 200 && r.data.ok === true);
  r = await j('POST', '/auth/login', { emailOrPhone: email, password: 'admset123' });
  check('login blocked after deactivate (AUTH_ACCOUNT_DISABLED)', r.status === 401 && r.body?.error?.code === 'AUTH_ACCOUNT_DISABLED');

  r = await j('PATCH', '/admin/users/' + uid, { isActive: true }, adminTok);
  check('reactivate', r.status === 200 && r.data.isActive === true);
  r = await j('POST', '/auth/login', { emailOrPhone: email, password: 'admset123' });
  check('login works after reactivate', r.status === 200);

  r = await j('GET', '/admin/users?role=ADMIN', null, adminTok);
  const adminId = (Array.isArray(r.data) ? r.data : []).find((u) => u.role === 'ADMIN')?.id;
  if (adminId) {
    r = await j('PATCH', '/admin/users/' + adminId, { fullName: 'hacked' }, adminTok);
    check('cannot edit ADMIN → 400', r.status === 400);
    r = await j('DELETE', '/admin/users/' + adminId, null, adminTok);
    check('cannot deactivate ADMIN → 400', r.status === 400);
  }

  console.log(`\n=== ${pass} PASS, ${fail} FAIL ===`);
  process.exit(fail ? 1 : 0);
})();
