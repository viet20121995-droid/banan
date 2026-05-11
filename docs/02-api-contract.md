# 02 — API Contract

All routes are versioned under `/api/v1`. JSON in / JSON out. Auth via `Authorization: Bearer <accessToken>` unless marked **public**.

Standard envelope:

```json
// success
{ "data": { ... }, "meta": { "page": 1, "perPage": 20, "total": 137 } }

// error
{ "error": { "code": "ORDER_NOT_FOUND", "message": "Order not found", "details": {} } }
```

## Auth

| Method | Path | Public | Body | Returns |
|---|---|---|---|---|
| POST | `/auth/register` | yes | `{email, phone?, password, fullName}` | `{user, accessToken, refreshToken}` |
| POST | `/auth/login` | yes | `{emailOrPhone, password}` | `{user, accessToken, refreshToken}` |
| POST | `/auth/refresh` | yes | `{refreshToken, deviceId?}` | `{accessToken, refreshToken}` |
| POST | `/auth/logout` | | `{refreshToken}` | `{}` |
| POST | `/auth/forgot-password` | yes | `{email}` | `{}` |
| POST | `/auth/reset-password` | yes | `{token, password}` | `{}` |
| GET | `/auth/me` | | – | `{user}` |

## Catalog (read = public, write = staff)

