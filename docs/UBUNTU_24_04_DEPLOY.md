# Ubuntu Server 24.04 LTS — Production Deployment Runbook

This document is the English counterpart to the Arabic deployment section in
[`README.md`](../README.md). It walks through deploying the Railway Secretariat
System on a clean Ubuntu Server 24.04 LTS host, covering: provisioning,
verification, backups, upgrades, and (optional) Cloudflare Tunnel for remote
access.

---

## Architecture

The production stack runs as three Docker services (the third optional):

| Service       | Port           | Description                                                      |
|---------------|----------------|------------------------------------------------------------------|
| `server`      | 8080 (internal)| Dart-only API server — compiled via `dart compile exe`, ships in a Debian-slim image with `tini` + system `libsqlite3`. |
| `web`         | 80 (host)      | nginx serving the Flutter Web bundle, reverse-proxying `/api/*` to `server`. |
| `cloudflared` | n/a            | Optional outbound Cloudflare Tunnel for remote (WARP) access.     |

Persistent state (SQLite DB + uploaded attachments) lives in the Docker named
volume `railways_secretariat_data`, so containers can be rebuilt freely.

---

## Prerequisites

- A clean Ubuntu Server **24.04 LTS** (`noble`) host with internet access.
- A user with `sudo` privileges (root works).
- ~2 GB free disk for images + builds.
- One of:
  - **LAN-only access**: a local network the host is on (e.g. `192.168.0.0/16`).
  - **Remote access**: a Cloudflare account if you want to expose it via a Tunnel.

---

## 1. One-shot provisioning (recommended)

The repository ships with an idempotent bootstrap script that does everything:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/aymank2020/Railways-Secretariat-System.git /tmp/railways
cd /tmp/railways
sudo bash deploy/scripts/bootstrap.sh
```

What it does, in order:

1. Installs Docker Engine + Compose v2 + UFW + jq.
2. Creates the `railways` system user and adds it to the `docker` group.
3. Clones the repo into `/opt/railways-secretariat-flutter` (or fast-forwards
   if it already exists).
4. Generates `/opt/railways-secretariat-flutter/.env` from `.env.example`
   (default port 80, CORS closed, rate-limit 10).
5. Configures UFW: SSH always allowed, port 80 restricted to LAN ranges
   (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
6. Builds and starts the `server` and `web` services.
7. Waits for both to become healthy via `/healthz` and `/api/health`.
8. **Rotates the seeded admin account** (`admin` / `admin123`) to a random
   22-character password and writes it to
   `/opt/railways-secretariat-flutter/INITIAL_CREDENTIALS.txt` (mode `0600`).

When the script exits, the LAN URL is printed (e.g. `http://192.168.1.15`).

### After bootstrap

```bash
cat /opt/railways-secretariat-flutter/INITIAL_CREDENTIALS.txt   # rotated admin password
curl -fsS http://localhost/healthz                              # nginx liveness
curl -fsS http://localhost/api/health                           # API liveness
```

Open `http://<lan-ip>/` in a browser and log in with `admin` + the rotated
password from `INITIAL_CREDENTIALS.txt`. **Change it again** from the user
settings screen, then `shred -u` the credentials file.

---

## 2. Manual deployment (for non-LAN setups)

If you don't want UFW or the LAN-only restriction (e.g. you're putting nginx
behind another reverse proxy that handles TLS), do this instead:

```bash
sudo apt-get update && sudo apt-get install -y git docker.io docker-compose-v2
sudo systemctl enable --now docker

git clone https://github.com/aymank2020/Railways-Secretariat-System.git /opt/railways
cd /opt/railways

cp .env.example .env
# edit .env: WEB_BIND_HOST, WEB_BIND_PORT, SECRETARIAT_CORS_ORIGINS, etc.

docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps   # both services should be "healthy"
```

You will then need to rotate the admin password manually:

```bash
curl -X POST http://localhost/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
# → use the returned token to call /api/auth/change-password (see lib/server_main.dart)
```

---

## 3. Verifying the deployment

| Check | Expected output |
|---|---|
| `docker compose -f docker-compose.prod.yml ps` | both services `Up (healthy)` |
| `curl -fsS http://<host>/healthz` | `ok` |
| `curl -fsS http://<host>/api/health` | JSON with `"status":"ok"` |
| `curl -fsS http://<host>/` | HTML for the Flutter Web bundle |
| Login at `http://<host>/` | works with the rotated admin password |

If any healthcheck fails, the most useful logs are:

