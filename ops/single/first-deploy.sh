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
#   ops/single/first-deploy.sh user@SERVER_IP[:SSH_PORT] <CC> [ORG_LOGO_URL]
#
#   ops/single/first-deploy.sh root@76.13.194.80 ID
#   ops/single/first-deploy.sh vdsuser@195.38.164.187:43816 KG     # custom SSH port
#   ops/single/first-deploy.sh root@203.0.113.10 PH https://example.org/logo.png
#
# Non-root SSH users are fine — privileged steps run via sudo (passwordless
# sudo required, as on most VPS images).
#
# Env:
#   REPO_URL   git URL to clone (default: this repo's origin). For a PRIVATE
#              repo embed a token: REPO_URL='https://<PAT>@github.com/FAO-SID/SIS-dev.git'
#   BRANCH     branch to check out (default: main)
#   DEST       server install dir (default: /opt/sis)
#   SSH_PORT   ssh port (default: parsed from user@host:port, else 22)
#
# The SPA is built with relative URLs (the compose default), so the site works
# over the server's bare IP or a domain with no edits. Re-running wipes the DB
# volume and re-seeds from the dump — same as deploy.sh itself.
# ============================================================================

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 user@SERVER_IP[:SSH_PORT] <CC> [ORG_LOGO_URL]" >&2
  echo "Example: $0 root@203.0.113.10 NP" >&2
  echo "         $0 vdsuser@195.38.164.187:43816 KG   # custom ssh port" >&2
  exit 1
fi

# Accept user@host or user@host:port. ssh needs `-p PORT host`, not host:port.
RAW="$1"
if [[ "$RAW" == *:* ]]; then
  SSH_TARGET="${RAW%:*}"             # user@host
  SSH_PORT="${SSH_PORT:-${RAW##*:}}" # the trailing :port
else
  SSH_TARGET="$RAW"
  SSH_PORT="${SSH_PORT:-22}"
fi
HOST_ONLY="${SSH_TARGET#*@}"         # host alone, for the browser URL (web is :80)

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
echo " Target server : $SSH_TARGET   (ssh port $SSH_PORT)"
echo " Repo / branch : $REPO_URL  ($BRANCH)"
echo " Country       : $CC   →   http://$HOST_ONLY/  (nginx :80)"
echo " Install dir   : $DEST"
echo "============================================================"
echo "Press Ctrl-C now if that's wrong. Continuing in 5s…"
sleep 5

# All on-server work over a single SSH session. The remote reads the vars from
# the env we set on the ssh command line.
ssh -p "$SSH_PORT" -o StrictHostKeyChecking=accept-new "$SSH_TARGET" \
  "CC='$CC' ORG_LOGO_URL='$ORG_LOGO_URL' REPO_URL='$REPO_URL' BRANCH='$BRANCH' DEST='$DEST' SSH_PORT='$SSH_PORT' bash -s" <<'REMOTE'
set -euo pipefail

# Run privileged steps via sudo when the SSH user isn't root.
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "### 1/4  apt + Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl git ufw
  curl -fsSL https://get.docker.com | $SUDO sh    # docker-ce + compose plugin (uses sudo)
else
  echo "docker already present: $($SUDO docker --version)"
  $SUDO apt-get install -y git ufw >/dev/null 2>&1 || true
fi
$SUDO docker compose version

echo "### 2/4  firewall (ufw): ssh ($SSH_PORT) + http + https"
$SUDO ufw allow 22/tcp           >/dev/null 2>&1 || true
$SUDO ufw allow "${SSH_PORT}/tcp" >/dev/null 2>&1 || true   # don't lock ourselves out
$SUDO ufw allow 80/tcp           >/dev/null 2>&1 || true
$SUDO ufw allow 443/tcp          >/dev/null 2>&1 || true
yes | $SUDO ufw enable           >/dev/null 2>&1 || true
$SUDO ufw status verbose || true

echo "### 3/4  clone repo → $DEST ($BRANCH)"
$SUDO mkdir -p "$(dirname "$DEST")"
if $SUDO test -d "$DEST/.git"; then
  $SUDO git -C "$DEST" fetch --depth 1 origin "$BRANCH"
  $SUDO git -C "$DEST" checkout -f "$BRANCH"
  $SUDO git -C "$DEST" reset --hard "origin/$BRANCH"
else
  $SUDO git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

if ! $SUDO test -f "$DEST/deploy.sh"; then
  echo "ERROR: deploy.sh not found in the clone." >&2
  exit 1
fi

echo "### 4/4  deploy $CC"
cd "$DEST"
$SUDO chmod +x deploy.sh
# deploy.sh reads COUNTRY / PROJECT_DIR / ORG_LOGO_URL from the env (defaults
# baked in for local dev). Run it as root so docker works without a docker-group
# re-login; -E carries the exported vars into root's environment.
export COUNTRY="$CC" PROJECT_DIR="$DEST"
[ -n "$ORG_LOGO_URL" ] && export ORG_LOGO_URL
if [ -n "$SUDO" ]; then
  $SUDO -E ./deploy.sh
else
  ./deploy.sh
fi
REMOTE

echo
echo "============================================================"
echo " $CC deployed. Open:  http://$HOST_ONLY/"
echo " (the admin password was printed above by deploy.sh — save it.)"
echo
echo " HTTPS: point a domain A-record at the server and front sis-nginx"
echo " with Caddy or certbot (port 443 is already exposed)."
echo "============================================================"
