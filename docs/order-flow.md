# Banan order lifecycle — three flows

Every order moves through four roles: **Customer → Merchant → (Kitchen?) → Customer**.
The merchant decides where the cake is made the moment they accept the order,
and the customer sees a live tracker that adapts to that decision.

The three scenarios below cover everything the system supports today.

---

## Flow A — Prepare at counter (in-house)

Used for: small orders, store specials, anything the front-of-house team can
handle on the same equipment without sending to the central kitchen.

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Customer │     │ Merchant │     │ Counter  │     │ Customer │
│  places  │ ──▶ │  accepts │ ──▶ │ prepares │ ──▶ │  picks   │
│   order  │     │          │     │          │     │ up / del │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

| Step | Actor | UI action | Order status | What the customer sees |
|------|-------|-----------|--------------|-----------------------|
| 1 | Customer | Add to cart → Checkout → "Place order" (cash or VNPay) | `PENDING` | "Placed · Awaiting confirmation" |
| 2 | Merchant | Order list → tap order → **Accept** | `ACCEPTED` | "Accepted" — store is on it |
| 3 | Merchant | Order detail → **Prepare at counter** button | `IN_PREPARATION` | 🏬 Banner: *"Being prepared at the counter"* + progress tracker step "Counter" lights up |
| 4 | Counter staff | (Off-app — physically baking/decorating) | `IN_PREPARATION` | Unchanged; customer just waits |
| 5 | Merchant | Order detail → **Ready for pickup** (pickup) **or** **Out for delivery** (delivery) | `READY_FOR_PICKUP` / `DELIVERING` | "Ready" 🥡 or "On the way" 🛵 ; banner disappears |
| 6 | Merchant | When customer arrives / driver returns → **Mark completed** | `COMPLETED` | "Completed" + loyalty points credited |

**Failure paths from any pre-complete state:** Merchant can **Cancel** (refund
auto-issued for prepaid orders via the existing refund flow).

---

## Flow B — Kitchen prepares (central kitchen)

Used for: complex cakes, large quantities, anything a different team handles
in a separate location. The merchant offloads production to the kitchen and
the kitchen runs its own kanban.

```
┌──────────┐   ┌──────────┐   ┌────────────────────────────────┐   ┌──────────┐   ┌──────────┐
│ Customer │   │ Merchant │   │      Central kitchen           │   │ Merchant │   │ Customer │
│  places  │──▶│ accepts +│──▶│ Pending → Preparing → Ready    │──▶│  hands   │──▶│  picks   │
│   order  │   │ sends to │   │           ↓                    │   │   off    │   │ up / del │
│          │   │  kitchen │   │       dispatches back          │   │          │   │          │
└──────────┘   └──────────┘   └────────────────────────────────┘   └──────────┘   └──────────┘
```

| Step | Actor | UI action | `status` | `kitchenStatus` | What the customer sees |
|------|-------|-----------|----------|-----------------|-----------------------|
| 1 | Customer | Checkout → place order | `PENDING` | – | "Placed" |
| 2 | Merchant | Accept | `ACCEPTED` | – | "Accepted" |
| 3 | Merchant | **Send to kitchen** button | `SENT_TO_KITCHEN` | `PENDING_ACK` | 🏭 Banner: *"Being prepared in our kitchen — Waiting for the kitchen team to start"* + tracker step "Kitchen" lights up + sub-badge `Kitchen · Pending` |
| 4 | Kitchen | Kanban → **Pending** column → **Accept & start** | `SENT_TO_KITCHEN` | `PREPARING` | Banner: *"Our bakers are crafting your order right now"* + badge `Kitchen · Preparing` |
| 5 | Kitchen | (Bakes / decorates — off-app) | unchanged | `PREPARING` | Unchanged |
| 6 | Kitchen | **Mark ready** | `SENT_TO_KITCHEN` | `READY_DISPATCH` | Banner: *"Ready and on its way back to the store"* + badge `Kitchen · Ready` |
| 7 | Kitchen | **Dispatch** (returns control to merchant) | `READY_FOR_PICKUP` *or* `DELIVERING` | preserved | "Ready" 🥡 / "On the way" 🛵 ; banner disappears; tracker advances |
| 8 | Merchant | Customer arrives / driver returns → **Mark completed** | `COMPLETED` | preserved (for kitchen analytics) | "Completed" |

The kitchen card also lands in **"Completed today"** column on the kitchen
kanban after dispatch, so kitchen staff see the running tally without
leaving the board.

**Realtime events** push at every transition: customer's tracker, kitchen's
kanban, and merchant's order list all update without polling. The events are:
`order.created`, `order.status_changed`, `order.kitchen_status_changed`.

---

## Flow C — Scheduled order (pre-order for future date)

Used for: birthday cakes ordered a week ahead, wedding cakes, event catering.
The customer locks in a specific delivery/pickup date during checkout, pays
upfront, and the merchant queues the order until production should start.

