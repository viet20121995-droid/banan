# Banan Backend

NestJS HTTP + WebSocket API for the Banan platform.

## Prerequisites

- Node.js 20+
- pnpm 9+ (or use `corepack enable` to get it)
- Docker Desktop (for Postgres + Redis)

## First-time setup

```bash
cd backend
cp .env.example .env
docker compose up -d            # postgres + redis
pnpm install
pnpm prisma:generate
pnpm prisma:migrate              # creates the dev DB
pnpm prisma:seed                 # populates demo data
pnpm start:dev
```

Open:

- API: http://localhost:3000/api/v1/health
- Swagger: http://localhost:3000/api/docs
- Prisma Studio: `pnpm prisma:studio`

## Demo accounts (after seed)

All passwords: `banan123`

- `admin@banan.local` (ADMIN)
- `merchant@banan.local` (MERCHANT_OWNER, Banan Saigon)
- `kitchen@banan.local` (KITCHEN_MANAGER, Banan Central Kitchen)
- `customer@banan.local` (CUSTOMER, Gold tier)

## Roadmap

The backend module structure grows with the milestones in `../docs/05-roadmap.md`.
M0 ships health check + Prisma plumbing only. M1 adds auth.
