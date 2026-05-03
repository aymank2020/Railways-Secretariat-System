#!/usr/bin/env bash
# =============================================================================
# backup.sh
#
# Take a *consistent* snapshot of the Railway Secretariat System persistent
# state (SQLite database + uploaded attachments) and write it to a single
# tar.gz archive on the host.
#
# Why this script (and why it is not just `tar`):
#   * The Dart server uses SQLite in WAL journal mode. A naive `tar` of the
#     live database file may capture an inconsistent snapshot (missing
#     committed transactions still in -wal, or torn pages mid-write).
#   * SQLite's online backup API (`.backup`) acquires the right locks and
#     produces a fully self-contained .db file, even while the server is
#     actively writing. We use that, then tar the resulting snapshot
#     together with the attachments tree.
#
# Output: a single tar.gz under $BACKUP_DIR named
#         secretariat-backup-YYYYMMDD-HHMMSSZ.tar.gz
# Layout inside the archive:
#         ./secretariat-snapshot.db            (consistent SQLite snapshot)
#         ./MANIFEST.txt                       (timestamp, sizes, integrity)
#         ./attachments/...                    (every uploaded file)
#
# Retention: keeps the newest $RETENTION (default 14) archives.
#
# Usage (run as root or as a user in the docker group):
#   sudo bash deploy/scripts/backup.sh
#
# Override defaults via env:
#   VOLUME_NAME=railways_secretariat_data
#   BACKUP_DIR=/var/backups/railways-secretariat
#   RETENTION=14
#   SQLITE_IMAGE=alpine:3.20         # any image where `apk add sqlite` works
#
# Scheduling: the bundled systemd timer in
# `deploy/systemd/railways-secretariat-backup.timer` calls this script every
# night. See `docs/DISASTER_RECOVERY.md` for the full restore procedure.
# =============================================================================
set -euo pipefail

VOLUME_NAME="${VOLUME_NAME:-railways_secretariat_data}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/railways-secretariat}"
RETENTION="${RETENTION:-14}"
SQLITE_IMAGE="${SQLITE_IMAGE:-alpine:3.20}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
ARCHIVE_NAME="secretariat-backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

log()  { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }
die()  { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker CLI not found in PATH."

if ! docker volume inspect "${VOLUME_NAME}" >/dev/null 2>&1; then
    die "Docker volume '${VOLUME_NAME}' does not exist. Has the stack been deployed?"
fi

mkdir -p "${BACKUP_DIR}"
chmod 0700 "${BACKUP_DIR}"

log "Snapshotting volume '${VOLUME_NAME}' -> ${ARCHIVE_PATH}"

# Inside the throwaway container we:
#   1. Install sqlite3 (apk is fast on alpine; no persistent state).
#   2. Refuse to run if the source DB does not exist.
#   3. Run `.backup` against the live DB. SQLite holds a shared lock, the
#      Dart server keeps serving requests while this runs.
#   4. Verify the snapshot with `PRAGMA integrity_check`. Anything other
#      than the literal "ok" reply aborts the backup so we never ship a
#      corrupted archive.
#   5. Build a manifest and tar the snapshot + attachments tree into
#      /backup. The live `.db`, `.db-wal`, and `.db-shm` files are
#      explicitly excluded (we only persist the consistent snapshot).
docker run --rm \
    -v "${VOLUME_NAME}:/data" \
    -v "${BACKUP_DIR}:/backup" \
    -e "TIMESTAMP=${TIMESTAMP}" \
    -e "ARCHIVE_NAME=${ARCHIVE_NAME}" \
    "${SQLITE_IMAGE}" \
    sh -eu -c '
        apk add --no-cache --quiet sqlite tar gzip >/dev/null 2>&1

        if [ ! -f /data/secretariat.db ]; then
            echo "ERROR: /data/secretariat.db not found in volume." >&2
            exit 2
        fi

        SNAPSHOT="/data/.secretariat-snapshot-${TIMESTAMP}.db"

        # 1. Online backup (consistent even with writers in flight).
        sqlite3 /data/secretariat.db ".backup ${SNAPSHOT}"

        # 2. Verify integrity. SQLite prints a single line "ok" on success,
        #    or a list of problems otherwise.
        INTEGRITY="$(sqlite3 "${SNAPSHOT}" "PRAGMA integrity_check;" || true)"
        if [ "${INTEGRITY}" != "ok" ]; then
            echo "ERROR: snapshot integrity_check returned: ${INTEGRITY}" >&2
            rm -f "${SNAPSHOT}"
            exit 3
        fi

        # 3. Move snapshot under a friendlier name + write a manifest. We
        #    stage them in /tmp/stage so they can be tarred alongside the
        #    attachments tree without leaking anything else from /data.
        mkdir -p /tmp/stage
        mv "${SNAPSHOT}" /tmp/stage/secretariat-snapshot.db

        DB_BYTES=$(stat -c %s /tmp/stage/secretariat-snapshot.db)
        ATT_BYTES=0
        if [ -d /data/attachments ]; then
            ATT_BYTES=$(du -sb /data/attachments 2>/dev/null | awk "{print \$1}")
        fi

        cat > /tmp/stage/MANIFEST.txt <<MANIFEST
Railway Secretariat System — backup manifest
Generated:        ${TIMESTAMP}
Volume:           ${VOLUME_NAME:-railways_secretariat_data}
Snapshot bytes:   ${DB_BYTES}
Attachments bytes ${ATT_BYTES}
Integrity check:  ${INTEGRITY}
Archive layout:
  ./secretariat-snapshot.db
  ./MANIFEST.txt
  ./attachments/...
MANIFEST

        # 4. Pack snapshot + attachments together.
        if [ -d /data/attachments ]; then
            cp -a /data/attachments /tmp/stage/attachments
        else
            mkdir -p /tmp/stage/attachments
        fi

        tar -C /tmp/stage -czf "/backup/${ARCHIVE_NAME}" \
            secretariat-snapshot.db MANIFEST.txt attachments

        chmod 0600 "/backup/${ARCHIVE_NAME}"

        # 5. Clean up the staging area inside the container; the container
        #    itself is removed by --rm.
        rm -rf /tmp/stage
    '

if [ ! -f "${ARCHIVE_PATH}" ]; then
    die "Archive ${ARCHIVE_PATH} was not created."
fi

ARCHIVE_SIZE="$(du -sh "${ARCHIVE_PATH}" | cut -f1)"
log "Archive created: ${ARCHIVE_SIZE} at ${ARCHIVE_PATH}"

# Retention: keep only the newest $RETENTION archives. Anything matching
# the old pre-snapshot naming (`secretariat-backup-YYYYMMDD-HHMMSS.tar.gz`)
# is also pruned by the same glob.
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
