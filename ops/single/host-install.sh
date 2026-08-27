#!/bin/bash
set -euo pipefail

# ============================================================================
# ops/single/host-install.sh — run ON THE SERVER where the SIS will live.
# The on-host twin of first-deploy.sh (which drives the same steps over SSH
# from your laptop). Use this one when the person installing IS at the server
# — a country's own admin, a VM console, a box we have no SSH access to.
#
#   install Docker + Compose → firewall → git clone → ./deploy.sh
#
# One country per server, nginx on :80 — the BASE deployment
# (docker-compose.yml + deploy.sh), NOT the workshop multi-country layer.
#
# Usage (on the server, as root or a sudo-capable user):
#
#   # without the repo yet — fetch and run in one line:
#   curl -fsSL https://raw.githubusercontent.com/FAO-SID/OpenNSIS/main/ops/single/host-install.sh | sudo bash -s -- ID
#
#   # or from an existing checkout:
#   sudo ops/single/host-install.sh ID
#   sudo ops/single/host-install.sh PH https://example.org/logo.png
#
# Env knobs (export before running, or prefix the command):
#   REPO_URL   git URL to clone (default: the repo this script sits in, else
#              the public GitHub repo). For a PRIVATE repo embed a token:
#              REPO_URL='https://<PAT>@github.com/FAO-SID/OpenNSIS.git'
#   BRANCH     branch to check out             (default: main)
#   DEST       install dir                     (default: /opt/sis, or the
#              checkout this script is run from)
#   LANGUAGE   default UI language, e.g. pt    (default: en)
#   DOMAIN     e.g. sis.example.org — enables automatic HTTPS via the Caddy
#              front (deploy.sh writes the tls profile into .env). Point the
#              domain's A-record at this server FIRST.
#
# Re-running wipes the DB volume and re-seeds from the dump — same as
# deploy.sh itself. The admin password is printed ONCE at the end — save it.
# ============================================================================

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <CC> [ORG_LOGO_URL]" >&2
  echo "Example: sudo $0 NP" >&2
  echo "         LANGUAGE=pt DOMAIN=sis.example.org sudo -E $0 BR" >&2
  exit 1
fi

CC=$(echo "$1" | tr '[:lower:]' '[:upper:]')          # ISO 3166-1 alpha-2
ORG_LOGO_URL="${2:-}"
BRANCH="${BRANCH:-main}"

# Run privileged steps via sudo when not root (passwordless sudo, as on most
# VPS images). Everything below needs root: apt, ufw, docker, /opt.
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# DEST: an explicit env wins; else, if this script is being run from inside a
# checkout (not curl-piped), install into that checkout; else /opt/sis.
if [[ -z "${DEST:-}" ]]; then
  DEST="/opt/sis"
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    [[ -f "$SELF_ROOT/deploy.sh" ]] && DEST="$SELF_ROOT"
  fi
fi

REPO_URL="${REPO_URL:-$(git -C "$DEST" config --get remote.origin.url 2>/dev/null \
  || echo 'https://github.com/FAO-SID/OpenNSIS.git')}"

echo "============================================================"
echo " This server   : $(hostname) ($(hostname -I 2>/dev/null | awk '{print $1}'))"
echo " Repo / branch : $REPO_URL  ($BRANCH)"
echo " Country       : $CC"
echo " Install dir   : $DEST"
echo " UI language   : ${LANGUAGE:-en}"
[ -n "${DOMAIN:-}" ] && echo " HTTPS domain  : $DOMAIN  (A-record must already point here)"
echo "============================================================"
echo "Re-running on an existing install WIPES the database."
echo "Press Ctrl-C now if that's wrong. Continuing in 5s…"
sleep 5

echo "### 1/4  apt + Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl git ufw
  curl -fsSL https://get.docker.com | $SUDO sh    # docker-ce + compose plugin
else
  echo "docker already present: $($SUDO docker --version)"
  $SUDO apt-get install -y git ufw >/dev/null 2>&1 || true
fi
$SUDO docker compose version

echo "### 2/4  firewall (ufw): ssh + http + https"
# Allow every port sshd actually listens on, not just 22 — enabling ufw over
# an SSH session on a custom port must not lock the admin out.
SSH_PORTS=$($SUDO sshd -T 2>/dev/null | awk '/^port /{print $2}' || true)
for p in 22 ${SSH_PORTS:-}; do
  $SUDO ufw allow "${p}/tcp" >/dev/null 2>&1 || true
done
$SUDO ufw allow 80/tcp  >/dev/null 2>&1 || true
$SUDO ufw allow 443/tcp >/dev/null 2>&1 || true
yes | $SUDO ufw enable  >/dev/null 2>&1 || true
$SUDO ufw status verbose || true

echo "### 3/4  repo → $DEST ($BRANCH)"
$SUDO mkdir -p "$(dirname "$DEST")"
if $SUDO test -d "$DEST/.git"; then
  $SUDO git -C "$DEST" fetch origin "$BRANCH"
  $SUDO git -C "$DEST" checkout -f "$BRANCH"
  $SUDO git -C "$DEST" reset --hard "origin/$BRANCH"
else
  $SUDO git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

if ! $SUDO test -f "$DEST/deploy.sh"; then
  echo "ERROR: deploy.sh not found in $DEST." >&2
  exit 1
fi

echo "### 4/4  deploy $CC"
cd "$DEST"
$SUDO chmod +x deploy.sh
# deploy.sh reads COUNTRY / PROJECT_DIR / LANGUAGE / ORG_LOGO_URL / DOMAIN
# from the env. Run as root so docker works without a docker-group re-login;
# -E carries the exported vars into root's environment.
export COUNTRY="$CC" PROJECT_DIR="$DEST"
[ -n "${LANGUAGE:-}" ]     && export LANGUAGE
[ -n "${DOMAIN:-}" ]       && export DOMAIN
[ -n "$ORG_LOGO_URL" ]     && export ORG_LOGO_URL
if [ -n "$SUDO" ]; then
  $SUDO -E ./deploy.sh
else
  ./deploy.sh
fi

HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "============================================================"
if [ -n "${DOMAIN:-}" ]; then
  echo " $CC deployed. Open:  https://$DOMAIN/"
  echo " (the certificate is issued on the first request — allow a moment.)"
else
  echo " $CC deployed. Open:  http://${HOST_IP:-<this-server>}/"
  echo
  echo " HTTPS later: point a domain A-record at this server, add the"
  echo " DOMAIN/tls lines to .env and run 'docker compose up -d' — see the"
  echo " README's 'Enabling HTTPS'. Do NOT re-run deploy.sh (it wipes the DB)."
fi
echo " (the admin password was printed above by deploy.sh — save it.)"
echo "============================================================"
