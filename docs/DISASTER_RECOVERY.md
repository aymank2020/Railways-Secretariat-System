# Disaster Recovery Runbook

This document describes how to **back up**, **verify**, and **restore** the
Railway Secretariat System production deployment. The whole system fits in
a single Docker named volume (`railways_secretariat_data`) plus a static
Flutter Web bundle, so recovery is intentionally simple — but every minute
matters in an outage, so the steps below assume nothing and tell you
exactly what to type.

> **Audience:** the operator on the ground (`aymankamel24` on
> `192.168.1.15`) or whoever inherits the system. The instructions are
> shell-by-shell; you should be able to follow them under stress.

---

## 1. What gets backed up

The persistent state is everything inside the
`railways_secretariat_data` Docker volume:

| Path inside the volume               | Contents                       |
| ------------------------------------ | ------------------------------ |
| `/secretariat.db`                    | Live SQLite database (WAL)     |
| `/secretariat.db-wal`, `.db-shm`     | SQLite WAL & shared-memory     |
| `/attachments/...`                   | Uploaded files (PDF/images/etc)|

**Source of truth:** `deploy/scripts/backup.sh` — it does not just `tar`
the volume; it uses SQLite's online `.backup` API to capture a consistent
DB snapshot **even while the server is writing**, then bundles the
snapshot together with the attachments tree into a single
`tar.gz` archive under `/var/backups/railways-secretariat/`.

Each archive has the layout:

```
secretariat-backup-YYYYMMDD-HHMMSSZ.tar.gz
├── secretariat-snapshot.db    ← consistent, safe to open with sqlite3
├── MANIFEST.txt               ← timestamps, sizes, integrity_check
└── attachments/...            ← files referenced by the DB
```

The original live `.db`, `.db-wal`, and `.db-shm` files are
**deliberately excluded** from the archive — we always restore from the
snapshot, never from a torn live copy.

---

## 2. Backup schedule

The systemd timer `railways-secretariat-backup.timer` (installed by
`bootstrap.sh`) fires daily at **02:30 local time** with a randomised
delay of up to 30 minutes. `Persistent=true` is set, so a missed run
catches up on the next boot.

Inspect the schedule:

```bash
sudo systemctl status railways-secretariat-backup.timer
sudo systemctl list-timers --all | grep railways-secretariat
```

Force a run on demand (for example before a risky migration):

```bash
sudo systemctl start railways-secretariat-backup.service
sudo journalctl -u railways-secretariat-backup.service -n 50 --no-pager
```

List the resulting archives:

```bash
sudo ls -lh /var/backups/railways-secretariat/
```

Default retention is **14 archives**; older files are pruned by the
backup script itself.

---

## 3. Verifying a backup

A backup you have never tested is a backup you do not have. Every
quarter — and immediately after any change to the schema — verify the
**latest** archive on a separate machine (laptop, fresh VM, anything
that is **not** production). A clean Ubuntu 24.04 box is the canonical
target, but any host with `sqlite3` and `tar` will do.

```bash
# 1. Copy the archive out of production.
scp aymankamel24@192.168.1.15:/var/backups/railways-secretariat/secretariat-backup-LATEST.tar.gz /tmp/

# 2. Extract it into a sandbox directory.
mkdir /tmp/sec-restore && tar -xzf /tmp/secretariat-backup-*.tar.gz -C /tmp/sec-restore
cat /tmp/sec-restore/MANIFEST.txt

# 3. Run integrity_check on the snapshot.
sqlite3 /tmp/sec-restore/secretariat-snapshot.db 'PRAGMA integrity_check;'
# Expected output: ok

# 4. Spot-check the data.
sqlite3 /tmp/sec-restore/secretariat-snapshot.db "
  SELECT 'users',   COUNT(*) FROM users
  UNION ALL SELECT 'warid', COUNT(*) FROM warid
  UNION ALL SELECT 'sadir', COUNT(*) FROM sadir
  UNION ALL SELECT 'audit', COUNT(*) FROM audit_log;
"

# 5. List a few attachments. Counts should match what the user expects.
ls /tmp/sec-restore/attachments | head
find /tmp/sec-restore/attachments -type f | wc -l
```

If `integrity_check` returns anything other than `ok`, **do not delete
the archive** — keep it for inspection and walk back to the previous
known-good archive (the one before it).

---

## 4. Restore procedure (full disaster — host wiped)

This is the procedure you follow when production is gone: hard-drive
failure, VM rolled back, user accidentally deleted everything, etc.
Time-to-recovery target: **30 minutes** from a fresh Ubuntu 24.04 box.

### 4.1 Provision a fresh host

1. Install Ubuntu 24.04, give it the LAN IP `192.168.1.15` (or update
   DNS).
2. Copy the latest backup archive onto the host:

   ```bash
   scp secretariat-backup-LATEST.tar.gz aymankamel24@192.168.1.15:/tmp/
   ```

3. Clone the repo and run bootstrap:

   ```bash
   sudo bash -c '
     git clone https://github.com/aymank2020/Railways-Secretariat-System.git /tmp/railways-flutter && \
     cd /tmp/railways-flutter && \
     bash deploy/scripts/bootstrap.sh
   '
   ```

   At this point you have a **clean** stack with the seeded admin/user
   accounts. Do **not** log in yet — we are about to overwrite the DB.

### 4.2 Stop the stack so the volume is quiescent

```bash
cd /opt/railways-secretariat-flutter
sudo docker compose -f docker-compose.prod.yml down
```

### 4.3 Wipe the volume and restore the snapshot

