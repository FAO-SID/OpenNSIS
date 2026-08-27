---
name: "🐞 Bug report"
about: Report a defect in a running OpenNSIS node (something behaves incorrectly)
title: "[Bug]: "
labels: bug
assignees: ''
---

<!--
Thanks for helping improve OpenNSIS!

Before opening, please search existing issues to avoid duplicates.

⚠️ Do NOT paste secrets. Redact any .env values (POSTGRES_PASSWORD,
POSTGRES_GLOSIS_PASSWORD, SECRET_KEY, WEB_MAPPING_API_KEY), JWTs and the
GloSIS federation token before pasting logs or config.
-->

## Summary
<!-- A clear and concise description of the bug. -->

## Affected component(s)
<!-- Tick all that apply. -->
- [ ] `sis-web-mapping` (public map view / admin SPA)
- [ ] `sis-api` (auth, ETL, layers, settings, users, admin)
- [ ] `sis-api-glosis` (federation API)
- [ ] `sis-database` (PostgreSQL / PostGIS)
- [ ] `sis-metadata` (pyCSW catalogue)
- [ ] `sis-web-services` (MapServer WMS / WCS)
- [ ] `sis-nginx` (routing / TLS)
- [ ] Not sure

## Steps to reproduce
1.
2.
3.

## Expected behaviour
<!-- What you expected to happen. -->

## Actual behaviour
<!-- What actually happened. Include error messages verbatim. -->

## Screenshots
<!-- If applicable, drag images here (especially helpful for map / SPA issues). -->

## Environment
- OpenNSIS version / commit (`git rev-parse --short HEAD`):
- Deployment layer: <!-- deploy.sh on a dedicated server / ops/single / ops/workshop / local dev -->
- Host OS + version:
- Docker Engine version (`docker --version`):
- Docker Compose version (`docker compose version`):
- Browser + version (for `sis-web-mapping` issues):

## Logs
<!--
Relevant output from `docker compose ps` and
`docker compose logs --tail=200 <service>`. Redact secrets, tokens and
personal data first.
-->

```text
paste logs here
```

## Additional context
<!-- Anything else that helps: recent changes, custom config, data specifics. -->
