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

## Roadmap (next increments)

2. **Shop floor + QC** — work-order start/pause/done, quality points (measure /
   pass-fail) gated on operations, quality alerts. Flutter tablet kanban.
3. **Flutter "Sản xuất" section** — dashboard, BoM editor, MO screen, stock/lot
   views, wired to this API. Route-separated from the orders area.
4. **Planning** — Gantt/Kanban schedule, employee assignment, MPS.
5. **Reports + purchasing** — production/scrap/cost reports, replenishment.
6. **P2** — OEE, maintenance, activities/notifications, HSD background job.
