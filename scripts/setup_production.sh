#!/usr/bin/env bash
# =============================================================================
# setup_production.sh
# Full production setup for Railway Secretariat System on Ubuntu/Debian server.
#
# What this script does:
#   1. Builds the server binary from source (uses pubspec_server.yaml — no Flutter needed)
#   2. Deploys binary to /opt/secretariat/
#   3. Installs & starts the secretariat systemd service
#   4. Installs cloudflared and sets up a free Cloudflare Tunnel
#   5. Prints the public HTTPS URL for the app
#
# Usage:
#   bash setup_production.sh [--skip-build] [--skip-tunnel]
#
# Requirements on server:
#   - Dart SDK >= 3.0.0  (dart --version)
#   - git
#   - sudo access
#   - Internet connection
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/aymank2020/Railways-Secretariat-System.git"
BRANCH="main"
BUILD_DIR="/tmp/secretariat_build"
DEPLOY_DIR="/opt/secretariat"
SERVICE_NAME="secretariat"
CLOUDFLARED_SERVICE="cloudflared"
TUNNEL_NAME="secretariat"
SKIP_BUILD=false
SKIP_TUNNEL=false

# ── Parse flags ──────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skip-build)  SKIP_BUILD=true ;;
    --skip-tunnel) SKIP_TUNNEL=true ;;
  esac
done

log()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
ok()   { echo -e "\033[1;32m    ✓ $*\033[0m"; }
warn() { echo -e "\033[1;33m    ⚠ $*\033[0m"; }
die()  { echo -e "\033[1;31m    ✗ $*\033[0m"; exit 1; }

# ── 1. Build server binary ────────────────────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
  log "Building server binary..."

  # Check Dart
  dart --version || die "Dart SDK not found. Install it: https://dart.dev/get-dart"

  # Clean previous build
  rm -rf "$BUILD_DIR"

  log "Cloning repository (branch: $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR"

  cd "$BUILD_DIR"

  log "Switching to server-only pubspec (no Flutter SDK required)..."
  cp pubspec_server.yaml pubspec.yaml

  log "Running dart pub get..."
  dart pub get

  log "Compiling server_main.dart..."
  dart compile exe lib/server_main.dart -o "$BUILD_DIR/server_main"
  ok "Binary compiled: $BUILD_DIR/server_main ($(du -sh $BUILD_DIR/server_main | cut -f1))"
else
  log "Skipping build (--skip-build)"
  [ -f "$BUILD_DIR/server_main" ] || die "No binary found at $BUILD_DIR/server_main — remove --skip-build"
fi

# ── 2. Deploy binary ──────────────────────────────────────────────────────────
log "Deploying binary to $DEPLOY_DIR..."

# Ensure directories exist
sudo mkdir -p "$DEPLOY_DIR"/{logs,backups,secretariat_data}

# Ensure secretariat system user exists
if ! id -u secretariat &>/dev/null; then
  log "Creating secretariat system user..."
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin secretariat
  ok "User 'secretariat' created"
fi

# Stop service if running (ignore errors)
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true

# Copy binary
sudo cp "$BUILD_DIR/server_main" "$DEPLOY_DIR/server_main"
sudo chown secretariat:secretariat "$DEPLOY_DIR/server_main"
sudo chmod 755 "$DEPLOY_DIR/server_main"
sudo chown -R secretariat:secretariat "$DEPLOY_DIR"
ok "Binary deployed to $DEPLOY_DIR/server_main"

# ── 3. Install / update systemd service ──────────────────────────────────────
log "Installing systemd service..."

sudo tee /etc/systemd/system/secretariat.service > /dev/null <<'SERVICE'
[Unit]
Description=Railway Secretariat API Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=secretariat
Group=secretariat
WorkingDirectory=/opt/secretariat
ExecStart=/opt/secretariat/server_main
Restart=on-failure
RestartSec=5s

# Environment
Environment=SECRETARIAT_SERVER_HOST=0.0.0.0
Environment=SECRETARIAT_SERVER_PORT=8080
Environment=SECRETARIAT_STORAGE_ROOT=/opt/secretariat/secretariat_data
Environment=SECRETARIAT_LOG_REQUESTS=1

# Logging
StandardOutput=append:/opt/secretariat/logs/server.log
StandardError=append:/opt/secretariat/logs/error.log

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
sleep 2

