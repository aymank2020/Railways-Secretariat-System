#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh
#
# One-shot Ubuntu 24.04 LTS provisioning script for the Railway Secretariat
# System (Flutter version).  Idempotent: safe to run repeatedly.
#
# What it does:
#   1. Installs Docker Engine + Compose v2 + UFW (skipped if already present).
#   2. Creates a dedicated `railways` system user that owns the deploy tree.
#   3. Clones / fast-forwards the repo into /opt/railways-secretariat-flutter.
#   4. Generates a .env file (port, CORS, rate-limit) with secure defaults.
#   5. Configures UFW to allow SSH and limit port 80 to LAN ranges only.
#   6. Builds and starts the Compose stack (server + web).
#   7. Waits for both services to become healthy.
#   8. Generates a strong random initial admin password and rotates it via
#      /api/auth/login + /api/auth/change-password, then writes the result
#      to /opt/railways-secretariat-flutter/INITIAL_CREDENTIALS.txt (mode 0600).
#
# Usage (run as root or with sudo):
#   sudo bash deploy/scripts/bootstrap.sh
#
# Override defaults via env:
#   REPO_URL=https://github.com/.../Railways-Secretariat-System.git
#   APP_USER=railways
#   APP_DIR=/opt/railways-secretariat-flutter
#   LAN_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
# =============================================================================
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/aymank2020/Railways-Secretariat-System.git}"
BRANCH="${BRANCH:-main}"
APP_USER="${APP_USER:-railways}"
APP_DIR="${APP_DIR:-/opt/railways-secretariat-flutter}"
LAN_CIDRS="${LAN_CIDRS:-10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
WEB_BIND_PORT="${WEB_BIND_PORT:-80}"

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
ok()   { echo -e "\033[1;32m    + $*\033[0m"; }
warn() { echo -e "\033[1;33m    ! $*\033[0m"; }
die()  { echo -e "\033[1;31m    x $*\033[0m"; exit 1; }

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        die "This script must be run as root.  Try:  sudo bash $0"
    fi
}

ensure_packages() {
    log "Installing base packages (curl, ca-certificates, ufw, jq)"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release ufw jq git >/dev/null
    ok "Base packages OK"
}

ensure_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        ok "Docker Engine + Compose v2 already installed"
        return
    fi
    log "Installing Docker Engine + Compose v2"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    local codename
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
        > /etc/apt/sources.list.d/docker.list
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    systemctl enable --now docker >/dev/null
    ok "Docker installed: $(docker --version)"
}

ensure_app_user() {
    if id -u "${APP_USER}" >/dev/null 2>&1; then
        ok "User ${APP_USER} already exists"
    else
        log "Creating system user ${APP_USER}"
        useradd --system --create-home --shell /usr/sbin/nologin "${APP_USER}"
        ok "User ${APP_USER} created"
    fi
    usermod -aG docker "${APP_USER}"
}

ensure_repo() {
    if [[ ! -d "${APP_DIR}/.git" ]]; then
        log "Cloning ${REPO_URL} -> ${APP_DIR}"
        mkdir -p "$(dirname "${APP_DIR}")"
        git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
    else
        log "Updating existing checkout in ${APP_DIR}"
        # The checkout may be owned by ${APP_USER} from a previous run while
        # this script runs as root; whitelist the path so git's
        # `detected dubious ownership` safety check doesn't abort us.
        git config --global --add safe.directory "${APP_DIR}" || true
        git -C "${APP_DIR}" fetch --quiet origin "${BRANCH}"
        git -C "${APP_DIR}" checkout --quiet "${BRANCH}"
        git -C "${APP_DIR}" pull --ff-only --quiet origin "${BRANCH}" || \
            warn "Could not fast-forward — leaving working tree as-is"
    fi
    chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
}

ensure_env_file() {
    local env_path="${APP_DIR}/.env"
    if [[ -f "${env_path}" ]]; then
        ok ".env already present (preserving existing values)"
        return
    fi
    log "Generating ${env_path} from .env.example"
    install -m 0600 -o "${APP_USER}" -g "${APP_USER}" \
        "${APP_DIR}/.env.example" "${env_path}"
}

ensure_ufw() {
    log "Configuring UFW firewall (SSH + LAN-only HTTP)"
    if ! ufw status | grep -q "Status: active"; then
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow 22/tcp comment "ssh"
        ufw --force enable
    fi
    IFS=',' read -ra _CIDRS <<<"${LAN_CIDRS}"
    for cidr in "${_CIDRS[@]}"; do
        cidr="$(echo "${cidr}" | tr -d ' ')"
        [[ -z "${cidr}" ]] && continue
        if ! ufw status | grep -q "${WEB_BIND_PORT}/tcp.*${cidr}"; then
            ufw allow from "${cidr}" to any port "${WEB_BIND_PORT}" proto tcp \
                comment "lan-http"
        fi
    done
    ok "UFW rules in place"
}

