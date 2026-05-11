# 07 — Production Checklist

Pre-flight before any environment that takes real money. Tick every box.

## Security

- [ ] `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` rotated to 64+ random bytes.
- [ ] `CORS_ORIGINS` lists only the production hostnames (no `localhost`).
- [ ] Helmet defaults enabled — verify `Content-Security-Policy` is on (it is by default in `main.ts`).
- [ ] Postgres user has the minimum privileges needed (no SUPERUSER).
- [ ] S3 bucket is private; public reads come via the CDN base URL only.
- [ ] Stripe webhook signing secret matches the live endpoint.
- [ ] All payment webhooks verify signatures (already done — confirm `STRIPE_WEBHOOK_SECRET`, `VNPAY_HASH_SECRET`, `MOMO_SECRET_KEY` are all set).
- [ ] Rate limits tuned: 5/min register, 10/min login, 30/min refresh; 120/min everywhere else; webhooks bypass throttling.
- [ ] No raw card data on our servers — Stripe Checkout / VNPay / MoMo handle PAN.
- [ ] Token storage: refresh tokens hashed at rest (already done with sha256 in `auth.service`).
- [ ] Refresh-token rotation enabled — re-using a revoked refresh fails.

## Database

- [ ] `prisma migrate deploy` clean — no pending migrations.
- [ ] `prisma migrate diff` against the production schema produces zero drift.
- [ ] Indexes verified: `Order(customerId, createdAt)`, `Order(storeId, status)`, `Order(kitchenId, kitchenStatus)`, `Notification(userId, createdAt)`, etc.
- [ ] Backups enabled with PITR ≥ 7 days.
- [ ] A nightly `pg_dump` to S3 is configured (defense in depth).

## API

- [ ] `/health` returns 200 with `{ ok: true }` against prod DB.
- [ ] Swagger is **disabled** in prod (`main.ts` already gates on `NODE_ENV !== 'production'`).
- [ ] `x-request-id` is being set + echoed in responses.
- [ ] Pino redactions cover `Authorization` + `Cookie` headers (already done).
- [ ] All payment webhooks reachable from the internet (no auth, signature-gated).

## Flutter web

- [ ] Built with `--release --dart-define=BANAN_ENV=prod`.
- [ ] No dev print statements; logger gated to WARNING+ in prod (`Env.isProd`).
- [ ] go_router fallback hits `index.html` for unknown routes (Pages / Vercel SPA mode).
- [ ] Service worker (default Flutter web) versioned per build.
- [ ] App icons + favicon swapped from Flutter defaults.

## Money flow

- [ ] Stripe test charge runs end-to-end through the live webhook.
- [ ] Refund on a captured Stripe charge marks the Payment row REFUNDED.
- [ ] CASH order completes → cash payment row flips CAPTURED automatically on `OrdersService.transition('COMPLETED')`.
- [ ] Cancelled-with-captured-payment creates a `Refund` row in `REQUESTED`.

## Loyalty / coupons

- [ ] Earn rate (10,000 VND per point) and redemption value (100 VND per point) confirmed with finance.
- [ ] Coupon `perUserLimit` enforced (CouponRedemption row inserts in same transaction as the order).
- [ ] Tier thresholds (`gold: 1000`, `platinum: 5000`) confirmed.

## Realtime

- [ ] Socket.IO endpoint reachable through the LB (check WS upgrade headers).
- [ ] Customer / merchant / kitchen rooms are joined automatically per role.
- [ ] Realtime events arrive within 1s of the underlying state change in a 3-machine cluster.

## Observability

- [ ] `LOG_LEVEL=info` in prod.
- [ ] Sentry receives a manually-thrown error.
- [ ] Alerts configured for: `5xx > 1%`, `connection failures`, `webhook signature mismatches`.
- [ ] Health check is the platform's primary readiness probe.

## App stores (when shipping mobile)

- [ ] Privacy policy URL filled in for both stores.
- [ ] Test account credentials submitted with the review.
- [ ] App tracking transparency strings populated (iOS).
- [ ] Push notification permission prompt hooked up (after first sign-in for best opt-in rate).

## Day-2 ops

- [ ] Runbook for "API is down": who pages whom, what to check first.
- [ ] Runbook for "Payments are failing": Stripe dashboard, webhook log, signed-payload replay tool.
- [ ] On-call rotation in PagerDuty / Better Stack.