```bash
# Remove the empty volume created by the bootstrap.
sudo docker volume rm railways_secretariat_data

# Recreate it (compose would do this automatically on `up`, but doing it
# now lets us populate it before the server starts).
sudo docker volume create --name railways_secretariat_data

# Use a throwaway alpine container to extract the archive into the volume.
sudo docker run --rm \
    -v railways_secretariat_data:/data \
    -v /tmp:/in:ro \
    alpine:3.20 \
    sh -eu -c '
        cd /data
        tar -xzf /in/secretariat-backup-LATEST.tar.gz
        # The snapshot lands at the volume root. Rename it back into the
        # filename the server expects.
        mv secretariat-snapshot.db secretariat.db
        chown -R 10001:10001 /data       # railways UID inside the server image
        chmod 0600 secretariat.db
    '
```

### 4.4 Start the stack and verify

```bash
sudo docker compose -f docker-compose.prod.yml up -d
sleep 10
curl -fsS http://localhost/api/health
```

Log in as admin (use the password from `INITIAL_CREDENTIALS.txt` if you
restored a fresh admin row; otherwise use the production password from
your password manager) and confirm:

- The list of users matches the previous deployment.
- A few warid/sadir records are visible.
- Downloading an attachment returns the original file (this confirms
  the attachments tree restored intact).

If anything looks wrong, **do not modify the data**. Stop the stack,
rerun step 4.3 with a different (older) archive, or escalate.

---

## 5. Partial restore (single record / single file)

Sometimes a user accidentally deletes one warid/sadir or one attachment.
Don't full-restore; cherry-pick.

### 5.1 Restore one row from the snapshot

```bash
# Open the latest snapshot read-only.
sqlite3 /tmp/sec-restore/secretariat-snapshot.db

sqlite> .mode insert warid
sqlite> SELECT * FROM warid WHERE id = 12345;
# Copy the resulting INSERT statement.
```

Then connect to the live DB inside the running server container and
re-insert:

```bash
sudo docker exec -i $(sudo docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml ps -q server) \
    sqlite3 /opt/secretariat/secretariat_data/secretariat.db
```

Paste the `INSERT` statement. The server will pick the row up
automatically — no restart needed.

### 5.2 Restore one attachment file

```bash
tar -xzf /tmp/secretariat-backup-LATEST.tar.gz -C /tmp/sec-restore \
    attachments/<sub>/<filename>

sudo docker cp /tmp/sec-restore/attachments/<sub>/<filename> \
    $(sudo docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml ps -q server):/opt/secretariat/secretariat_data/attachments/<sub>/<filename>

sudo docker exec $(sudo docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml ps -q server) \
    chown railways:railways /opt/secretariat/secretariat_data/attachments/<sub>/<filename>
```

---

## 6. Off-host backups (recommended)

The systemd timer keeps backups **on the same machine** as the live
data. That is fine for accidental-deletion recovery, but it does **not**
protect against host-level loss (disk failure, theft, ransomware). For
real durability, copy `/var/backups/railways-secretariat/` to a separate
host or storage system on a regular cadence.

Pick whichever matches your environment:

- **Another LAN machine** (`rsync` via SSH):
  ```bash
  rsync -avz --delete \
        /var/backups/railways-secretariat/ \
        backup-host:/srv/railways-secretariat/
  ```
- **Cloud object storage** (S3-compatible):
  ```bash
  aws s3 sync /var/backups/railways-secretariat/ \
              s3://my-railways-backup/ \
              --storage-class STANDARD_IA
  ```
- **External USB drive** mounted via udev / a cron `mount && rsync && umount`.

Whichever you pick, run the off-host copy **after** the systemd timer,
not on the same schedule, so you never copy an in-progress archive.

---

## 7. Common failure modes & fixes

| Symptom                              | Likely cause / fix |
| ------------------------------------ | ------------------ |
| `backup.sh` exits with `integrity_check returned: ...` | The live DB is corrupted. Investigate immediately — do **not** discard the failed snapshot, and try running `sqlite3 /opt/secretariat/secretariat_data/secretariat.db 'PRAGMA integrity_check'` directly. If the live DB is corrupt, restore from the previous good archive (section 4). |
| `docker volume inspect railways_secretariat_data` fails | The stack has never been started (volume not created), or it was force-removed. `docker compose -f docker-compose.prod.yml up -d` recreates it. |
| `INITIAL_CREDENTIALS.txt` missing | Re-run `bootstrap.sh`. The `harden_seeded_users` and `rotate_admin_password` steps are idempotent and will recreate the file if needed. |
| `/var/backups/railways-secretariat` is full | Lower `RETENTION` (default 14) or move the directory to a larger volume and update `BACKUP_DIR` in the systemd unit's `Environment=` block. |
| Server returns 500 with `Reference: req-…` | Look up the request id in the journal: `sudo journalctl CONTAINER_NAME=railways-server | grep req-…` |

---

## 8. Quick reference

```bash
# Run a backup right now.
sudo systemctl start railways-secretariat-backup.service

# List backups.
sudo ls -lh /var/backups/railways-secretariat/

# Verify the latest backup (run on a non-prod machine).
tar -tzf /var/backups/railways-secretariat/$(ls -1t /var/backups/railways-secretariat/ | head -1) | head

# Inspect the systemd timer.
sudo systemctl list-timers railways-secretariat-backup.timer
sudo journalctl -u railways-secretariat-backup.service -n 50 --no-pager

# Stop the stack (e.g. before a full restore).
sudo docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml down

# Bring everything back up.
sudo docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml up -d
```
