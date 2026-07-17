#!/bin/bash
# Dump the production Postgres to $BACKUP_DIR, verify the dump is readable,
# then prune old ones. Runs ON THE VPS, from cron:
#
#   0 3 * * * bash /opt/banan/infra/backup-db.sh >> /opt/banan/backups/backup.log 2>&1
#
# Cron mails failures nowhere on a box with no MTA, so read that log — or
# better, alert on it. A backup job nobody watches is a backup job that stopped
# working in March.
#
# Env (all optional):
#   BACKUP_DIR    where dumps land          (default /opt/banan/backups)
#   RETAIN_DAYS   prune dumps older than    (default 14)
#   CONTAINER     postgres container name   (default banan-postgres-1)
#   BACKUP_REMOTE scp target for off-box copies, e.g. user@host:/backups
#                 UNSET BY DEFAULT — see the warning below.
#
# A dump sitting on the same disk as the database is not a backup: it dies with
# the box it was protecting against. Set BACKUP_REMOTE (or copy the files off
# some other way) or this script only protects against "someone dropped a
# table", not against losing the server.
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/opt/banan/backups}
RETAIN_DAYS=${RETAIN_DAYS:-14}
CONTAINER=${CONTAINER:-banan-postgres-1}
BACKUP_REMOTE=${BACKUP_REMOTE:-}

log() { echo "[$(date +'%F %T')] $*"; }

mkdir -p "$BACKUP_DIR"
out="$BACKUP_DIR/banan-$(date +%F-%H%M).dump"
tmp="$out.partial"

# POSTGRES_USER / POSTGRES_DB are already in the container's environment, so the
# credentials never have to be parsed out of .env.prod or passed on a command
# line other processes could read.
log "dumping $CONTAINER -> $out"
docker exec "$CONTAINER" sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > "$tmp"

# Prove the archive is readable before it counts as a backup. A truncated dump
# (disk full, container killed mid-write) is still a plausible-looking file, and
# without this check it would quietly replace the good ones as they age out.
log "verifying archive"
docker exec -i "$CONTAINER" pg_restore --list > /dev/null < "$tmp"

mv "$tmp" "$out"
log "ok: $(du -h "$out" | cut -f1) $out"

if [ -n "$BACKUP_REMOTE" ]; then
  log "copying off-box -> $BACKUP_REMOTE"
  scp -q "$out" "$BACKUP_REMOTE/"
  log "off-box copy done"
else
  log "WARNING: BACKUP_REMOTE unset — this dump only exists on this server"
fi

# Only reached when today's dump verified. `set -e` means a failure above exits
# first, so a bad run can never prune the good dumps it failed to replace, and
# the .partial file is left behind as evidence.
log "pruning dumps older than ${RETAIN_DAYS}d"
find "$BACKUP_DIR" -maxdepth 1 -name 'banan-*.dump' -mtime "+$RETAIN_DAYS" -print -delete

log "done"
