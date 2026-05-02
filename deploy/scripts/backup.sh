#!/usr/bin/env bash
# =============================================================================
# backup.sh
#
# Snapshot the Docker named volume that holds the SQLite database and the
# uploaded attachments for the Railway Secretariat System.
#
# Output: a single tar.gz under $BACKUP_DIR named
#         secretariat-backup-YYYYMMDD-HHMMSS.tar.gz
# Retention: keeps the newest $RETENTION (default 14) files.
#
# Usage (run as root or as the `railways` user that owns the docker group):
#   sudo bash deploy/scripts/backup.sh
#
# Override defaults via env:
#   VOLUME_NAME=railways_secretariat_data
#   BACKUP_DIR=/var/backups/railways-secretariat
#   RETENTION=14
#
# Example cron (daily at 02:30):
#   30 2 * * *  /opt/railways-secretariat-flutter/deploy/scripts/backup.sh \
#               >> /var/log/railways-secretariat-backup.log 2>&1
# =============================================================================
set -euo pipefail

VOLUME_NAME="${VOLUME_NAME:-railways_secretariat_data}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/railways-secretariat}"
RETENTION="${RETENTION:-14}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
ARCHIVE="${BACKUP_DIR}/secretariat-backup-${TIMESTAMP}.tar.gz"

log()  { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }
die()  { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker CLI not found"

if ! docker volume inspect "${VOLUME_NAME}" >/dev/null 2>&1; then
    die "Docker volume '${VOLUME_NAME}' does not exist."
fi

mkdir -p "${BACKUP_DIR}"
chmod 0700 "${BACKUP_DIR}"

log "Snapshotting volume '${VOLUME_NAME}' -> ${ARCHIVE}"
# Run a tiny throw-away container that mounts the volume read-only and tars
# its contents.  Using --rm + --network=none keeps the side effects minimal.
docker run --rm --network=none \
    -v "${VOLUME_NAME}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:3.20 \
    sh -c "tar -C /data -czf /backup/$(basename "${ARCHIVE}") . && chmod 0600 /backup/$(basename "${ARCHIVE}")"

log "Archive created: $(du -sh "${ARCHIVE}" | cut -f1) at ${ARCHIVE}"

# Retention: keep only the newest $RETENTION archives.
log "Pruning old backups (retain ${RETENTION})"
mapfile -t old_files < <(
    find "${BACKUP_DIR}" -maxdepth 1 -type f \
        -name 'secretariat-backup-*.tar.gz' \
        -printf '%T@ %p\n' \
        | sort -nr \
        | awk -v keep="${RETENTION}" 'NR>keep {print $2}'
)
for f in "${old_files[@]}"; do
    log "Removing old backup: ${f}"
    rm -f -- "${f}"
done

log "Backup complete."
