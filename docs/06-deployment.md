# 06 — Deployment Guide

This document covers shipping Banan to a real environment. The dev stack
runs locally via Docker Compose; production splits into managed services.

## Architecture for production

```
┌──────────────────┐        ┌──────────────────┐
│ Customer (Web)   │        │ Customer (iOS/   │
│ Cloudflare Pages │        │ Android — Play /  │
│ or Vercel        │        │ App Store)       │
└────────┬─────────┘        └────────┬─────────┘
         │  HTTPS                     │ HTTPS
         └─────────────┬───────────────┘
                       │
              ┌────────▼─────────┐
              │  api.banan.app   │  Fly.io / Render / Railway
              │  NestJS + WS     │  (3+ replicas behind a TLS load balancer)
              └────────┬─────────┘
                       │
       ┌───────────────┼─────────────────┬────────────────┐
       │               │                 │                │
   ┌───▼─────┐  ┌──────▼─────┐    ┌──────▼─────┐    ┌─────▼──────┐
   │ Postgres│  │ Redis      │    │ S3 / R2    │    │ FCM        │
   │ (managed │ │ (Upstash / │    │ (uploads + │    │ (push)     │
   │  RDS)   │  │  Memorystore)   │  CDN)      │    │            │
   └─────────┘  └────────────┘    └────────────┘    └────────────┘
```

## Prerequisites

- A managed Postgres 16+ instance (Supabase, RDS, Neon, etc.)
- A managed Redis (Upstash, Memorystore, ElastiCache)
- An S3-compatible bucket for uploads (Cloudflare R2 is the cheapest)
- Stripe live keys (or VNPay merchant + MoMo partner credentials)
- Firebase project with FCM enabled (service account JSON)
- A domain with TLS (Cloudflare in front of everything is the simplest)

## Backend

### Build the container

```dockerfile
# backend/Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && corepack prepare pnpm@9 --activate \
 && pnpm install --frozen-lockfile

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN corepack enable && corepack pnpm build && corepack pnpm prisma:generate

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY package.json ./
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

> Currently we're on `pnpm dev`; add the Dockerfile above when you cut a
> first deploy. Until then run `pnpm prisma:deploy && pnpm start:prod` on
> a worker host.

### Required env vars in production

| Variable | Notes |
|---|---|
| `NODE_ENV` | Always `production`. |
| `DATABASE_URL` | Managed Postgres connection string. |
| `REDIS_URL` | Managed Redis. Used for pub/sub and queues. |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Long random — `openssl rand -base64 64`. Rotate yearly. |
| `CORS_ORIGINS` | Comma-separated `https://app.banan.app,https://merchant.banan.app,https://kitchen.banan.app`. |
| `S3_*` | R2 / S3 credentials and bucket name. |
| `S3_PUBLIC_BASE_URL` | CDN-fronted URL. |
| `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` | Live keys. Webhook secret is per environment. |
| `VNPAY_*` / `MOMO_*` | Live merchant credentials. |
| `FCM_SERVICE_ACCOUNT_PATH` | Path to the JSON file in the container. Mount as a secret volume. |
| `LOG_LEVEL` | `info` in prod. |
| `SENTRY_DSN` *(optional)* | When set, errors flow to Sentry. |

### Migrations

```bash
pnpm prisma migrate deploy   # never `migrate dev` in prod
```

Run as a one-shot job before rolling new app versions. Migrations are
forward-only — never `prisma db push` against production.

### Health, readiness, liveness

`/api/v1/health` returns `{ ok, environment, timestamp }` and pings the
DB. Configure your platform's health check to hit this and treat
non-200 as unhealthy.

### TLS + WebSocket

The Socket.IO endpoint runs at the same host. Ensure your TLS terminator
forwards `Connection: Upgrade` and `Upgrade: websocket`. Cloudflare needs
"WebSockets" toggled on for the proxied DNS record.

## Flutter customer (web)

```bash
cd apps/banan_customer
flutter build web --release \
  --dart-define=BANAN_API_BASE_URL=https://api.banan.app/api/v1 \
  --dart-define=BANAN_WS_URL=https://api.banan.app \
  --dart-define=BANAN_ENV=prod
```

Deploy the contents of `build/web/` to:

- **Cloudflare Pages** (recommended — free, instant cache invalidation)
- **Vercel** static
- **Netlify**

Set the `_redirects` (Netlify) or `_headers` to send `index.html` for any
unknown path so go_router's deep links work.

## Flutter merchant + kitchen (web)

Same flow as customer, different `--web-port` during dev and different
hostname in prod. Suggested:

- `merchant.banan.app` → built `banan_merchant`
- `kitchen.banan.app` → built `banan_kitchen`

Both apps require `BANAN_API_BASE_URL` to point at the same backend.
Update `CORS_ORIGINS` on the backend to include all three hostnames.

## Flutter customer (mobile)

When you're ready for native apps:

```bash
# iOS
cd apps/banan_customer
flutter build ipa --release \
  --dart-define=BANAN_API_BASE_URL=https://api.banan.app/api/v1 \
  --dart-define=BANAN_WS_URL=wss://api.banan.app \
  --dart-define=BANAN_ENV=prod

# Android
flutter build appbundle --release --dart-define=...
```

You'll need:
- Apple developer account + App Store Connect entry
- Google Play Console
- App icons + splash assets (we ship Flutter defaults today; a brand pass
  before submission is recommended)
- Privacy policy URL (loyalty + payment data triggers App Store review)
- Push notifications: an APNs key uploaded to Firebase + Play Store
  notification permission flow

## CI / CD outline

```
pull_request:
  - pnpm -C backend lint + test
  - dart analyze (root, all packages)
  - flutter test (each app)
  - prisma migrate diff --from-migrations --to-schema (no drift)

push to main:
  - build and push backend image
  - run `prisma migrate deploy`
  - rolling restart of API replicas
  - flutter build web for all 3 apps
  - upload to Cloudflare Pages
```

GitHub Actions reference workflows live in `docs/07-runbook.md` (TBD —
land alongside the first prod cut).

## Backups & disaster recovery

- Postgres: enable point-in-time recovery (PITR) — most managed DBs default to 7 days.
- S3 bucket: enable versioning + lifecycle to delete old versions after 30 days.
- Backups exclude PII redaction — handle GDPR / Vietnamese PDPL requests via the export endpoint (TBD).

## Monitoring & alerting

- **Logs**: Pino JSON to stdout → ship via your platform (Fly's `flyctl logs`, Render's log explorer, or pipe to Logtail / Datadog).
- **Errors**: set `SENTRY_DSN` to forward unhandled exceptions.
- **Metrics**: `/health` for liveness; add `/metrics` (Prometheus) when you need it (M-later).
- **Alerts**: at minimum, page on `5xx > 1%` and `db_connections > 80%`.

## Rolling out the first version

1. Provision Postgres, Redis, S3 bucket, Stripe live keys.
2. Set every env var. **Verify CORS_ORIGINS, JWT secrets, STRIPE_WEBHOOK_SECRET.**
3. Run `prisma migrate deploy`.
4. Run `pnpm prisma:seed` ONLY if you want the demo data; otherwise create the first admin via a one-off `tsx scripts/create-admin.ts` (TBD).
5. Deploy backend → verify `/health`.
6. Configure Stripe webhook endpoint at `https://api.banan.app/api/v1/payments/stripe/webhook`. Copy the signing secret into the env.
7. Build + deploy each Flutter web app.
8. Smoke test: register a customer, place a CASH order, walk it through merchant + kitchen.
