# Kitchen MES — "Sản xuất"

A manufacturing-execution system for the Banan bakery, living **inside** the
existing monorepo as a separate section of the kitchen app — not a second stack.

## Why it's built into Banan, not a standalone FastAPI/React app

The spec suggested "Python/FastAPI or Node/NestJS" + "React + Tailwind". Two
things make reuse the right call, not just the convenient one:

- **It's a section of the kitchen *site*.** `banan_kitchen` is a Flutter web
  app. You can't embed a React app inside it as "a part of the site", so the UI
  must be Flutter. Frontend stack is therefore decided by where it lives.
- **One person runs this.** A separate service means a second deployment, a
  second auth system, a second database, a second backup job. Banan already has
  all four — JWT + RBAC, Postgres/Prisma, the deploy pipeline, the nightly
  `pg_dump`. The MES reuses every one of them.

So: a NestJS `manufacturing` module on the existing backend + a `Sản xuất`
feature area in `banan_kitchen`, both **namespaced away from the ordering side**.
Every table is `Mfg*`; nothing touches `Product`, `Order`, or the kitchen queue.

## Status — increment 1 (backend spine) ✅

The engine, where correctness matters most, built and proven end-to-end against
a real Postgres. What's live:

| Area | Done |
| --- | --- |
| 3-tier products (raw / semi / finished / packaging) + categories | ✅ |
| UoM + conversion (g ↔ kg, piece) | ✅ |
| Multi-level BoM + baker's % (ratio) | ✅ |
| Work centers + operations | ✅ |
| MO: create → confirm → check-availability → reserve → produce → cancel | ✅ |
| Produce: generate lot (mfg/expiry), book stock, consume components, AVCO | ✅ |
| Receipt (nhập kho NVL) + AVCO roll-forward | ✅ |
| Scrap (ghi hao hụt, giảm tồn) | ✅ |
| Lot traceability (backward: finished → raw) | ✅ |
| Multi-level cost rollup (materials AVCO + operation time) | ✅ |
| RBAC (reads: kitchen roles; writes: manager/admin) | ✅ |

**Deferred to later increments** (schema is forward-compatible where it costs
nothing): quality points/checks, shop-floor tablet screens + work-order
start/pause/done, production schedule (Gantt/Kanban), MPS, OEE, maintenance,
purchase requests, reports UI, and the **entire Flutter UI**. The API exists so
the UI can be built against it.

## Architecture

- **`src/manufacturing/mfg-math.ts`** — pure arithmetic (UoM conversion, baker's
  %, AVCO, expiry). No I/O, so the money rules are unit-tested in isolation.
- **`src/manufacturing/manufacturing.service.ts`** — the engine. Every stock- or
  cost-changing operation runs in a transaction so a half-finished produce can't
  desync quants and lots.
- **`src/manufacturing/manufacturing.controller.ts`** — REST under
  `/api/v1/manufacturing/*`, RBAC per route.
- **`prisma/seed-manufacturing.ts`** — idempotent demo data (10 work centers, 4
  stock locations, one multi-level recipe).

Stock is modelled as **quants** (on-hand per product/lot/location) moved by
**stock moves**. Two well-known locations resolved by code: `STOCK` (on-hand)
and `SCRAP`. Components flow through a virtual `PRODUCTION` location on the way
into a finished good — the move pair (`STOCK→PRODUCTION` out, `PRODUCTION→STOCK`
in) is exactly what makes a lot traceable to what it consumed.

## API (all under `/api/v1/manufacturing`)

```
GET  boms/:id/cost                 cost breakdown (multi-level rollup)
GET  orders                        list MOs (?state=)
GET  orders/:id
POST orders                        create MO (draft) from a BoM
POST orders/:id/confirm            validate + generate work orders + check avail
GET  orders/:id/check-availability
POST orders/:id/reserve
POST orders/:id/produce            → lot + stock + consume + AVCO + DONE
POST orders/:id/cancel
POST receipts                      nhập kho NVL (+ AVCO)
POST scraps                        ghi hao hụt
GET  stock/on-hand?productId=
GET  lots/expiring?before=         HSD warning feed
GET  traceability/lot/:id
```

