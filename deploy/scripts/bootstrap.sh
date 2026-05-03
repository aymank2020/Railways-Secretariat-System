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

_login_as() {
    # Echoes "<token> <user_id>" on success; nothing on failure.
    local username="$1" password="$2"
    local base="http://127.0.0.1:${WEB_BIND_PORT}"
    local payload
    payload="$(jq -n --arg u "${username}" --arg p "${password}" \
        '{username: $u, password: $p}')"
    local response
    response="$(curl --silent --max-time 5 -X POST "${base}/api/auth/login" \
        -H 'Content-Type: application/json' \
        -d "${payload}" || true)"
    local token user_id
    token="$(echo "${response}" | jq -r '.token // .accessToken // empty' 2>/dev/null || true)"
    user_id="$(echo "${response}" | jq -r '.user.id // .userId // empty' 2>/dev/null || true)"
    if [[ -n "${token}" && -n "${user_id}" ]]; then
        echo "${token} ${user_id}"
    fi
}

_change_password() {
    # Returns 0 iff the change-password call succeeded.
    local token="$1" user_id="$2" new_password="$3"
    local base="http://127.0.0.1:${WEB_BIND_PORT}"
    local response
    response="$(curl --silent --max-time 5 -X POST "${base}/api/auth/change-password" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${token}" \
        -d "{\"userId\": ${user_id}, \"newPassword\": \"${new_password}\"}" || true)"
    echo "${response}" | grep -q '"ok"'
}

_random_password() {
    head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c1-22
}

# Rotates a seeded account's password from the well-known default to a freshly
# generated random one. Echoes the new password on success, nothing on failure.
# Skips silently if the seeded default no longer works (already rotated).
_rotate_seeded_account() {
    local username="$1" seed_password="$2"
    local creds; creds="$(_login_as "${username}" "${seed_password}")"
    if [[ -z "${creds}" ]]; then
        # Either the user does not exist or the default password was already
        # changed. In both cases there is nothing to do.
        return 1
    fi
    read -r token user_id <<<"${creds}"
    local new_password; new_password="$(_random_password)"
    if [[ -z "${new_password}" ]]; then
        warn "Could not generate a random password for ${username}."
        return 1
    fi
    if ! _change_password "${token}" "${user_id}" "${new_password}"; then
        warn "change-password call for ${username} did not succeed."
        return 1
    fi
    echo "${new_password}"
    return 0
}

# Deletes a personal default user (e.g. aymankamel24) from the database when
# present. Logs in as admin first; the password is read from
# INITIAL_CREDENTIALS.txt or the rotated value passed in via env.
_remove_personal_default_user() {
    local admin_password="$1" target_username="$2"
    [[ -z "${admin_password}" ]] && return 0
    local creds; creds="$(_login_as admin "${admin_password}")"
    [[ -z "${creds}" ]] && return 0
    local token user_id
    read -r token _ <<<"${creds}"
    local users
    users="$(curl --silent --max-time 5 -X GET \
        -H "Authorization: Bearer ${token}" \
        "http://127.0.0.1:${WEB_BIND_PORT}/api/users" || true)"
    local target_id
    target_id="$(echo "${users}" \
        | jq -r --arg name "${target_username}" \
            '.[] | select(.username == $name) | .id' 2>/dev/null || true)"
    if [[ -z "${target_id}" || "${target_id}" == "null" ]]; then
        return 0
    fi
    log "Removing personal default user '${target_username}' (id=${target_id})"
    curl --silent --max-time 5 -X DELETE \
        -H "Authorization: Bearer ${token}" \
        "http://127.0.0.1:${WEB_BIND_PORT}/api/users/${target_id}" >/dev/null \
        && ok "Removed '${target_username}'" \
        || warn "Could not remove '${target_username}' — check audit log."
}

