# Deploy Banan

Production is a single VPS running Docker Compose: NestJS backend, Postgres,
Redis, and Caddy serving the three Flutter web apps as static files.

| Piece | Where |
| --- | --- |
| Customer | `https://banancakes.vn` |
| Merchant | `https://merchant.banancakes.vn` |
| Kitchen | `https://kitchen.banancakes.vn` |
| API | `https://api.banancakes.vn/api/v1` |
| Server | `/opt/banan` (ssh alias `banan`) |
| Env | `/opt/banan/infra/.env.prod` (see `infra/.env.prod.example`) |

Caddy terminates TLS, proxies `api.*` to the backend container, and serves each
app from `/opt/banan/web/{customer,merchant,kitchen}`, bind-mounted read-only as
`/srv/*`. Container names carry a `-1` suffix (`banan-backend-1`, …).

---

## Backend

Migrations run automatically on boot (`prisma migrate deploy`), so a deploy is
pull + rebuild:

```bash
cd /opt/banan && git pull
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml up -d --build backend
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml logs --tail=50 backend
curl -sS -o /dev/null -w '%{http_code}\n' https://api.banancakes.vn/api/v1/health   # expect 200
```

Backend-only changes need nothing else — the web bundles are independent.

---

## Web apps

**Use the script.** It builds all three with the right defines, uploads, and
unpacks them:

```bash
SERVER=banan bash infra/deploy-web.sh
```

Then restart Caddy and verify in an **Incognito window** — the service worker
serves the previous bundle to an ordinary reload, so a normal refresh (even a
hard one) can't prove a deploy landed:

```bash
cd /opt/banan
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml restart caddy
```

### The defines are not optional

`Env` (`packages/core/lib/src/env/env.dart`) is compiled in from `--dart-define`.
Three ways a build silently ships broken:

| Mistake | What the visitor gets |
| --- | --- |
| No defines at all | `Env` falls back to `http://localhost:3000` — every browser calls **its own** machine. Page loads, then "Cannot reach the kitchen". |
| `BANAN_WS_URL=wss://…` | Dart's `Uri.port` only knows default ports for http/https, so `wss://` resolves to port **0**. Realtime dies against `…:0` while the app looks fine — merchant/kitchen stop receiving pushed orders. Pass `https://`; socket_io_client upgrades itself. |
| `BANAN_ENV=production` | `Env.isProd` compares to the literal `prod`, so this reads as non-prod: Dio's `LogInterceptor` prints every request/response body — passwords, tokens, customer PII — to the live site's console. |

Building by hand (the script already does this):

```pwsh
$API = "https://api.banancakes.vn/api/v1"
$WS  = "https://api.banancakes.vn"

cd apps/banan_customer   # or banan_merchant / banan_kitchen
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$API `
  --dart-define=BANAN_WS_URL=$WS `
  --dart-define=BANAN_CUSTOMER_APP_URL=https://banancakes.vn `
  --dart-define=BANAN_ENV=prod
```

Pass all four to **every** app. `BANAN_CUSTOMER_APP_URL` looks customer-only but
merchant's order detail builds the customer's tracking link from it
(`<customerAppUrl>/track/<id>`) — omit it there and staff hand out
`http://localhost:8081/track/…`, a link that opens only on their own machine.

Check the bundle before shipping it — expect hits for the API, zero for the
other two:

```bash
grep -c 'api.banancakes.vn' build/web/main.dart.js   # > 0
grep -c 'localhost:3000'    build/web/main.dart.js   # 0
grep -c 'wss://'            build/web/main.dart.js   # 0
```

### Shipping one app by hand

On your machine (PowerShell):

```pwsh
tar czf banan-web-customer.tgz --force-local -C apps/banan_customer/build/web .
scp banan-web-customer.tgz banan:/tmp/
```

On the server (`ssh banan`). **Unpack and check before replacing what's live** —
`rm -rf web/customer && tar xzf …` deletes the running site first and only then
discovers the tarball is missing (a previous deploy removes it from /tmp) or
truncated, which serves an empty directory to every customer:

```bash
cd /opt/banan
a=customer
test -s /tmp/banan-web-$a.tgz || echo "no tarball — scp it first"
rm -rf web/$a.new && mkdir -p web/$a.new
tar xzf /tmp/banan-web-$a.tgz -C web/$a.new
test -s web/$a.new/main.dart.js && rm -rf web/$a && mv web/$a.new web/$a
rm -f /tmp/banan-web-$a.tgz
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml restart caddy
```

Confirm the bundle that landed is the one you built — compare against
`md5sum apps/banan_customer/build/web/main.dart.js` locally:

```bash
md5sum web/*/main.dart.js
```

Don't verify by grepping the bundle for on-screen Vietnamese: dart2js escapes
non-ASCII, so "Popup quảng cáo" is stored as `Popup quảng c\xe1o` and a
literal search returns nothing even on a correct build.

---

## Payments (9Pay)

`NINEPAY_ENDPOINT` defaults to the sandbox. Take a real sandbox payment first,
then switch to `https://payment.9pay.vn`. 9Pay support must register both URLs
against the merchant account, and the merchant key differs between sandbox and
production:

- IPN: `https://api.banancakes.vn/api/v1/payments/ninepay/ipn`
- Return: `https://api.banancakes.vn/api/v1/payments/ninepay/return`

COD is off (`COD_ENABLED` unset or not `true`) — the API rejects
`paymentMethod=CASH` with `COD_DISABLED` before the order is created, and the
checkout only offers 9Pay.

---

## Uploads

`/uploads` lives on the VPS disk and is backed by a Docker volume, so it
survives a rebuild. `uploads.service.ts` is structured for S3/R2 if the folder
ever outgrows the box: set `S3_ENDPOINT` / `S3_BUCKET` / `S3_ACCESS_KEY_ID` /
`S3_SECRET_ACCESS_KEY` / `S3_PUBLIC_BASE_URL` and switch the module over.

---

## When something looks wrong

- **"Cannot reach the kitchen"** — the app reached the browser but not the API.
  Check the bundle's defines first (above), then that the backend answers
  `/health`. A transient one during a Caddy restart is expected.
- **Stale UI after deploy** — service worker. Incognito or DevTools →
  Application → Clear site data. A hard refresh is not enough.
- **WebSocket errors in console** — see the `wss://` row above.
