#!/bin/bash
# Restore a dump produced by backup-db.sh. Runs ON THE VPS.
#
#   bash infra/restore-db.sh --verify /opt/banan/backups/banan-2026-07-17-0300.dump
#       Restores into a scratch database, prints row counts, drops it.
#       Touches nothing real. This is the drill — run it monthly.
#
#   bash infra/restore-db.sh --into-prod /opt/banan/backups/banan-....dump
#       DESTRUCTIVE. Replaces the live database. Only for a real recovery.
#
# Env: CONTAINER (default banan-postgres-1)
set -euo pipefail

CONTAINER=${CONTAINER:-banan-postgres-1}
SCRATCH_DB=banan_restore_check

mode=${1:-}
dump=${2:-}

usage() {
  echo "usage: $0 --verify|--into-prod <dump-file>" >&2
  exit 2
}
[ -n "$mode" ] && [ -n "$dump" ] || usage
[ -f "$dump" ] || { echo "no such dump: $dump" >&2; exit 1; }

log() { echo "[$(date +'%F %T')] $*"; }

# Tables worth eyeballing after a restore: if these are empty or wildly short,
# the dump is not what you think it is. The SQL goes in on stdin rather than
# `-c`, so the double quotes Prisma's table names need survive the trip through
# `docker exec sh -c` instead of being eaten by the shell (unquoted, "Order" is
# a reserved word and the query dies).
counts_sql() {
  docker exec -i "$CONTAINER" sh -c \
    "psql -U \"\$POSTGRES_USER\" -d $SCRATCH_DB" <<'SQL'
select 'User' as tbl, count(*) from "User"
union all select 'Order', count(*) from "Order"
union all select 'Product', count(*) from "Product"
union all select 'Payment', count(*) from "Payment";
SQL
}

case "$mode" in
  --verify)
    log "restoring into scratch db $SCRATCH_DB (nothing real is touched)"
    # Drop a leftover scratch db from an interrupted earlier run.
    docker exec "$CONTAINER" sh -c \
      "dropdb -U \"\$POSTGRES_USER\" --if-exists $SCRATCH_DB"
    docker exec "$CONTAINER" sh -c \
      "createdb -U \"\$POSTGRES_USER\" $SCRATCH_DB"
    # --single-transaction: all-or-nothing, so a half-restored scratch db can
    # never be mistaken for a good one. --no-owner/--no-privileges drop the
    # role errors that would otherwise be the only "benign" failures here, so
    # any non-zero exit now means the dump really is unusable — the whole point
    # of the drill is to find that out here rather than during a recovery.
    status=0
    docker exec -i "$CONTAINER" sh -c \
      "pg_restore -U \"\$POSTGRES_USER\" -d $SCRATCH_DB \
         --single-transaction --exit-on-error --no-owner --no-privileges" \
      < "$dump" || status=$?

    if [ "$status" -eq 0 ]; then
      log "row counts in the restored copy:"
      counts_sql
    else
      # The transaction rolled back, so the scratch db is empty — counting rows
      # would only print zeroes and muddy the verdict.
      log "FAILED: pg_restore exited $status. This dump is NOT a usable backup."
    fi

    docker exec "$CONTAINER" sh -c \
      "dropdb -U \"\$POSTGRES_USER\" --if-exists $SCRATCH_DB"
    log "scratch db dropped."
    [ "$status" -eq 0 ] && \
      log "If those numbers look like production, the dump is good."
    exit "$status"
    ;;

  --into-prod)
    echo
    echo "  This REPLACES the live database with $dump."
    echo "  Everything written since that dump — orders, customers, payments — is gone."
    echo "  Stop the backend first so it cannot write mid-restore:"
    echo "    docker compose --env-file infra/.env.prod -f docker-compose.prod.yml stop backend"
    echo
    read -r -p '  Type the database name (banan) to proceed: ' confirm
    [ "$confirm" = "banan" ] || { echo "aborted"; exit 1; }

    log "restoring into the live database"
    # --single-transaction is what makes this safe to attempt at all: without
    # it pg_restore keeps going after an error, and --clean means it has
    # already dropped tables by then — a failure halfway would leave prod as a
    # mix of old, new and missing tables. Wrapped in one transaction, a failed
    # restore rolls back and leaves the database exactly as it was.
    docker exec -i "$CONTAINER" sh -c \
      'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
         --single-transaction --exit-on-error \
         --clean --if-exists --no-owner --no-privileges' \
      < "$dump"
    log "restored. Start the backend and check the site:"
    log "  docker compose --env-file infra/.env.prod -f docker-compose.prod.yml start backend"
    ;;

  *) usage ;;
esac
