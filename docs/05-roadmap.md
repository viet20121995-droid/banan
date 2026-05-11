# 05 — Build Roadmap

A realistic build order. Each milestone is a *vertical slice* — DB → API → Flutter → wired end-to-end — so the system is always demoable.

## M0 — Skeleton (1–2 days)

- [ ] `flutter create` each app, `nest new backend`, `prisma init`.
- [ ] Wire Melos workspace, lints, formatter, CI (GitHub Actions: lint + analyze + test).
- [ ] Docker compose: postgres + redis.
- [ ] Apply `schema.prisma` migration; seed script with admin + 1 store + 1 kitchen.
- [ ] Hello-world endpoints; Flutter apps render a themed splash that calls `/health`.
- [ ] Design system: tokens + `PrimaryButton`, `AppTextField`, `AppScaffold`.

**Exit:** `melos run customer:run` shows a styled splash hitting the backend; `pnpm prisma studio` shows seeded data.

## M1 — Auth + profile (3–4 days)

- [ ] Backend: `auth.module` (register / login / refresh / logout / me), JWT guards, roles guard, refresh-token rotation.
- [ ] Flutter: `features_shared/auth` (login + register screens) with Riverpod controller.
- [ ] Token storage (`flutter_secure_storage`); Dio interceptor refreshes on 401.
- [ ] Customer profile screen; merchant + kitchen splash redirect on wrong role.

**Exit:** All 3 apps gate behind login; refresh works after access expires.

## M2 — Catalog + customer browse (4–5 days)

- [ ] Backend: `categories`, `products` CRUD; pre-signed S3 upload endpoint; product variants.
- [ ] Flutter customer: `home`, `menu` (filters + search), `product_detail` with variant pickers.
- [ ] Flutter merchant: `menu_mgmt` — list + create + edit + image upload.
- [ ] Design system: `ProductCard`, `AppDataTable`, image grid.

**Exit:** Merchant adds a product → customer sees it within seconds. Filters and search work.

## M3 — Cart + checkout + orders (1 week)

- [ ] Backend: `orders.module` — POST /orders (transactional, snapshot pricing, coupon + points), GET, cancel.
- [ ] Backend: `OrderStatusEvent` writer; `WebSocketGateway` emitting `order.*` events.
- [ ] Flutter customer: `cart` (Riverpod), `checkout` (address picker, fulfillment, schedule, coupon, points), `orders` list.
- [ ] Flutter merchant: `orders_mgmt` queue (live via WebSocket), accept / reject / transitions.

**Exit:** Customer places order; merchant sees it appear instantly; status changes are reflected on the customer's tracking screen in real time.

## M4 — Payments (1 week)

- [ ] Backend: Stripe (intent + webhook), VNPay (create + IPN + return), MoMo (create + IPN). Single `PaymentsService` orchestrating provider strategy.
- [ ] Idempotent webhook handlers — `Payment.(provider, providerRef)` unique.
- [ ] Flutter customer: payment-sheet (Stripe), web/mobile redirect (VNPay/MoMo), success / failure deep-link handlers via `app_links`.

**Exit:** Three end-to-end payment flows pass against provider sandboxes; webhook replay is safe.

## M5 — Refunds + cancel flows (3 days)

- [ ] Backend: `refunds.module` — request, approve, reject; provider-side refund call; status reconciliation.
- [ ] Flutter customer: cancel-eligible UI, refund tracking on order detail.
- [ ] Flutter merchant: refunds inbox, approve / reject.

**Exit:** Cancelled paid order produces a `Refund` that lands `COMPLETED` after provider webhook.

## M6 — Central kitchen (1 week)

- [ ] Backend: `kitchen.module` — transfer endpoint, queue, kanban transitions, dispatch back to store.
- [ ] Flutter kitchen: `queue` list + `production_board` (kanban) wired to WebSocket; `dispatch` view; `batches` CRUD.

**Exit:** Merchant transfers an order; kitchen accepts, walks through statuses on the kanban; customer sees fine-grained kitchen status updates.

## M7 — Loyalty + coupons (4–5 days)

- [ ] Backend: `loyalty.module` — earn on `order.completed`, redeem at checkout, expiry cron, birthday cron.
- [ ] Backend: `coupons.module` — validate at checkout, log redemptions, enforce caps.
- [ ] Flutter customer: `membership` screen (tier, points history, available coupons + birthday reward).

**Exit:** Completing an order awards points; redeeming points reduces the next order's total; birthday coupon issued on the day.

## M8 — Notifications + push (3 days)

- [ ] Backend: FCM admin SDK; per-event push templates; in-app notifications endpoint.
- [ ] Flutter: `features_shared/notifications` — inbox + FCM init + foreground vs background routing; deep-link to order on tap.

**Exit:** Status changes deliver both an in-app entry and a push notification; tap opens the order.

## M9 — Analytics dashboards (3–4 days)

- [ ] Backend: `analytics.module` — SQL views/materialized views for revenue, peak hours, best-sellers, refund rate, kitchen efficiency.
- [ ] Flutter merchant: `dashboard` with `RevenueChart`, `PeakHoursChart`, `StatCard`s.
- [ ] Flutter kitchen: `analytics` view — daily production, delays, capacity utilization.

**Exit:** Demoable dashboards with seeded historical data day-1.

## M10 — Hardening (1 week, ongoing)

- [ ] Rate limiting tuned; Helmet; input fuzzing.
- [ ] OpenAPI published; contract tests in CI.
- [ ] Sentry + log aggregation in apps and backend.
- [ ] Offline mode (customer): cached menu + queued cart actions via Hive.
- [ ] Localization: full vi_VN pass.
- [ ] App Store / Play Store / web hosting pipelines.

## What I'd build first (recommendation)

Once you confirm the foundation, I'd start with **M0 + M1** in one go: scaffold all three Flutter apps, backend, Prisma migration, design-system tokens, and the full auth slice. That gives us a real, runnable system to extend feature-by-feature.

Tell me to "start M0" and I'll begin scaffolding files. If you want to deviate (e.g. Firebase backend instead, or Bloc instead of Riverpod), say so before I scaffold — those choices are expensive to reverse later.