```bash
sudo -u railways docker compose -f /opt/railways-secretariat-flutter/docker-compose.prod.yml logs --tail=80
```

---

## 4. Daily operations

### Update to the latest commit on `main`

```bash
sudo -u railways bash -c '
  cd /opt/railways-secretariat-flutter && \
  git pull --ff-only origin main && \
  docker compose -f docker-compose.prod.yml build && \
  docker compose -f docker-compose.prod.yml up -d --force-recreate
'
```

### Backup the database + attachments

The repo ships a Docker-volume-aware backup script:

```bash
sudo bash /opt/railways-secretariat-flutter/deploy/scripts/backup.sh
ls -la /var/backups/railways-secretariat/
```

It produces a single `tar.gz` per run, mode `0600`, and prunes archives older
than the newest 14. To run it daily at 02:30, install a root crontab entry:

```cron
30 2 * * *  /opt/railways-secretariat-flutter/deploy/scripts/backup.sh \
            >> /var/log/railways-secretariat-backup.log 2>&1
```

Restoring a backup (DESTRUCTIVE — wipes the current volume):

```bash
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml stop server
docker run --rm \
    -v railways_secretariat_data:/data \
    -v /var/backups/railways-secretariat:/backup \
    alpine:3.20 \
    sh -c 'rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null; \
           tar -C /data -xzf /backup/<archive>.tar.gz'
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml up -d server
```

### Tail logs

```bash
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml logs -f
```

Both services have rotation caps configured (`max-size: 10m`, `max-file: 3`)
so logs cannot fill the disk.

---

## 5. (Optional) Cloudflare Tunnel for remote access

If you want users to reach the system from outside the LAN without opening
port 80 to the internet:

1. On a trusted admin machine, create a tunnel:
   ```bash
   cloudflared tunnel create secretariat
   ```
   Follow the dashboard flow until you have a **Tunnel Token**.

2. On the server, add the token to `/opt/railways-secretariat-flutter/.env`:
   ```
   CLOUDFLARE_TUNNEL_TOKEN=<paste-token-here>
   ```

3. Start the tunnel container:
   ```bash
   cd /opt/railways-secretariat-flutter
   sudo -u railways docker compose -f docker-compose.prod.yml \
       --profile tunnel up -d cloudflared
   ```

The tunnel terminates TLS at Cloudflare's edge. You can additionally restrict
access via Cloudflare Access policies (e.g. require WARP / SSO).

---

## 6. Migrating from an older deployment

If you already have a `secretariat.db` file from a previous Windows / older
Linux deployment, copy it into the new Docker volume:

```bash
# 1. Copy the DB onto the new server (any path works).
scp old-secretariat.db ubuntu@<new-host>:/tmp/

# 2. Stop the server container so SQLite isn't being written.
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml stop server

# 3. Move the file into the named volume.
docker run --rm \
    -v railways_secretariat_data:/data \
    -v /tmp:/import \
    alpine:3.20 \
    sh -c 'cp /import/old-secretariat.db /data/secretariat.db && chown 10001:10001 /data/secretariat.db'

# 4. Restart.
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml up -d server
```

If you also have an `attachments/` directory from the old deployment, repeat
step 3 with the directory mounted into `/data/attachments`.

After restoring, log in once and verify a few records load before deleting
the old database file.

---

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `web` container unhealthy, `server` healthy | nginx upstream rejected (server still starting) | wait 15 s; if persistent, check `logs server` |
| `server` container unhealthy | sqlite3 lib not present, or DB path unwritable | inspect `logs server`; ensure `libsqlite3-0` is in image (it is by default) |
| Default admin login fails | password was already rotated | check `INITIAL_CREDENTIALS.txt` |
| Port 80 already in use | another service (apache, vue stack) on host | edit `.env` `WEB_BIND_PORT` to 8081, retry |
| LAN clients can't reach the server | UFW blocking | `sudo ufw status` and ensure your subnet is allowed |
| "Could not load native library `libsqlite3.so`" | very old Debian base | rebuild — Dockerfile installs the symlink |

---

## 8. Removing the deployment

```bash
sudo -u railways docker compose \
    -f /opt/railways-secretariat-flutter/docker-compose.prod.yml down -v
sudo rm -rf /opt/railways-secretariat-flutter
sudo userdel railways
sudo ufw delete allow 80/tcp 2>/dev/null || true
```

This removes the containers, volumes (DB + attachments + logs), the install
directory, the system user, and the firewall rule.
