# Single-country deploy (one server, one country)

The standard production shape: **one country per server**, served by nginx on
`:80`, using the repo's base `docker-compose.yml` + `deploy.sh` (default
container names, no workshop override).

This is the opposite of `ops/workshop/`, which packs many countries onto one
host on distinct ports.

## One command (from your laptop)

```bash
ops/single/first-deploy.sh root@SERVER_IP NP
#                          └ ssh target  └ ISO 3166-1 alpha-2
```

SSHes in, installs Docker + Compose, opens the firewall (22/80/443), clones the
repo to `/opt/sis`, and runs `deploy.sh` with `COUNTRY=NP`. The admin password
is printed at the end — save it.

Optional 3rd arg: a logo URL (`ORG_LOGO_URL`). Env knobs: `REPO_URL`, `BRANCH`,
`DEST` (install dir, default `/opt/sis`).

## One command (on the server itself)

When the person installing is at the server — a country's own admin, a box we
have no SSH access to — the same steps run locally via `host-install.sh`:

```bash
# without the repo yet — fetch and run in one line:
curl -fsSL https://raw.githubusercontent.com/FAO-SID/SIS-dev/main/ops/single/host-install.sh | sudo bash -s -- ID

# or from an existing checkout:
sudo ops/single/host-install.sh ID
```

Same sequence (Docker + Compose, firewall, clone to `/opt/sis`, `deploy.sh`)
and the same knobs (`REPO_URL`, `BRANCH`, `DEST`, 2nd arg = logo URL), plus:

- `LANGUAGE=pt` — default UI language for the instance.
- `DOMAIN=sis.example.org` — automatic HTTPS via the Caddy front (point the
  A-record at the server first).

```bash
LANGUAGE=pt DOMAIN=sis.example.org sudo -E ops/single/host-install.sh BR
```

The firewall step allows every port `sshd` listens on (not just 22), so
enabling `ufw` over an SSH session on a custom port won't lock the admin out.

## Or by hand

```bash
# on the server
curl -fsSL https://get.docker.com | sh
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && yes | ufw enable
git clone https://github.com/FAO-SID/SIS-dev.git /opt/sis && cd /opt/sis
COUNTRY=NP PROJECT_DIR=/opt/sis ./deploy.sh
```

`COUNTRY`, `PROJECT_DIR`, and `ORG_LOGO_URL` are read from the environment
(defaults baked in for local dev), so no need to edit `deploy.sh`.

## Notes

- **Relative URLs**: the SPA is built with `API_URL=""` / `MAPSERVER_URL=/mapserver`
  (the compose default), so it calls its own origin — works on a bare IP or a
  domain, http or https, with no rebuild. Override via `.env` only if the API /
  MapServer live on a different origin.
- **Fresh + empty**: the instance starts with codelists but no demo projects;
  the country adds its own rasters/profiles through the admin UI.
- **Re-running `deploy.sh` wipes the DB volume** and re-seeds from the dump.
- **HTTPS**: point a domain at the server and front `sis-nginx` with Caddy or
  nginx + certbot (`:443` is already exposed).
- **Migrating a workshop country to its own box** instead of a fresh deploy?
  See `ops/workshop/README.md` → *Graduation* (rsync the `/opt/sis-<cc>/`
  volumes, then run the base `./deploy.sh`).