⚠️ **Status: data model + API are wired, but two UI pieces are still missing.**
Listed at the end of this section.

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ Customer │   │  System  │   │ Merchant │   │  Counter │   │ Customer │
│  places  │──▶│  parks   │──▶│ accepts  │──▶│    or    │──▶│  picks   │
│   order  │   │  until   │   │ when     │   │  Kitchen │   │  up at   │
│ "for…"   │   │  T-2hr   │   │ T-2hr    │   │          │   │ schedDate│
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

| Step | Actor | UI action | Order status | What the customer sees |
|------|-------|-----------|--------------|-----------------------|
| 1 | Customer | Checkout → picks **"Schedule for later"** → date/time picker (e.g. *May 18, 3pm*) → places order with payment | `PENDING` with `scheduledFor` set | "Scheduled for May 18, 3:00 PM" + tracker shows "Placed" with a 📅 indicator |
| 2 | System | Order parked — no merchant alert yet (it's not due) | `PENDING` | "Scheduled for May 18 · We'll start ~2 hr before pickup" |
| 3 | System | At `scheduledFor - 2 hours`, scheduled job promotes the order to merchant's "Active" queue *(needs implementation — see below)* | `PENDING` | Unchanged until merchant accepts |
| 4 | Merchant | Active queue → **Accept** | `ACCEPTED` | "Accepted — see you May 18 at 3 PM" |
| 5 | Merchant | Choose **Prepare at counter** *or* **Send to kitchen** (Flow A or B from here) | `IN_PREPARATION` / `SENT_TO_KITCHEN` | Department banner appears |
| 6 | Counter / Kitchen | Same as Flow A or B steps 4–6 | … | … |
| 7 | Merchant | **Mark completed** when customer collects or driver returns | `COMPLETED` | "Completed" |

### What still needs to be built for Flow C

| Piece | Where | Effort |
|-------|-------|--------|
| **Customer-side date/time picker** in checkout | `apps/banan_customer/lib/features/checkout/checkout_screen.dart` — add a "Schedule for later" toggle that opens a `showDatePicker` + `showTimePicker` and sets `scheduledFor` on the order draft | ~1 hr |
| **Scheduled-order display** on customer order detail | Show the `scheduledFor` prominently with a 📅 icon and a friendly relative-time format ("Tomorrow at 3 PM") | ~30 min |
| **Merchant scheduled queue** | Separate tab/filter in merchant orders screen for `scheduledFor != null AND scheduledFor > now`. Merchant can preview but accept is held until the auto-promotion threshold | ~1 hr |
| **Auto-promotion cron job** | Backend `@nestjs/schedule` task that runs every 5 min — for each scheduled order where `now >= scheduledFor - leadTime`, emit a `order.due_soon` realtime event so the merchant tab buzzes | ~1 hr |
| **Lead-time setting per store** | New column `Store.preparationLeadMinutes` (default 120). Merchant sets this in store settings; the cron uses it | ~30 min |

Total to make Flow C fully working: ~4 hours of focused work. **Want me to ship it?**

---

## Common shared mechanics across all 3 flows

### Realtime updates
All three flows are pushed live over WebSocket. The customer never needs to
refresh. The events use rooms keyed by `order:{id}`, `user:{customerId}`,
`store:{storeId}`, `kitchen:{kitchenId}` — so only the right people get
notified.

### Payment timing
- **Cash on pickup:** Payment is `INITIATED` at checkout, transitions to `CAPTURED` when the merchant marks completed.
- **VNPay:** Customer pays immediately at checkout; if VNPay's IPN confirms, payment is `CAPTURED` before the order even leaves PENDING. Refunds flow through the refunds module on cancel.

### Cancellation rules
- **Customer** can cancel only in `PENDING` or `ACCEPTED`.
- **Merchant** can cancel up to (and including) `DELIVERING` / `READY_FOR_PICKUP`.
- **Kitchen** cannot cancel — they dispatch back to merchant, who decides.
- Cancellation in any paid state auto-creates a refund request.

### Loyalty & notifications
- Loyalty points are credited on `COMPLETED` based on order total.
- Each status transition pushes a notification to the customer's inbox (the bell icon in the customer app).
- Each new order pushes a notification to merchant staff.

---

## State machines at a glance

```text
OrderStatus  PENDING ──▶ ACCEPTED ──┬──▶ IN_PREPARATION ───────┐
                │                   │                          │
                │                   └──▶ SENT_TO_KITCHEN ─┐    │
                │                                         │    │
                ▼                   ┌─────────────────────┴────┴─▶ READY_FOR_PICKUP ──▶ COMPLETED
            CANCELLED               │                              DELIVERING       ──▶ COMPLETED
                                    │
                                    └──▶ CANCELLED  (from any pre-COMPLETED state)

KitchenStatus  PENDING_ACK ──▶ PREPARING ──▶ READY_DISPATCH
                                                  │
                                                  ▼
                                          (dispatch back to merchant —
                                           OrderStatus flips out of
                                           SENT_TO_KITCHEN)
```
