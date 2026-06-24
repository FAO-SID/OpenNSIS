#!/bin/bash
set -euo pipefail

# ============================================================================
# ops/single/first-deploy.sh — run from YOUR LAPTOP. Stands up ONE country's
# SIS on its own dedicated server, end to end, using the BASE deployment
# (docker-compose.yml + deploy.sh) — nginx on :80, default container names,
# one country per server. This is NOT the workshop multi-country layer.
#
#   ssh in → install Docker + Compose → firewall → git clone → ./deploy.sh
#
# Usage:
#   ops/single/first-deploy.sh user@SERVER_IP <CC> [ORG_LOGO_URL]
#
#   ops/single/first-deploy.sh root@203.0.113.10 NP
#   ops/single/first-deploy.sh root@203.0.113.10 PH https://example.org/logo.png
#
# Env:
#   REPO_URL   git URL to clone (default: this repo's origin). For a PRIVATE
#              repo embed a token: REPO_URL='https://<PAT>@github.com/FAO-SID/SIS-dev.git'
#   BRANCH     branch to check out (default: main)
#   DEST       server install dir (default: /opt/sis)
#
# The SPA is built with relative URLs (the compose default), so the site works
# over the server's bare IP or a domain with no edits. Re-running wipes the DB
# volume and re-seeds from the dump — same as deploy.sh itself.
# ============================================================================

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 user@SERVER_IP <CC> [ORG_LOGO_URL]" >&2
  echo "Example: $0 root@203.0.113.10 NP" >&2
  exit 1
fi

SERVER="$1"
CC=$(echo "$2" | tr '[:lower:]' '[:upper:]')          # ISO 3166-1 alpha-2
ORG_LOGO_URL="${3:-}"
BRANCH="${BRANCH:-main}"
DEST="${DEST:-/opt/sis}"
REPO_URL="${REPO_URL:-$(git -C "$(dirname "${BASH_SOURCE[0]}")/../.." config --get remote.origin.url 2>/dev/null || echo '')}"

if [[ -z "$REPO_URL" ]]; then
  echo "ERROR: no REPO_URL given and no git origin found. Set REPO_URL=…" >&2
  exit 1
fi

echo "============================================================"
echo " Target server : $SERVER"
echo " Repo / branch : $REPO_URL  ($BRANCH)"
echo " Country       : $CC   →   http://<IP>/  (nginx :80)"
echo " Install dir   : $DEST"
echo "============================================================"
echo "Press Ctrl-C now if that's wrong. Continuing in 10s…"
sleep 10

# All on-server work over a single SSH session. The remote reads the vars from
# the env we set on the ssh command line.
ssh -o StrictHostKeyChecking=accept-new "$SERVER" \
  "CC='$CC' ORG_LOGO_URL='$ORG_LOGO_URL' REPO_URL='$REPO_URL' BRANCH='$BRANCH' DEST='$DEST' bash -s" <<'REMOTE'
set -euo pipefail

echo "### 1/4  apt + Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl git ufw
  curl -fsSL https://get.docker.com | sh        # docker-ce + compose plugin
else
  echo "docker already present: $(docker --version)"
  apt-get install -y git ufw >/dev/null 2>&1 || true
fi
docker compose version

echo "### 2/4  firewall (ufw): SSH + http + https"
ufw allow 22/tcp  >/dev/null 2>&1 || true
ufw allow 80/tcp  >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
yes | ufw enable  >/dev/null 2>&1 || true
ufw status verbose || true

echo "### 3/4  clone repo → $DEST ($BRANCH)"
mkdir -p "$(dirname "$DEST")"
if [[ -d "$DEST/.git" ]]; then
  git -C "$DEST" fetch --depth 1 origin "$BRANCH"
  git -C "$DEST" checkout -f "$BRANCH"
  git -C "$DEST" reset --hard "origin/$BRANCH"
else
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

if [[ ! -f "$DEST/deploy.sh" ]]; then
  echo "ERROR: deploy.sh not found in the clone." >&2
  exit 1
fi

echo "### 4/4  deploy $CC"
cd "$DEST"
chmod +x deploy.sh
# deploy.sh reads COUNTRY / PROJECT_DIR / ORG_LOGO_URL from the env (defaults
# baked in for local dev). ORG_LOGO_URL stays unset → deploy.sh's own default.
export COUNTRY="$CC" PROJECT_DIR="$DEST"
[[ -n "$ORG_LOGO_URL" ]] && export ORG_LOGO_URL
./deploy.sh
REMOTE

echo
echo "============================================================"
echo " $CC deployed. Open:  http://${SERVER#*@}/"
echo " (the admin password was printed above by deploy.sh — save it.)"
echo
echo " HTTPS: point a domain A-record at the server and front sis-nginx"
echo " with Caddy or certbot (port 443 is already exposed)."
echo "============================================================"