| Method | Path | Roles | Notes |
|---|---|---|---|
| GET | `/categories` | public | – |
| GET | `/products` | public | Query: `categoryId, q, minPrice, maxPrice, size, flavor, seasonal, storeId, page, perPage, sort` |
| GET | `/products/:id` | public | – |
| POST | `/products` | MERCHANT_* | Create product (scoped to caller's store). |
| PATCH | `/products/:id` | MERCHANT_* | – |
| DELETE | `/products/:id` | MERCHANT_OWNER | – |
| POST | `/products/:id/variants` | MERCHANT_* | – |
| PATCH | `/products/:id/variants/:variantId` | MERCHANT_* | – |
| DELETE | `/products/:id/variants/:variantId` | MERCHANT_* | – |
| POST | `/uploads/sign` | MERCHANT_* | Returns pre-signed S3 URL for image upload. |

## Customer

| Method | Path | Roles | Notes |
|---|---|---|---|
| GET | `/me/addresses` | CUSTOMER | – |
| POST | `/me/addresses` | CUSTOMER | – |
| PATCH | `/me/addresses/:id` | CUSTOMER | – |
| DELETE | `/me/addresses/:id` | CUSTOMER | – |
| GET | `/me/payment-methods` | CUSTOMER | – |
| POST | `/me/payment-methods` | CUSTOMER | `{provider, token, isDefault}` |
| DELETE | `/me/payment-methods/:id` | CUSTOMER | – |
| GET | `/me/loyalty` | CUSTOMER | `{tier, balance, history}` |

## Orders

| Method | Path | Roles | Notes |
|---|---|---|---|
| POST | `/orders` | CUSTOMER | Body: `{storeId, items[], fulfillmentType, addressId?, scheduledFor?, paymentMethodId, couponCode?, pointsToRedeem?}`. Returns the order **and** a `paymentIntent` blob suited to the chosen provider (Stripe `client_secret`, VNPay redirect URL, MoMo deep link). |
| GET | `/orders` | CUSTOMER | Caller's orders. `?status=...&page=` |
| GET | `/orders/:id` | CUSTOMER (own), MERCHANT_* (own store), KITCHEN_* (own kitchen), ADMIN | – |
| GET | `/orders/:id/timeline` | same | Returns `OrderStatusEvent[]`. |
| POST | `/orders/:id/cancel` | CUSTOMER (when allowed), MERCHANT_*, ADMIN | Triggers refund if paid. |
| POST | `/orders/:id/reorder` | CUSTOMER | Returns a draft order body to repost to `POST /orders`. |

### Merchant order ops

| Method | Path | Roles |
|---|---|---|
| GET | `/merchant/orders` | MERCHANT_* — `?status, dateFrom, dateTo, q` |
| POST | `/merchant/orders/:id/accept` | MERCHANT_* |
| POST | `/merchant/orders/:id/reject` | MERCHANT_* — body `{reason}` |
| POST | `/merchant/orders/:id/transition` | MERCHANT_* — body `{toStatus, note?}` |
| POST | `/merchant/orders/:id/transfer-to-kitchen` | MERCHANT_* — body `{kitchenId?, note?}` |
| POST | `/merchant/orders/:id/refund` | MERCHANT_* — body `{amount, reason}` |

### Kitchen order ops

| Method | Path | Roles |
|---|---|---|
| GET | `/kitchen/orders` | KITCHEN_* — kanban data, grouped by `kitchenStatus` |
| POST | `/kitchen/orders/:id/accept` | KITCHEN_* |
| POST | `/kitchen/orders/:id/reject` | KITCHEN_MANAGER |
| POST | `/kitchen/orders/:id/transition` | KITCHEN_* — body `{toKitchenStatus, note?}` |
| POST | `/kitchen/orders/:id/dispatch` | KITCHEN_* — sets order back to `READY_FOR_PICKUP` or `DELIVERING` |
| GET | `/kitchen/batches` | KITCHEN_* |
| POST | `/kitchen/batches` | KITCHEN_MANAGER |
| PATCH | `/kitchen/batches/:id` | KITCHEN_* |

## Payments (server-driven)

| Method | Path | Notes |
|---|---|---|
| POST | `/payments/stripe/intent` | Returns `client_secret`. Idempotency key required. |
| POST | `/payments/stripe/webhook` | **Public**, verified by Stripe-Signature header. |
| POST | `/payments/vnpay/create` | Returns `redirectUrl`. |
| GET | `/payments/vnpay/return` | **Public**, hash-verified. Front-end redirect target. |
| POST | `/payments/vnpay/ipn` | **Public**, hash-verified. Authoritative. |
| POST | `/payments/momo/create` | Returns `payUrl` / `deeplink`. |
| POST | `/payments/momo/ipn` | **Public**, signature-verified. Authoritative. |

Webhooks are the **only** place where a payment becomes `CAPTURED`. Frontend success pages are advisory only.

## Refunds

| Method | Path | Roles |
|---|---|---|
| GET | `/refunds` | MERCHANT_*, ADMIN |
| GET | `/refunds/:id` | scope-checked |
| POST | `/refunds/:id/approve` | MERCHANT_OWNER, ADMIN |
| POST | `/refunds/:id/reject` | MERCHANT_OWNER, ADMIN |

## Analytics

| Method | Path | Roles |
|---|---|---|
| GET | `/merchant/analytics/summary?range=7d` | MERCHANT_* — `{revenue, orders, refundRate, peakHours[], bestSellers[]}` |
| GET | `/kitchen/analytics/summary?range=7d` | KITCHEN_* — `{dailyProduction, delayedOrders, efficiency, capacityUtilization}` |

## Notifications

| Method | Path | Roles |
|---|---|---|
| GET | `/me/notifications` | any auth — paginated inbox |
| POST | `/me/notifications/read` | any auth — body `{ids[]}` |
| POST | `/me/devices` | any auth — body `{fcmToken, platform}` registers FCM token |
| DELETE | `/me/devices/:fcmToken` | any auth |

## WebSocket (`/ws`)

Auth: connect with `?token=<accessToken>`. Server validates JWT, attaches `userId` + `role` + room memberships.

**Client → server**

| Event | Payload | Purpose |
|---|---|---|
| `order:subscribe` | `{orderId}` | Customer subscribes to a single order's updates. |

**Server → client**

| Event | Payload |
|---|---|
| `order.created` | `{order}` (merchant only) |
| `order.status_changed` | `{orderId, code, fromStatus, toStatus, at}` |
| `order.kitchen_status_changed` | `{orderId, code, fromStatus, toStatus, at}` |
| `kitchen.batch_updated` | `{batch}` |
| `payment.updated` | `{orderId, paymentId, status}` |
| `notification.new` | `{notification}` |

## Error codes (stable strings)

`AUTH_INVALID_CREDENTIALS`, `AUTH_TOKEN_EXPIRED`, `AUTH_FORBIDDEN`, `VALIDATION_ERROR`, `ORDER_NOT_FOUND`, `ORDER_NOT_CANCELLABLE`, `PAYMENT_FAILED`, `PAYMENT_DUPLICATE`, `COUPON_INVALID`, `COUPON_EXPIRED`, `COUPON_LIMIT_REACHED`, `STOCK_INSUFFICIENT`, `RATE_LIMITED`, `INTERNAL`.

## OpenAPI

The NestJS app exposes Swagger at `/api/docs` in non-prod environments. Flutter clients can be regenerated from `openapi.json` if desired (we'll start with handwritten DTOs to keep the surface clean).
