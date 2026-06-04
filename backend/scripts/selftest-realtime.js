// Realtime catalog-sync self-test. Connects an ANONYMOUS socket (as a guest
// browser would), triggers a catalog mutation + a config mutation via the
// admin API, and asserts the `public` room received both broadcasts.
// Run: cd backend && node scripts/selftest-realtime.js
const { io } = require('socket.io-client');

const API = process.env.API || 'http://localhost:3000/api/v1';
const WS = process.env.WS || 'http://localhost:3000';

const got = { catalog: false, config: false };

async function main() {
  const sock = io(WS, { transports: ['websocket'] }); // no auth token = guest

  await new Promise((res, rej) => {
    sock.on('connect', res);
    sock.on('connect_error', (e) => rej(new Error('connect_error: ' + e.message)));
    setTimeout(() => rej(new Error('connect timeout')), 5000);
  });
  console.log('  ✓ anonymous socket connected', sock.id);

  sock.on('catalog.changed', () => { got.catalog = true; });
  sock.on('config.changed', () => { got.config = true; });

  // Login admin
  const login = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrPhone: 'admin@banan.local', password: 'banan123' }),
  }).then((r) => r.json());
  const token = login?.data?.accessToken || login?.accessToken;
  if (!token) throw new Error('admin login failed');
  const auth = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  // Catalog mutation (bulk-price dry-run — touches /products, no data change)
  await fetch(`${API}/products/merchant/bulk-price`, {
    method: 'POST',
    headers: auth,
    body: JSON.stringify({ scope: 'all', mode: 'percent', amount: 0, dryRun: true }),
  });
  // Config mutation (idempotent display-config patch)
  await fetch(`${API}/display-config`, {
    method: 'PATCH',
    headers: auth,
    body: JSON.stringify({ showStockToCustomers: false }),
  });

  // Give the broadcast a moment to arrive.
  await new Promise((r) => setTimeout(r, 1500));
  sock.close();

  let fails = 0;
  if (got.catalog) console.log('  ✓ received catalog.changed after product write');
  else { console.log('  ✗ NO catalog.changed'); fails++; }
  if (got.config) console.log('  ✓ received config.changed after config write');
  else { console.log('  ✗ NO config.changed'); fails++; }

  console.log(fails === 0 ? '\nREALTIME SYNC OK (2/2)' : `\nFAIL (${fails})`);
  process.exit(fails);
}

main().catch((e) => { console.error('ERROR:', e.message); process.exit(1); });