if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
  ok "secretariat service is running"
else
  warn "Service may have failed — checking logs:"
  sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
  die "Service failed to start"
fi

# Quick local health check
sleep 1
if curl -sf http://localhost:8080/api/health > /dev/null; then
  ok "Local health check passed: http://localhost:8080/api/health"
else
  warn "Local health check failed — service may still be starting"
fi

# ── 4. Install & configure Cloudflare Tunnel ─────────────────────────────────
if [ "$SKIP_TUNNEL" = false ]; then
  log "Installing cloudflared..."

  if ! command -v cloudflared &>/dev/null; then
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" \
      -o /tmp/cloudflared.deb
    sudo dpkg -i /tmp/cloudflared.deb
    ok "cloudflared installed: $(cloudflared --version)"
  else
    ok "cloudflared already installed: $(cloudflared --version)"
  fi

  # ── Quick tunnel (trycloudflare.com — no login needed) ──────────────────
  log "Starting Cloudflare quick tunnel (trycloudflare.com)..."
  warn "URL will be random but stable while the service runs."
  warn "For a permanent URL, run: cloudflared tunnel login"

  # Create a systemd service for the tunnel
  sudo tee /etc/systemd/system/cloudflared-secretariat.service > /dev/null <<'TUNNEL_SERVICE'
[Unit]
Description=Cloudflare Tunnel for Railway Secretariat
After=network-online.target secretariat.service
Wants=network-online.target
Requires=secretariat.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --url http://localhost:8080
Restart=on-failure
RestartSec=10s

# Log the tunnel URL to a file for easy retrieval
StandardOutput=append:/opt/secretariat/logs/cloudflare_tunnel.log
StandardError=append:/opt/secretariat/logs/cloudflare_tunnel.log

[Install]
WantedBy=multi-user.target
TUNNEL_SERVICE

  sudo systemctl daemon-reload
  sudo systemctl enable cloudflared-secretariat
  sudo systemctl start cloudflared-secretariat

  log "Waiting for tunnel URL (up to 30 seconds)..."
  TUNNEL_URL=""
  for i in $(seq 1 30); do
    sleep 1
    TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' \
      /opt/secretariat/logs/cloudflare_tunnel.log 2>/dev/null | tail -1 || true)
    if [ -n "$TUNNEL_URL" ]; then
      break
    fi
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ -n "$TUNNEL_URL" ]; then
    echo ""
    echo "  🌐 PUBLIC URL:  $TUNNEL_URL"
    echo ""
    echo "  Use this URL in the Flutter app Server Settings screen."
    echo "  Health check: $TUNNEL_URL/api/health"
    echo ""
    # Write URL to a file for easy retrieval
    echo "$TUNNEL_URL" | sudo tee "$DEPLOY_DIR/tunnel_url.txt" > /dev/null
    ok "URL saved to $DEPLOY_DIR/tunnel_url.txt"
  else
    warn "Could not detect URL yet. Check manually:"
    echo "  sudo journalctl -u cloudflared-secretariat -n 30"
    echo "  or: grep trycloudflare /opt/secretariat/logs/cloudflare_tunnel.log"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  log "Skipping Cloudflare tunnel setup (--skip-tunnel)"
fi

# ── 5. Summary ────────────────────────────────────────────────────────────────
echo ""
log "Setup complete! Services status:"
sudo systemctl status "$SERVICE_NAME" --no-pager -l | head -8
echo ""
sudo systemctl status cloudflared-secretariat --no-pager -l 2>/dev/null | head -8 || true

echo ""
echo "Useful commands:"
echo "  Get tunnel URL:    cat $DEPLOY_DIR/tunnel_url.txt"
echo "  Server logs:       tail -f $DEPLOY_DIR/logs/server.log"
echo "  Tunnel logs:       tail -f $DEPLOY_DIR/logs/cloudflare_tunnel.log"
echo "  Restart server:    sudo systemctl restart $SERVICE_NAME"
echo "  Restart tunnel:    sudo systemctl restart cloudflared-secretariat"
echo "  Redeploy:          bash <(curl -fsSL https://raw.githubusercontent.com/aymank2020/Railways-Secretariat-System/main/scripts/setup_production.sh)"
