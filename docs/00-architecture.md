# 00 — System Architecture

## High-level diagram

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Customer App    │  │  Merchant App    │  │  Kitchen App     │
│ Flutter          │  │ Flutter (Web)    │  │ Flutter (Web)    │
│ iOS/Android/Web  │  │ + Tablet         │  │ + Tablet         │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │ REST + Socket.IO + FCM                    │
         └────────────────────┬──────────────────────┘
                              │
                       ┌──────▼──────┐
                       │  API Gateway │  (NestJS HTTP + WS)
                       │  JWT auth    │
                       └──────┬──────┘
                              │
        ┌──────────┬──────────┼──────────┬──────────────┐
        │          │          │          │              │
   ┌────▼────┐ ┌──▼──┐  ┌────▼─────┐ ┌──▼──┐     ┌─────▼─────┐
   │Postgres │ │Redis│  │  S3/R2   │ │ FCM │     │ Payments  │
   │ Prisma  │ │queue│  │  (images)│ │push │     │ Stripe /  │
   │         │ │cache│  │          │ │     │     │ VNPay /   │
   └─────────┘ └─────┘  └──────────┘ └─────┘     │ MoMo      │
                                                  └───────────┘
```

## Why these choices

| Concern | Choice | Why |
|---|---|---|
| Backend | **NestJS (TS)** | Modular, DI built in, first-class WebSocket + Swagger + guards. |
| DB | **PostgreSQL + Prisma** | Orders/refunds/loyalty are deeply relational and need transactions; Firestore can't model this cleanly. |
| Auth | **JWT (access + refresh)** with role claims | Works across mobile + web + dashboards; we still issue FCM tokens server-side for push. |
| Realtime | **Socket.IO** rooms (`order:{id}`, `store:{id}`, `kitchen:{id}`) | Reuses HTTP infra; survives reconnects; per-room broadcast keeps payloads small. |
| Queue / cache | **Redis + BullMQ** | Scheduled-order release, payment retries, batch production planning, pub/sub fan-out. |
| File storage | **S3-compatible** (R2 / S3) | Pre-signed uploads from clients, CDN-friendly. |
| Push | **FCM** | Cross-platform; single SDK on Flutter. |

## Clean Architecture (per Flutter app)

```
feature/
├── domain/              # pure Dart — Entity, Repository (abstract), UseCase
├── data/                # DTO, Mapper, Repository impl, datasources
└── presentation/        # widgets, screens, controllers (Riverpod)
```

**Dependency direction:** `presentation → domain ← data`. Presentation depends only on `domain`. The DI layer (in `packages/data`) wires concrete implementations to the abstract repository interfaces.

## Authentication flow

```
Client                              API
  │  POST /auth/register             │
  │  ───────────────────────────────►│
  │                                  │ bcrypt(password), insert User
  │  { accessToken, refreshToken }   │
  │  ◄───────────────────────────────│
  │                                  │
  │  Authorization: Bearer <access>  │
  │  any protected request          │
  │  ───────────────────────────────►│ JwtAuthGuard + RolesGuard
  │                                  │
  │  401 (access expired)            │
  │  POST /auth/refresh { refresh }  │
  │  ───────────────────────────────►│ verify, rotate refresh
  │  { accessToken, refreshToken }   │
  │  ◄───────────────────────────────│
```

- **Access token** lifetime 15 min; **refresh token** 30 days, rotated on use, revocable per device.
- Refresh tokens stored in `RefreshToken` table with `deviceId`, `userAgent`, `revokedAt`.
- Flutter side: `flutter_secure_storage` (Keychain / Keystore) for tokens; Dio interceptor auto-refreshes on 401.

## Realtime model

Each connected client joins rooms based on their role:

| Role | Rooms joined |
|---|---|
| Customer | `user:{userId}`, `order:{orderId}` (per-active order) |
| Merchant | `store:{storeId}` |
| Kitchen | `kitchen:{kitchenId}` |

Server emits a small set of events:

| Event | Payload | Receivers |
|---|---|---|
| `order.created` | `{orderId, storeId, summary}` | `store:{storeId}` |
| `order.status_changed` | `{orderId, fromStatus, toStatus, at}` | `order:{orderId}`, `user:{userId}`, `store:{storeId}`, `kitchen:{kitchenId}?` |
| `order.kitchen_status_changed` | `{orderId, fromStatus, toStatus, at}` | `kitchen:{kitchenId}`, `store:{storeId}`, `user:{userId}` |
| `kitchen.batch_updated` | `{batchId, status, actualQty}` | `kitchen:{kitchenId}` |
| `payment.updated` | `{orderId, paymentId, status}` | `user:{userId}`, `store:{storeId}` |

Client also reads HTTP for the canonical state — WebSocket is **delta**, not source of truth.

## Responsive breakpoints

| Breakpoint | Width | Primary target |
|---|---|---|
| `xs` | < 600 | Phone (customer) |
| `sm` | 600–904 | Large phone / small tablet |
| `md` | 905–1239 | Tablet (merchant/kitchen) |
| `lg` | 1240–1439 | Laptop |
| `xl` | ≥ 1440 | Desktop dashboards |

`design_system/responsive` exposes a `BreakpointBuilder` and `context.bp` extension. Customer app composes single-column phone layouts, dashboards switch to multi-pane at `md+`.

## Observability

- **Backend:** `pino` JSON logs + request ID middleware; OpenTelemetry traces; `/health` via `@nestjs/terminus`.
- **Flutter:** `package:logging` piped to console + Sentry (optional) in release.
- **Audit:** `OrderStatusEvent` table is the immutable timeline for every order (legal/refund evidence).

## Security checklist (enforced in code, not just docs)

- All payment webhooks verify HMAC signature (Stripe, VNPay, MoMo) before doing any work.
- All state-changing endpoints behind `JwtAuthGuard` + `RolesGuard`.
- Multi-tenant isolation: every merchant/kitchen query is scoped by `storeId` / `kitchenId` from the JWT, never from the request body.
- Rate limit: `@nestjs/throttler` on `/auth/*`, `/payments/*/webhook`, `/orders` POST.
- No raw card data ever touches the server — Stripe.js / VNPay redirect / MoMo redirect.
