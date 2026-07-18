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
- **Produce** generates the finished lot (mfg = today, expiry = today +
  `expirationDays`), books it into stock, consumes components FIFO by expiry
  (backflushing any shortfall so cost/qty stay whole), rolls the finished
  product's AVCO forward, and snapshots `totalCost` = materials + operations.
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
  real time flows into the produce cost.
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
rescheduled. Proven by an integration case (assign → resolve name → clear to
backlog → refuse a DONE MO); integration 8/8 on real Postgres.

**MPS scope:** the schedule board *is* the master production schedule surface —
what to make, when, by whom. Demand-netting (planning against sales
orders/forecast) is deliberately out of scope for a one-person, separate
section. A pixel-timeline Gantt is skipped in favour of day columns — the right
grain for a bakery. Add either if a real need shows up.

## Roadmap (next increments)

5. **Reports + purchasing** — production/scrap/cost reports, replenishment.
6. **P2** — OEE, maintenance, activities/notifications, HSD background job.

Also deferred UI: BoM editor (create/edit recipes — today recipes come from the
seed or the API), scrap form, receipt form, quality-alerts screen.
