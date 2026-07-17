# Banan — Patisserie & Cold Cake Ordering Platform

Multi-role platform for a premium patisserie operation:

- **Customer** app (iOS / Android / Web) — browse, order, track, loyalty.
- **Merchant Store** dashboard (Web / Tablet) — menu, orders, refunds, transfer-to-kitchen.
- **Central Kitchen** dashboard (Web / Tablet) — production queue, kanban board, dispatch.

## Repository layout

```
banan/
├── apps/
│   ├── banan_customer/     # Flutter — mobile-first, also web
│   ├── banan_merchant/     # Flutter — web/tablet dashboard
│   └── banan_kitchen/      # Flutter — web/tablet kanban + ops
├── packages/
│   ├── core/               # env, result type, failures, logging, extensions
│   ├── design_system/      # tokens, theme, reusable widgets, charts, kanban
│   ├── domain/             # entities + repository interfaces (pure Dart)
│   ├── data/               # API client, WS client, DTOs, repo impls, DI
│   └── features_shared/    # auth, profile, notifications shared by all apps
├── backend/                # NestJS — REST + WebSocket + workers
│   └── prisma/             # schema, migrations
├── docs/                   # architecture, ERD, API contract, roadmap
├── melos.yaml
└── README.md
```

## Where to start

1. Read `docs/00-architecture.md` for the system overview.
2. Read `docs/01-database.md` and `backend/prisma/schema.prisma` for the data model.
3. Read `docs/02-api-contract.md` for REST + WebSocket surface.
4. Read `docs/03-flutter-structure.md` for the Clean Architecture layout.
5. Read `docs/04-packages.md` for the dependency list and rationale.
6. Read `DEPLOY.md` to ship it, and `docs/07-production-checklist.md` for what
   to settle before taking real money.

## Running

```bash
# backend
cd backend
docker compose up -d            # postgres + redis
pnpm install
pnpm prisma migrate dev
pnpm start:dev

# flutter (from repo root)
dart pub global activate melos
melos bootstrap
melos run customer:run          # or merchant:run / kitchen:run
```
