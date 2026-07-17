# Production checklist

How to *deploy* is [DEPLOY.md](../DEPLOY.md). This is what to settle around it —
the things that bite once real money and real customers are involved.

This file points at where the truth lives rather than restating it. Read the
values out of the source; a number copied into a doc goes stale silently.

---

## 1. Backups

Postgres is a container on a single VPS with its data in the `pgdata` Docker
volume (`docker-compose.prod.yml`) — no replica, no failover. Backups are the
only thing standing between a dead box and every order, customer and loyalty
balance. Nothing else on this list matters as much.

`infra/backup-db.sh` dumps, verifies the archive is readable, and prunes; it
refuses to prune when the dump failed, so a broken run can't quietly age out
the good copies. `infra/restore-db.sh` does the drill and the real recovery.

```bash
# On the VPS — daily at 03:00.
crontab -e
0 3 * * * bash /opt/banan/infra/backup-db.sh >> /opt/banan/backups/backup.log 2>&1
```

- [ ] Cron installed, and `backups/backup.log` actually shows daily `ok:` lines
      a week later. A backup job nobody watches is one that stopped in March.
- [ ] **`BACKUP_REMOTE` set** so dumps land off the box. Until then the backup
      dies with the server it was protecting against — this is the one step
      that makes the rest worth anything.
- [ ] **Run the drill:** `bash infra/restore-db.sh --verify <dump>` and check
      the row counts look like production. A dump nobody has restored is a
      hope, not a backup. Repeat monthly.
- [ ] Say out loud how much data you accept losing, and set the cadence from
      that answer rather than from what's convenient.
- [ ] Know that `--into-prod` exists and what it costs, *before* the night you
      need it.

## 2. Migration drift

Migrations run automatically on boot (`prisma migrate deploy`) — which is
exactly why drift hurts: a bad one fails *while the backend starts*, so it
surfaces as a container that won't come up, with the site down.

```bash
npx prisma migrate diff \
  --from-url "$DATABASE_URL" --to-schema-datamodel prisma/schema.prisma
```

- [ ] Diff prod against `schema.prisma` before deploying a schema change.
- [ ] Dump first (§1) before any migration that drops or rewrites a column.
- [ ] Watch `logs --tail=50 backend` through the restart instead of assuming.

## 3. Secrets and access

- [ ] **Rotate anything pasted into a chat, ticket, or email** — 9Pay secret +
      checksum keys, dashboard passwords. Rotation is what undoes an exposure;
      deleting the message is not.
- [ ] 2FA on the 9Pay merchant dashboard.
- [ ] `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`: long, random, prod-only.
- [ ] `CORS_ORIGINS` lists prod hosts only (`infra/.env.prod.example`).
- [ ] Swagger stays off in prod (`main.ts` gates on `NODE_ENV`).
- [ ] Postgres user isn't a superuser, and its port isn't published to the
      internet (`docker-compose.prod.yml`).
- [ ] SSH key-only; root login and password auth disabled.
- [ ] `ufw` default-deny inbound, only 22/80/443 open.
- [ ] `fail2ban` + `unattended-upgrades` installed.

## 4. Money constants — confirm with a human

These decide what customers pay and earn. They live in code, not config, and
ship wrong quietly because nothing fails loudly.

- [ ] Loyalty earn rate, redemption value, tier thresholds —
      `backend/src/loyalty/loyalty.service.ts`.
- [ ] The points-to-đồng rate at checkout (`_vndPerPoint` in
      `checkout_screen.dart`) **agrees with the backend's**. The backend is
      authoritative, so a mismatch shows one discount and charges another.
- [ ] Delivery fee tiers + free-delivery threshold — admin `DeliveryConfig`.
- [ ] Per-user and total coupon limits are enforced for the coupons you intend
      to publish — `backend/src/coupons/coupons.service.ts`.

## 5. Payments

- [ ] `NINEPAY_ENDPOINT` is `https://payment.9pay.vn`, not the sandbox.
- [ ] The production merchant key is in place — it differs from sandbox.
- [ ] 9Pay has registered the IPN + return URLs (listed in DEPLOY.md).
- [ ] One real end-to-end payment, then confirm the order flipped to paid.
- [ ] COD stays off unless you mean it: with `COD_ENABLED` unset the API
      rejects `paymentMethod=CASH` and checkout offers 9Pay only.

## 6. Operational hygiene

- [ ] Docker log rotation — logs fill the disk otherwise, and a full disk takes
      Postgres down with it:

```
# /etc/logrotate.d/docker-banan
/var/lib/docker/containers/*/*.log {
  daily
  rotate 7
  size 100M
  copytruncate
  missingok
  compress
}
```

- [ ] Uptime check on `https://api.banancakes.vn/api/v1/health` that reaches a
      human when it fails.
- [ ] Disk-space alert — this box holds Postgres, uploads, and Docker logs.
- [ ] Know how to read `docker compose ... logs backend` before you need to.

## 7. Known limitations — accepted, not bugs

- **Realtime is single-instance.** Rooms live in the backend process's memory,
  so a second replica would deliver to only its own clients, silently. Scaling
  out needs `@socket.io/redis-adapter` first (see `realtime.gateway.ts`).
- **Uploads are on local disk** (`/uploads`, Docker volume). Fine for one box;
  `uploads.service.ts` is shaped for S3/R2 when it isn't.
- **One box, no failover.** Everything here assumes that's an accepted
  trade-off — §1 is what makes it survivable.
