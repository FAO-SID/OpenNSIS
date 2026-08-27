---
name: "🚀 Deployment & operations"
about: Problems installing, updating or running a node (Docker, deploy.sh, ops, TLS)
title: "[Deploy]: "
labels: deployment
assignees: ''
---

<!--
Use this for install / update / runtime problems of a node — as opposed to a
defect in application behaviour (use the Bug report for that).

⚠️ Never paste secrets. .env holds POSTGRES_PASSWORD, POSTGRES_GLOSIS_PASSWORD,
SECRET_KEY, WEB_MAPPING_API_KEY and (if enabled) the GloSIS federation token.
Redact them, along with any JWTs, before pasting logs or config.
-->

## What were you doing?
<!-- Tick all that apply. -->
- [ ] First deploy (`./deploy.sh`)
- [ ] Remote first deploy (`ops/single/first-deploy.sh user@SERVER <CC>`)
- [ ] Workshop / multi-country host (`ops/workshop/deploy-workshop.sh <CC> <PORT>`)
- [ ] Update (`./update.sh`)
- [ ] Enabling HTTPS / Caddy (TLS profile)
- [ ] Other:

## What happened?
<!-- Describe the failure. Include the exact error output. -->

## Command
```bash
# the exact command(s) you ran
```

## Environment
- OpenNSIS version / commit (`git rev-parse --short HEAD`):
- Host OS + version:
- Docker Engine version (`docker --version`):
- Docker Compose version (`docker compose version`):
- Deployment layer: <!-- single dedicated server / ops/single / ops/workshop -->
- Domain / TLS (Caddy profile) involved? yes / no

## Container status
<!-- Output of `docker compose ps`. -->
```text
paste here
```

## Logs
<!--
`docker compose logs --tail=200 <service>` for the failing service
(sis-database is a common culprit on first deploy). Redact secrets.
-->
```text
paste logs here
```

## Relevant .env keys (values redacted)
<!-- e.g. COUNTRY=KH, DOMAIN=..., COMPOSE_PROFILES=tls — NEVER include secret values. -->

## Additional context
<!-- Firewall, ports 80/443 already in use, proxy/CDN, disk space, etc. -->