## Business rules implemented

- **Ratio %** = component weight / basis weight × 100; basis = the flagged flour
  line, else total. Stored on the BoM line.
- **Confirm** refuses a BoM with no components (a cake with no ingredients is a
  data error, not a plan).
- **Check availability** compares on-hand − reserved against need and sets an
  Available / Not-available badge, but never blocks — advisory, matching the
  observed "warn but continue".
- **Reservations are advisory by design.** `reserve` is a soft hold: it never
  overbooks a quant (a guarded update re-checks `quantity − reservedQty ≥ take`
  in SQL, so two concurrent reserves can't both grab the same stock), but the
  hold is *not owned per-MO* — `reservedQty` is a running total on the quant, not
  an allocation. Real on-hand is never at risk from this: `produce` consumes real
  FIFO stock and backflushes any shortfall, and `produce` itself is guarded by an
  atomic state claim so a batch is consumed/booked exactly once. Making holds
  *hard* (a per-MO allocation ledger so cancel/produce only touch their own
  reservation) is a deliberate future increment, not an accident — deferred
  because at single-site bakery concurrency the advisory hold is enough.
- **Produce** generates the finished lot (mfg = today, expiry = today +
  `expirationDays`), books it into stock, consumes the **full** BoM FIFO by
  expiry (backflushing any shortfall so cost/qty stay whole), rolls the finished
  product's AVCO forward, and snapshots `totalCost` = materials + operations. It
  makes the whole planned quantity — partial-yield production was removed rather
  than left half-wired. Every stock write is an **atomic increment** (Postgres
  row-locks the update) so concurrent moves can't lose each other's changes.
- **QC is enforced on both close paths.** Whether an operation is closed from the
  shop floor (`doneWO`) or the order is closed directly (`produce`), the same
  gate runs: every active quality point on the operation must have a latest PASS
  check. So finished stock can't be booked with QC skipped or failed, no matter
  which button ends the batch.
- **Cost** = Σ(component base-qty × AVCO, recursing into semi BoMs) +
  Σ(operation minutes / 60 × work-center cost/hour). Unit costs keep 2 decimals
  so a semi at 180.25đ/g doesn't shed a quarter đồng per gram up the tree; only
  order totals round to a whole đồng.
- **Traceability** walks the finished lot's producing move → its MO → the
  component moves that left stock → recursing for any consumed semi lot.

## Running it

Schema + migration are already in `prisma/`. On a fresh DB the migration applies
on boot (`prisma migrate deploy`), same as the rest of Banan.

```bash
# Seed the demo master data (idempotent).
cd backend && npx ts-node prisma/seed-manufacturing.ts
```

## Tests

```bash
# Unit (no DB) — pure math: ratio %, UoM conversion, AVCO, expiry.
npx jest mfg-math

# Integration (real Postgres) — the golden path, every number hand-checked:
# receive → produce semi → produce finished (multi-level) → scrap → trace.
MFG_IT=1 DATABASE_URL=postgresql://... npx jest manufacturing.integration
```

The integration spec is gated on `MFG_IT` so the default `npx jest` stays green
without a database. It proves acceptance criteria 1, 3, 4, 5, 6, 7:
- a multi-level BoM with ratio % → an MO from it
- produce → lot with correct mfg/expiry, stock updated
- availability reflects real stock
- scrap reduces stock and is recorded
- a finished lot traces back to its raw lots
- MO cost = materials + operations, matching a hand calc to the đồng

## Increment 2 — Flutter "Sản xuất" section ✅

A route-separated area in `banan_kitchen` (`/production/*`, reached from a
factory icon on the orders board — never mixed with the Kanban):

- **Dashboard** — MO counts by state, near-expiry lots, links to orders/stock.
- **MO list** — filterable by state; "Tạo lệnh" picks a BoM + quantity.
- **MO detail** — status, components with Đủ hàng / Thiếu badges, and the
  state-driven actions (Xác nhận → Kiểm tra tồn / Giữ hàng / Sản xuất → Huỷ).
  Produce shows the resulting lot, output and cost. Write actions are gated to
  kitchen managers; staff see a read-only card.
- **Stock** — on-hand at the kitchen location + near-expiry lots.

Data layer: `ManufacturingApi` in `packages/data` (DTOs + Result/isOk guards),
`manufacturingApiProvider`. Backend gained the read endpoints the UI needs
(`GET products / boms / boms/:id / work-centers / dashboard/mo-counts`).

Kitchen web build compiles; the API is proven by the integration test. The UI
wiring itself still wants a click-through on a running stack.

## Increment 3 — Shop floor + QC ✅

- **Work-order execution**: `POST work-orders/:id/{start,pause,done}` with real
  duration banked (start marks the run, pause/done add elapsed minutes). That
  real time flows into the produce cost. Each transition is a **guarded UPDATE**
  that re-checks the work order's state under the row lock and increments
  `durationReal` from the row's own `dateStart` in SQL — so two people closing or
  pausing the same operation at once can't lose banked time or stomp each other's
  state (the close applies exactly once).
- **Quality points** on operations (`MEASURE` with a norm range, or `PASS_FAIL`),
  and **checks** — for a MEASURE point the verdict is computed server-side (PASS
  only inside `[normMin, normMax]`), so a tablet just sends the number.
- **Gating**: `done` is refused until every active quality point on the
  operation has a *latest* PASS check — a re-measure supersedes an earlier fail,
  so a corrected batch isn't blocked forever. A FAIL opens a **quality alert**.
- Flutter **Xưởng sản xuất** screen (tablet-first): work orders as columns per
  work center, Bắt đầu / Tạm dừng / Hoàn tất, and inline QC entry (temperature
  or Đạt/Không đạt). Any kitchen role runs it; QC-point authoring is manager-only.

Proven by an integration case: gate blocks with no check, a 50°C reading fails
and opens an alert, a re-measured 38°C passes and the WO finishes. Backend
suite 158 pass / 7 skip; integration 7/7 on real Postgres; kitchen web builds.

## Increment 4 — Planning (schedule + assignment) ✅

The master production schedule as a **day-column Kanban**, reusing fields that
already existed on the MO (`scheduledDate`, `responsibleId`) — no migration.

- **Schedule board** (`/production/schedule`): a backlog column of unscheduled
  MOs plus one column per day for the coming week (and any day already booked,
  including overdue). Cards show code, product, qty, state and assignee.
- **Plan a run**: tap a card (manager only) to set/clear its production day and
  pick the responsible person. Nulls clear the field.
- **Employee assignment**: `responsibleId` is a *soft* link — a plain user id,
  so the manufacturing side stays namespaced off `User` (no FK, no back-relation
  on the ordering model). Names are batch-resolved in the `schedule` feed, not by
  a join. `GET manufacturing/staff` lists assignable kitchen users.

New API: `GET manufacturing/schedule`, `GET manufacturing/staff`,
`POST manufacturing/orders/:id/plan`. A finished/cancelled MO can't be
rescheduled, and the responsible must be an *active kitchen user* (the same set
`staff` offers). The scheduled day is anchored to UTC midnight on the way out so
it round-trips to the same calendar day whatever timezone the backend runs in.
Proven by an integration case (assign → resolve name → clear to backlog → refuse
a DONE MO → refuse a non-kitchen assignee); integration 8/8 on real Postgres.

**MPS scope:** the schedule board *is* the master production schedule surface —
what to make, when, by whom. Demand-netting (planning against sales
orders/forecast) is deliberately out of scope for a one-person, separate
section. A pixel-timeline Gantt is skipped in favour of day columns — the right
grain for a bakery. Add either if a real need shows up.

## Increment 5 — Reports + replenishment ✅

Read-only reporting over what the engine already records — no migration, all
sourced from the existing `Mfg*` tables.

- **Production report** (`GET reports/production?from&to`) — finished (DONE) MOs
  grouped by product, with qty and cost from the produce-time snapshot
  (`qtyProduced`, `totalCost`). Qty is deliberately not totalled across products
  (mixed UoM — grams vs pieces); only đồng and MO count are.
- **Cost report** (`GET reports/cost?from&to`) — per DONE MO, the actual
  material-vs-operation split. Materials are summed from the MO's consume moves
  (`refType MO` booked into the `PRODUCTION` location) at their **frozen** unit
  cost; operations are the remainder of the `totalCost` snapshot, so the split
  reconstructs the total exactly with no rounding drift.
- **Scrap report** (`GET reports/scrap?from&to`) — scrap valued at the unit cost
  **frozen on the paired `SCRAP` move** (the AVCO snapshot at scrap time, not the
  live `avgCost` which drifts on later receipts). Grouped by reason (value only —
  qty is mixed-UoM) and by product (qty + value).
- **Replenishment** (`GET replenishment`) — an advisory buy list: for each
  purchased item (`RAW`/`PACKAGING`), `shortfall = open-MO demand
  (qtyToConsume − qtyConsumed over DRAFT/CONFIRMED/PROGRESS) − gross on-hand
  (quantity at STOCK)`. On-hand is **gross**, not free — a reserved quant is
  still physically in stock and earmarked for one of the very open MOs whose full
  need is already in `demand`, so subtracting `reservedQty` would double-count the
  reservation and recommend re-buying stock you already hold. It recommends what
  to buy and roughly what it costs; it **creates nothing** — the actual purchase
  orders are placed in Odoo (the system of record for procurement). A full
  purchase-request lifecycle in the MES was deliberately skipped rather than
  duplicate Odoo.

Report date windows (`from`/`to`) are anchored to **VN local** calendar days
(fixed ICT, UTC+7), not UTC, so a batch made at 06:00 local lands in the right
day; an unparseable date returns 400, not a 500.

Flutter: a **Báo cáo sản xuất** screen (`/production/reports`) with 3 tabs
(Sản xuất / Giá thành / Hao hụt) and quick date-range presets (7 / 30 ngày /
Tất cả), and a **Gợi ý mua hàng** screen (`/production/replenishment`). Both are
read-only, reached from the production dashboard. Integration 21/21 on real
Postgres (the report figures hand-checked: sponge split 37750/142500 = 180250,
scrap 200 × 209.15 = 41830 from the frozen move cost); kitchen web build OK.

## Increment 6 — Notifications + HSD background job ✅

Reuses the existing app-wide notification stack (`Notification` model,
`NotificationsService`, realtime gateway, FCM push) — no new notification model.
A `ManufacturingSchedulerService` (`@nestjs/schedule`) runs two jobs, both routed
to every active kitchen-role user via `notifyKitchenRoles`:

- **Daily digest** (07:00 ICT) — counts lots at/near expiry that still hold stock
  + MOs planned before today and still open; if either is non-zero, pushes one
  "Nhắc việc sản xuất" notification.
- **QC-alert sweep** (every 10 min) — one urgent "Cảnh báo QC" per new
  `MfgQualityAlert`, then stamps a new `notifiedAt` column so each fires exactly
  once (the only schema change — a nullable dedup timestamp; migration
  `mfg_alert_notified_at`).

Flutter: a kitchen **Thông báo** inbox (`/notifications`, bell + unread badge on
the production dashboard) reusing the shared `NotificationsRepository` + realtime
feed; a QC-alert tap deep-links to its MO. Integration 25/25 (sweep notifies once
then stamps; digest fires on an overdue MO); kitchen web build OK.

## Roadmap (next increments)

7. **OEE + maintenance** — equipment effectiveness + maintenance schedules/orders.
8. **Hard reservations** (if needed) — a per-MO allocation ledger so
   cancel/produce only touch their own hold (today reservations are advisory).

Also deferred UI: BoM editor (create/edit recipes — today recipes come from the
seed or the API), scrap form, receipt form, quality-alerts screen.