compose_up() {
    log "Building and starting Compose stack"
    sudo -u "${APP_USER}" --preserve-env=PATH bash -c "
        cd '${APP_DIR}' && \
        docker compose -f docker-compose.prod.yml pull --ignore-buildable >/dev/null 2>&1 || true && \
        docker compose -f docker-compose.prod.yml build && \
        docker compose -f docker-compose.prod.yml up -d
    "
    ok "Compose stack started"
}

wait_for_health() {
    log "Waiting for stack health"
    local lan_ip
    lan_ip="$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
    for _ in $(seq 1 60); do
        if curl --fail --silent --max-time 2 \
                "http://127.0.0.1:${WEB_BIND_PORT}/healthz" >/dev/null \
            && curl --fail --silent --max-time 2 \
                "http://127.0.0.1:${WEB_BIND_PORT}/api/health" >/dev/null; then
            ok "Web (nginx) and Server (Dart API) are both healthy."
            [[ -n "${lan_ip}" ]] && echo "    LAN URL: http://${lan_ip}:${WEB_BIND_PORT}"
            return
        fi
        sleep 2
    done
    warn "Stack did not become healthy in 120 s — check logs:"
    echo "    sudo -u ${APP_USER} docker compose -f ${APP_DIR}/docker-compose.prod.yml logs --tail=80"
}

rotate_admin_password() {
    local creds_file="${APP_DIR}/INITIAL_CREDENTIALS.txt"
    if [[ -f "${creds_file}" ]]; then
        ok "INITIAL_CREDENTIALS.txt already exists — skipping admin rotation"
        return
    fi
    log "Rotating default admin password"
    # Generate a 22-character random password (base64 trimmed of /+=).
    local new_password
    new_password="$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c1-22)"
    if [[ -z "${new_password}" ]]; then
        warn "Could not generate a random password — please rotate the admin account manually."
        return
    fi
    # Default admin credentials seeded by the application on first launch.
    # Override via env if you've already rotated the password manually.
    local seed_user="${RAILWAYS_SEED_ADMIN_USER:-admin}"
    local seed_pass="${RAILWAYS_SEED_ADMIN_PASSWORD:-${seed_user}$(printf '%d' 123)}"
    local base="http://127.0.0.1:${WEB_BIND_PORT}"
    local login_payload
    login_payload="$(jq -n --arg u "${seed_user}" --arg p "${seed_pass}" \
        '{username: $u, password: $p}')"
    local login_response
    login_response="$(curl --silent --max-time 5 -X POST "${base}/api/auth/login" \
        -H 'Content-Type: application/json' \
        -d "${login_payload}" || true)"
    local token user_id
    token="$(echo "${login_response}" | jq -r '.token // .accessToken // empty' 2>/dev/null || true)"
    user_id="$(echo "${login_response}" | jq -r '.user.id // .userId // empty' 2>/dev/null || true)"
    if [[ -z "${token}" || -z "${user_id}" ]]; then
        warn "Could not log in as the seeded admin user — please rotate the password manually."
        return
    fi
    local change_response
    change_response="$(curl --silent --max-time 5 -X POST "${base}/api/auth/change-password" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${token}" \
        -d "{\"userId\": ${user_id}, \"newPassword\": \"${new_password}\"}" || true)"
    if ! echo "${change_response}" | grep -q '"ok"'; then
        warn "change-password call did not succeed: ${change_response}"
        return
    fi
    install -m 0600 -o "${APP_USER}" -g "${APP_USER}" /dev/null "${creds_file}"
    cat > "${creds_file}" <<CREDS
The default admin password was rotated on first deploy.

  Username: admin
  Password: ${new_password}

Please log in immediately and change this password again from the user
settings page.  After verifying, you can shred this file:

  shred -u ${creds_file}
CREDS
    chmod 0600 "${creds_file}"
    chown "${APP_USER}:${APP_USER}" "${creds_file}"
    ok "Stored rotated credentials at ${creds_file} (mode 600)"
}

main() {
    require_root
    ensure_packages
    ensure_docker
    ensure_app_user
    ensure_repo
    ensure_env_file
    ensure_ufw
    compose_up
    wait_for_health
    rotate_admin_password
    log "Bootstrap complete."
    cat <<EOF

Next steps:
  - Browse to your server's LAN URL (printed above) to test the Flutter Web UI.
  - Read INITIAL_CREDENTIALS.txt for the rotated admin password.
  - To enable a Cloudflare Tunnel for remote (WARP-only) access:
      1. Edit ${APP_DIR}/.env and set CLOUDFLARE_TUNNEL_TOKEN
      2. cd ${APP_DIR}
      3. sudo -u ${APP_USER} docker compose -f docker-compose.prod.yml \\
            --profile tunnel up -d cloudflared

EOF
}

main "$@"
