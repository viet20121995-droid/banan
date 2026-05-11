# 01 — Database Design

The authoritative schema is `backend/prisma/schema.prisma`. This document explains the model and the ERD.

## ERD (textual)

```
User ───< Address
User ───< PaymentMethod
User ───< LoyaltyEvent
User ───< Notification
User ───< RefreshToken
User >─── Store      (merchant staff)
User >─── Kitchen    (kitchen staff)

Store ───< Product
Store ───< Order
Store >─── Kitchen   (defaultKitchen)

Kitchen ───< ProductionBatch
Kitchen ───< Order   (when routed)

Category ───< Product
Product ───< ProductVariant
Product ───< OrderItem
ProductVariant ───< OrderItem

Order ───< OrderItem
Order ───< Payment
Order ───< Refund
Order ───< OrderStatusEvent
Order >─── Coupon

Coupon ───< CouponRedemption
User ───< CouponRedemption
```

## Core entities — purpose at a glance

| Entity | Purpose |
|---|---|
| `User` | Single table for customers + merchants + kitchen staff + admins. `role` discriminates. `storeId` / `kitchenId` are set for staff. |
| `RefreshToken` | One row per active device session; rotated on refresh, revokable individually. |
| `Store` | A physical merchant store. Has its own products and a default `Kitchen` for outsourced production. |
| `Kitchen` | Central kitchen unit. Receives transferred orders, has hourly capacity. |
| `Category` | Global cake category (e.g. *Mousse*, *Tart*, *Seasonal*). |
| `Product` | A cake offered by a `Store`. `basePrice` + variants. Image array, prep time, seasonality flags. |
| `ProductVariant` | Concrete buyable: size + flavor + price delta + optional limited stock. |
| `Address` | Saved customer delivery address. |
| `PaymentMethod` | Tokenized payment method (Stripe customer + payment_method, VNPay token, MoMo). No PAN on our side. |
| `Order` | Header. Holds fulfillment type, scheduled time, totals, both `status` and (optional) `kitchenStatus`. |
| `OrderItem` | Line. Frozen `unitPrice` snapshot — never recompute from product later. |
| `OrderStatusEvent` | Immutable audit trail (status, actor, timestamp, note). |
| `Payment` | One per provider attempt. `(provider, providerRef)` is unique. |
| `Refund` | One per refund request; can be partial; provider reference filled after webhook confirmation. |
| `LoyaltyEvent` | Append-only ledger: earn, redeem, expire, birthday, adjustment. Current balance is `User.pointsBalance` (denormalized for read speed, reconciled by ledger). |
| `Coupon` | Code + type (percent / fixed / free delivery) + window + caps. |
| `CouponRedemption` | One row per use, used to enforce per-user limit. |
| `ProductionBatch` | Kitchen-side planning unit (e.g. *bake 30 chocolate 8" today at 14:00*). |
| `Notification` | In-app inbox + push receipt log. |

## Key invariants enforced at the DB layer

- `Order.total = subtotal + deliveryFee - pointsDiscount - couponDiscount` (validated in app, sanity-checked by a CHECK constraint).
- `Payment.(provider, providerRef)` unique → idempotent webhooks.
- `OrderStatusEvent` is append-only (no UPDATE/DELETE granted to app role).
- `LoyaltyEvent.balanceAfter` must equal sum of prior `delta`s (reconciled by a nightly job).
- `Order` cannot be cancelled if a successful `Payment` exists without a matching `Refund.status = COMPLETED`.

## Indexes

Defined in `schema.prisma`:

- `Order(customerId, createdAt)` — "My Orders" listing.
- `Order(storeId, status)` — merchant queue.
- `Order(kitchenId, kitchenStatus)` — kitchen kanban columns.
- `Order(scheduledFor)` — scheduled-release worker.
- `Product(categoryId, isAvailable)` — menu listing.
- `OrderStatusEvent(orderId, createdAt)` — timeline.
- `Notification(userId, createdAt)` — inbox.

## Migrations

Use Prisma Migrate (`pnpm prisma migrate dev` in development, `migrate deploy` in CI). All schema changes go through migration files committed to the repo. **Never** edit the database manually.

## Seeding

`backend/prisma/seed.ts` will create:
- 1 admin user
- 1 store + 1 manager
- 1 central kitchen + 1 manager
- ~20 products across 5 categories with images
- 2 sample customers, one with a Gold tier
- A handful of historical orders so dashboards have data day-1
