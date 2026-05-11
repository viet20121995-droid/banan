# Deploy Banan to the internet

Two artifacts (`backend/Dockerfile` + `backend/fly.toml`) make the backend
runnable on any host that speaks Docker. Today we use **Fly.io** for backend
+ Postgres + Redis (free tier) and **Cloudflare Pages** for the three Flutter
web apps (also free). Migrating off later = `docker pull` somewhere else and
flip DNS — zero code changes.

---

## Prerequisites

You install these once, on your machine:

1. **Fly CLI** — `iwr https://fly.io/install.ps1 -useb | iex` (PowerShell)
2. **Wrangler** (Cloudflare CLI) — `npm install -g wrangler`
3. **GitHub account** + a new private repo (we push the code there so you can
   redeploy from anywhere). Skip if you don't want Git remote yet.

Then `fly auth login` and `wrangler login` to sign into both services.

---

## 1. Deploy the backend to Fly.io

```pwsh
cd backend

# First-time setup. Accept the defaults; choose region "sin" (Singapore).
# When prompted for Postgres / Redis, say yes — Fly attaches them and
# injects DATABASE_URL / REDIS_URL into the app automatically.
fly launch --copy-config --no-deploy

# Set the rest of the env vars (everything that isn't DB/Redis).
fly secrets set `
  JWT_ACCESS_SECRET="$(openssl rand -base64 64)" `
  JWT_REFRESH_SECRET="$(openssl rand -base64 64)" `
  JWT_ACCESS_TTL="15m" `
  JWT_REFRESH_TTL="30d" `
  CORS_ORIGINS="https://customer-banan.pages.dev,https://merchant-banan.pages.dev,https://kitchen-banan.pages.dev"
  # ↑ replace the three URLs after step 2 once Cloudflare Pages assigns them.

fly deploy
```

After deploy:

- API lives at `https://banan-api.fly.dev`
- Health check: `https://banan-api.fly.dev/api/v1/health`
- One-time seed (sample products / admin user / etc.):
  `fly ssh console -C "node node_modules/prisma/build/index.js db seed"`

---

## 2. Deploy the three Flutter web apps to Cloudflare Pages

Each app is a static `build/web/` directory after `flutter build web`. We push
those to Cloudflare Pages.

```pwsh
# From repo root.
$API = "https://banan-api.fly.dev/api/v1"
$WS  = "wss://banan-api.fly.dev"

# Customer
cd apps/banan_customer
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$API `
  --dart-define=BANAN_WS_URL=$WS `
  --dart-define=BANAN_ENV=prod
wrangler pages deploy build/web --project-name=customer-banan

# Merchant
cd ../banan_merchant
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$API `
  --dart-define=BANAN_WS_URL=$WS `
  --dart-define=BANAN_ENV=prod
wrangler pages deploy build/web --project-name=merchant-banan

# Kitchen
cd ../banan_kitchen
flutter build web --release `
  --dart-define=BANAN_API_BASE_URL=$API `
  --dart-define=BANAN_WS_URL=$WS `
  --dart-define=BANAN_ENV=prod
wrangler pages deploy build/web --project-name=kitchen-banan
```

After deploy, Cloudflare shows you the three URLs:

- `https://customer-banan.pages.dev`
- `https://merchant-banan.pages.dev`
- `https://kitchen-banan.pages.dev`

Add them to `CORS_ORIGINS` on Fly:

```pwsh
fly secrets set CORS_ORIGINS="https://customer-banan.pages.dev,https://merchant-banan.pages.dev,https://kitchen-banan.pages.dev" --app banan-api
```

Fly rolls a new machine, CORS now allows the apps.

---

## 3. (Later) Custom domain via Cloudflare

When you're ready to graduate from `*.pages.dev` and `*.fly.dev`:

1. **Buy a domain** at Cloudflare Registrar (~$10/yr, at-cost).
2. **DNS records**:
   - `api.yourdomain.com` → `CNAME` to `banan-api.fly.dev`
   - `app.yourdomain.com` → Cloudflare Pages custom domain → `customer-banan.pages.dev`
   - `merchant.yourdomain.com` → → `merchant-banan.pages.dev`
   - `kitchen.yourdomain.com` → → `kitchen-banan.pages.dev`
3. **Re-build Flutter** with the new API URL:
   `--dart-define=BANAN_API_BASE_URL=https://api.yourdomain.com/api/v1` and
   redeploy.
4. **Update CORS_ORIGINS** on Fly to include the new domains.

That's the full graduation path — same code, same Docker image, just new DNS.

---

## 4. (Production) Move uploads to Cloudflare R2

The local `/uploads` folder lives inside the Fly machine and won't survive a
deploy. For real users:

1. Create an R2 bucket in Cloudflare (free 10 GB/month, no egress fees).
2. `fly secrets set S3_ENDPOINT=... S3_BUCKET=... S3_ACCESS_KEY_ID=... S3_SECRET_ACCESS_KEY=... S3_PUBLIC_BASE_URL=...`
3. Switch `UploadsModule` to write to S3 when those vars are set (the code is
   already structured for this — `uploads.service.ts` has the placeholder).

---

## Reset / redeploy

- **Backend code change** → `cd backend && fly deploy`
- **Flutter UI change** → repeat the `flutter build web` + `wrangler pages deploy` for the affected app
- **Database wipe** → `fly postgres connect -a banan-api-db`, then `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` — and re-run migrations + seed
