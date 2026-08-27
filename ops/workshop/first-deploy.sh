#!/bin/bash
set -euo pipefail

# ============================================================================
# first-deploy.sh — run from YOUR LAPTOP. Bootstraps a fresh Ubuntu 24.04
# Hetzner box and brings up the FIRST country (the pilot), end to end:
#
#   ssh in → install Docker + Compose → firewall → git clone → deploy BT.
#
# Usage:
#   ops/workshop/first-deploy.sh user@SERVER_IP [CC] [PORT]
#
#   ops/workshop/first-deploy.sh root@203.0.113.10            # BT on 8012 (defaults)
#   ops/workshop/first-deploy.sh root@203.0.113.10 BT 8012
#
# Env:
#   REPO_URL   git URL to clone (default: this repo's origin). For a PRIVATE
#              repo, embed a token, e.g.
#                REPO_URL='https://<GH_PAT>@github.com/FAO-SID/OpenNSIS.git'
#   BRANCH     branch to check out (default: main)
#
# PREREQUISITES (both must be true or the clone is useless):
#   1. The ops/workshop/ layer is COMMITTED and PUSHED to REPO_URL/BRANCH —
#      it is what `deploy-workshop.sh` lives in. (Currently uncommitted.)
#   2. The server can authenticate to REPO_URL (token in the URL, or a deploy
#      key you've added). For a public repo, neither is needed.
#
# After this, the remaining 12 countries are just repeats on the server:
#   ssh user@SERVER_IP
#   for d in "BD 8011" "ID 8013" … ; do  (copy template, deploy)  done
#   (see ops/workshop/README.md for the loop)
# ============================================================================

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 user@SERVER_IP [CC] [PORT]" >&2
  echo "Example: $0 root@203.0.113.10 BT 8012" >&2
  exit 1
fi

SERVER="$1"
CC=$(echo "${2:-BT}" | tr '[:lower:]' '[:upper:]')
PORT="${3:-8012}"
BRANCH="${BRANCH:-main}"
# Default to this checkout's origin if REPO_URL isn't given.
REPO_URL="${REPO_URL:-$(git -C "$(dirname "${BASH_SOURCE[0]}")/../.." config --get remote.origin.url 2>/dev/null || echo '')}"

if [[ -z "$REPO_URL" ]]; then
  echo "ERROR: no REPO_URL given and no git origin found. Set REPO_URL=…" >&2
  exit 1
fi

echo "============================================================"
echo " Target server : $SERVER"
echo " Repo / branch : $REPO_URL  ($BRANCH)"
echo " Pilot country : $CC  →  http://<IP>:$PORT/"
echo "============================================================"
echo "Reminder: ops/workshop/ must be pushed to $BRANCH, and the server must"
echo "be able to auth to the repo. Press Ctrl-C now if not. Continuing in 4s…"
sleep 4

# All the on-server work, run over a single SSH session. The remote script
# reads CC/PORT/REPO_URL/BRANCH from the env set on the ssh command line.
ssh -o StrictHostKeyChecking=accept-new "$SERVER" \
  "CC='$CC' PORT='$PORT' REPO_URL='$REPO_URL' BRANCH='$BRANCH' bash -s" <<'REMOTE'
set -euo pipefail
cc_lower=$(echo "$CC" | tr '[:upper:]' '[:lower:]')

echo "### 1/5  apt + Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl git ufw
  curl -fsSL https://get.docker.com | sh        # installs docker-ce + compose plugin
else
  echo "docker already present: $(docker --version)"
  apt-get install -y git ufw >/dev/null 2>&1 || true
fi
docker compose version

echo "### 2/5  firewall (ufw): SSH + workshop ports 8011-8023"
ufw allow 22/tcp           >/dev/null 2>&1 || true
ufw allow 8011:8023/tcp    >/dev/null 2>&1 || true   # one port per country
ufw allow 80/tcp           >/dev/null 2>&1 || true   # optional landing page
yes | ufw enable           >/dev/null 2>&1 || true
ufw status verbose || true

echo "### 3/5  clone repo → /opt/sis-template ($BRANCH)"
mkdir -p /opt
if [[ -d /opt/sis-template/.git ]]; then
  git -C /opt/sis-template fetch --depth 1 origin "$BRANCH"
  git -C /opt/sis-template checkout -f "$BRANCH"
  git -C /opt/sis-template reset --hard "origin/$BRANCH"
else
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" /opt/sis-template
fi

if [[ ! -x /opt/sis-template/ops/workshop/deploy-workshop.sh ]]; then
  echo "ERROR: ops/workshop/deploy-workshop.sh not found in the clone." >&2
  echo "       The ops/workshop layer isn't on $BRANCH yet — commit & push it." >&2
  exit 1
fi

echo "### 4/5  materialise /opt/sis-$cc_lower from the template"
rm -rf "/opt/sis-$cc_lower"
cp -r /opt/sis-template "/opt/sis-$cc_lower"

echo "### 5/5  deploy $CC on port $PORT"
cd "/opt/sis-$cc_lower"
ops/workshop/deploy-workshop.sh "$CC" "$PORT"
REMOTE

echo
echo "============================================================"
echo " Pilot $CC deployed. Open:  http://${SERVER#*@}:$PORT/"
echo " (the admin password was printed above by deploy-workshop.sh)"
echo
echo " Next countries — on the server, repeat per row:"
echo "   ssh $SERVER"
echo "   cp -r /opt/sis-template /opt/sis-<cc> && cd /opt/sis-<cc> \\"
echo "     && ops/workshop/deploy-workshop.sh <CC> <PORT>"
echo " Port table: ops/workshop/README.md"
echo "============================================================"
