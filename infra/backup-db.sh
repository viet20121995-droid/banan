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
#   DRIVE_REMOTE  rclone remote for the Google Drive copy (default gdrive:).
#                 Used when `rclone listremotes` knows it. One-time setup on
#                 the VPS (interactive, needs a browser on another machine):
#                   rclone config → n → name: gdrive → storage: drive →
#                   client_id/secret: blank → scope: 1 (drive) →
#                   root_folder_id: <id of the shared backup folder> →
#                   service_account_file: blank → Edit advanced: n →
#                   Use web browser to auto authenticate: n → run the printed
#                   `rclone authorize "drive" ...` on a PC, paste the token →
#                   Shared drive: n → y. Then `rclone lsd gdrive:` must list.
#                 Dumps older than DRIVE_RETAIN_DAYS (default 30) are deleted
#                 from the Drive folder.
#   ENV_FILE      where RESEND_API_KEY / OPS_ALERT_RECIPIENTS / EMAIL_FROM live
#                 (default /opt/banan/infra/.env.prod) — a failure mails ops.
#
# A dump sitting on the same disk as the database is not a backup: it dies with
# the box it was protecting against. Set BACKUP_REMOTE (or copy the files off
# some other way) or this script only protects against "someone dropped a
# table", not against losing the server.
set -euo pipefail

# A dump is every user, order, payment and loyalty balance in one file. Without
# this it inherits the cron user's umask — 022 for root, i.e. mode 644, readable
# by any local user or process on the box.
umask 077

BACKUP_DIR=${BACKUP_DIR:-/opt/banan/backups}
RETAIN_DAYS=${RETAIN_DAYS:-14}
CONTAINER=${CONTAINER:-banan-postgres-1}
BACKUP_REMOTE=${BACKUP_REMOTE:-}
DRIVE_REMOTE=${DRIVE_REMOTE:-gdrive:}
DRIVE_RETAIN_DAYS=${DRIVE_RETAIN_DAYS:-30}
ENV_FILE=${ENV_FILE:-/opt/banan/infra/.env.prod}

log() { echo "[$(date +'%F %T')] $*"; }

# Mail ops (Resend, same key the API uses). Best-effort: a mail failure must
# not change the backup's own exit code.
envval() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' ; }
alert() {
  local subject="$1" body="$2" key to from
  key=$(envval RESEND_API_KEY); to=$(envval OPS_ALERT_RECIPIENTS); from=$(envval EMAIL_FROM)
  [ -z "$to" ] && to=$(envval CONTACT_TO)
  if [ -z "$key" ] || [ -z "$to" ]; then log "alert not sent (no key/recipients): $subject"; return 0; fi
  # Every string field goes through esc(): a quote or backslash in EMAIL_FROM
  # or in the message must not break the JSON.
  esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '; }
  local json
  json=$(printf '{"from":"%s","to":[%s],"subject":"[Banan] %s","text":"%s"}' \
    "$(esc "${from:-Banan <onboarding@resend.dev>}")" \
    "$(printf '%s' "$to" | sed 's/ *, */","/g; s/^/"/; s/$/"/')" \
    "$(esc "$subject")" "$(esc "$body")")
  curl -s -o /dev/null -X POST https://api.resend.com/emails \
    -H "Authorization: Bearer $key" -H 'Content-Type: application/json' -d "$json" || true
}
trap 'rc=$?; log "ERROR: backup failed (exit $rc) at line $LINENO"; alert "Backup DB thất bại trên $(hostname)" "backup-db.sh exit $rc at line $LINENO — xem /opt/banan/backups/backup.log"; exit $rc' ERR

mkdir -p "$BACKUP_DIR"
# umask only governs what this run creates — chmod also repairs a directory
# that already existed with looser permissions.
chmod 700 "$BACKUP_DIR"
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

# Only reached when today's dump verified. `set -e` means a failure above exits
# first, so a bad run can never prune the good dumps it failed to replace, and
# the .partial file is left behind as evidence.
#
# Pruning happens before the off-box copy, and deliberately does not depend on
# it: retention is about this disk. If prune waited on a remote that was down
# for a fortnight, the dumps would pile up until the disk filled — and a full
# disk takes Postgres with it, which is a worse outage than the one the backup
# was insuring against.
log "pruning dumps older than ${RETAIN_DAYS}d"
find "$BACKUP_DIR" -maxdepth 1 -name 'banan-*.dump' -mtime "+$RETAIN_DAYS" -print -delete

# Tighten whatever survived, so dumps written before the umask above was added
# get repaired too instead of sitting at 644 forever.
find "$BACKUP_DIR" -maxdepth 1 -name 'banan-*.dump' -exec chmod 600 {} +

# A failed off-box copy still has to be loud — it just must not take the local
# dump or the prune down with it. Non-zero exit so cron/monitoring can see it.
rc=0
# Google Drive copy (rclone). The remote points straight at the shared backup
# folder (root_folder_id), so the dump lands there and old ones are pruned.
if command -v rclone >/dev/null 2>&1 && rclone listremotes 2>/dev/null | grep -qx "$DRIVE_REMOTE"; then
  log "copying to Google Drive ($DRIVE_REMOTE)"
  if rclone copyto "$out" "$DRIVE_REMOTE$(basename "$out")" --retries 3 --low-level-retries 10 2>>"$BACKUP_DIR/rclone.log"; then
    log "drive copy done"
    rclone delete "$DRIVE_REMOTE" --min-age "${DRIVE_RETAIN_DAYS}d" --include 'banan-*.dump' 2>>"$BACKUP_DIR/rclone.log" || true
  else
    log "ERROR: Google Drive copy failed — the dump exists only on this server"
    alert "Backup DB không lên được Google Drive" "rclone copy failed on $(hostname); see /opt/banan/backups/rclone.log"
    rc=1
  fi
else
  log "WARNING: rclone remote $DRIVE_REMOTE not configured — no Google Drive copy"
fi
if [ -n "$BACKUP_REMOTE" ]; then
  log "copying off-box -> $BACKUP_REMOTE"
  if scp -q "$out" "$BACKUP_REMOTE/"; then
    log "off-box copy done"
  else
    log "ERROR: off-box copy to $BACKUP_REMOTE failed — the dump exists only on this server"
    rc=1
  fi
fi

log "done"
exit "$rc"
