#!/usr/bin/env bash
# deploy_server_linux.sh — Run this script ON the Linux server to build and deploy
# Requirements: git, dart SDK >= 3.0.0 (no Flutter needed)
# Usage: bash deploy_server_linux.sh [repo_url] [branch]
set -euo pipefail

REPO_URL="${1:-https://github.com/aymank2020/Railways-Secretariat-System.git}"
BRANCH="${2:-main}"
BUILD_DIR="/tmp/secretariat_build"
DEPLOY_DIR="/opt/secretariat"
SERVICE="secretariat"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"

echo "==> Cloning repository ($BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR"

cd "$BUILD_DIR"

echo "==> Switching to server-only pubspec (no Flutter SDK required)..."
cp pubspec_server.yaml pubspec.yaml

echo "==> Running dart pub get..."
dart pub get

echo "==> Compiling server_main.dart..."
dart compile exe lib/server_main.dart -o server_main

echo "==> Deploying binary..."
sudo cp server_main "$DEPLOY_DIR/server_main"
sudo chown secretariat:secretariat "$DEPLOY_DIR/server_main"
sudo chmod 755 "$DEPLOY_DIR/server_main"

echo "==> Restarting service..."
sudo systemctl restart "$SERVICE"
sleep 2
sudo systemctl status "$SERVICE" --no-pager

echo ""
echo "==> Health check..."
curl -sf http://localhost:8080/api/health && echo "" || echo "Health check failed (service may still be starting)"

echo "Done."