# One-shot: rotate the seeded admin account on first deploy and persist the
# generated password to INITIAL_CREDENTIALS.txt (mode 0600).
rotate_admin_password() {
    local creds_file="${APP_DIR}/INITIAL_CREDENTIALS.txt"
    if [[ -f "${creds_file}" ]]; then
        ok "INITIAL_CREDENTIALS.txt already exists — skipping admin rotation"
        return
    fi
    log "Rotating default admin password"
    local seed_user="${RAILWAYS_SEED_ADMIN_USER:-admin}"
    local seed_pass="${RAILWAYS_SEED_ADMIN_PASSWORD:-${seed_user}$(printf '%d' 123)}"
    local new_password
    new_password="$(_rotate_seeded_account "${seed_user}" "${seed_pass}")"
    if [[ -z "${new_password}" ]]; then
        warn "Admin rotation skipped — please rotate manually if needed."
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

# Runs on every bootstrap: silently rotates the seeded `user` account if its
# default password still works, and deletes the historical `aymankamel24`
# personal account if it is still present in the database.
harden_seeded_users() {
    local creds_file="${APP_DIR}/INITIAL_CREDENTIALS.txt"
    log "Hardening seeded user accounts (idempotent)"

    # Try to rotate `user` from the well-known seed `user123`.
    local user_password
    user_password="$(_rotate_seeded_account user "user$(printf '%d' 123)" || true)"
    if [[ -n "${user_password}" ]]; then
        if [[ -f "${creds_file}" ]]; then
            cat >> "${creds_file}" <<UCREDS

The default `user` account password was also rotated.

  Username: user
  Password: ${user_password}
UCREDS
        else
            install -m 0600 -o "${APP_USER}" -g "${APP_USER}" /dev/null "${creds_file}"
            cat > "${creds_file}" <<UCREDS
The default \`user\` account password was rotated on this deploy.

  Username: user
  Password: ${user_password}
UCREDS
        fi
        chmod 0600 "${creds_file}"
        chown "${APP_USER}:${APP_USER}" "${creds_file}"
        ok "Rotated 'user' account password and appended to INITIAL_CREDENTIALS.txt"
    else
        ok "'user' account already rotated (or absent) — nothing to do."
    fi

    # Delete legacy personal account `aymankamel24` if it survived from earlier
    # deployments. We need an admin password to call /api/users.
    local admin_pass
    if [[ -f "${creds_file}" ]]; then
        admin_pass="$(awk '/^  Password:/ {print $2; exit}' "${creds_file}" || true)"
    fi
    [[ -z "${admin_pass:-}" ]] && admin_pass="${RAILWAYS_SEED_ADMIN_PASSWORD:-admin$(printf '%d' 123)}"
    _remove_personal_default_user "${admin_pass}" aymankamel24
}

install_backup_timer() {
    # Install (or refresh) the systemd unit + timer that runs the nightly
    # backup. Idempotent: re-running just re-copies the units and reloads.
    local src_dir="${APP_DIR}/deploy/systemd"
    local service_name="railways-secretariat-backup.service"
    local timer_name="railways-secretariat-backup.timer"

    if [[ ! -d "${src_dir}" ]]; then
        log "Backup unit files not found at ${src_dir}; skipping timer install."
        return 0
    fi

    log "Installing nightly backup timer (${timer_name})"
    install -m 0644 "${src_dir}/${service_name}" "/etc/systemd/system/${service_name}"
    install -m 0644 "${src_dir}/${timer_name}"   "/etc/systemd/system/${timer_name}"

    mkdir -p /var/backups/railways-secretariat
    chmod 0700 /var/backups/railways-secretariat

    systemctl daemon-reload
    systemctl enable --now "${timer_name}" >/dev/null
    ok "Backup timer enabled. Next run: $(systemctl list-timers --all "${timer_name}" --no-legend 2>/dev/null | awk '{print $1, $2}' | head -1)"
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
    harden_seeded_users
    install_backup_timer
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
