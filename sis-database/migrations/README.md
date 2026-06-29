# Database migrations

Incremental, **idempotent** SQL applied to a *live* database by the repo-root
`update.sh`, so countries can update an installed SIS without wiping the data
they uploaded.

This is the in-place counterpart to the full seed dump
(`sis-database/sis-database_latest_with_codelist.sql`): the dump is what a
*fresh* install loads once; migrations are how an *existing* install moves
forward without reloading (and thus erasing) its data.

## How it works

`update.sh` keeps a ledger table:

```sql
api.schema_migration (filename text primary key, applied_at timestamptz)
```

On each run it applies every `sis-database/migrations/NNN_*.sql` not yet in that
table, in **filename order** (by basename), each inside a single transaction
together with its bookkeeping insert. A failure rolls the whole file back and
records nothing, so re-running is safe.

## Writing a migration

1. Create the next number: `002_short_description.sql`, `003_…`, …
   Numbers are zero-padded and define the apply order — never renumber an
   existing one, and never edit a migration that may already be applied
   somewhere; add a new one instead.
2. Make it **idempotent and transaction-safe** so a re-run (or a fresh install
   that already has the change from the dump) is a harmless no-op:
   - `CREATE OR REPLACE FUNCTION/VIEW …`
   - `ALTER TABLE … ADD COLUMN IF NOT EXISTS …`
   - `CREATE TABLE/INDEX IF NOT EXISTS …`
   - `INSERT … ON CONFLICT DO NOTHING`
   - Avoid statements that can't run inside a transaction (e.g.
     `CREATE INDEX CONCURRENTLY`, some `ALTER TYPE … ADD VALUE`). If you truly
     need one, flag it — the runner uses `--single-transaction`.
3. Keep the dump in sync: also fold the change into the seed dump so fresh
   installs get it directly. (A migration then just converges older installs.)
4. Test: `./update.sh` applies it; run again — it should report `skip`.

## Scope

Migrations cover **schema, views, functions/triggers, and reference-data**
changes. They do **not** rebuild application code (that's `update.sh` doing
`up --build` on the app containers) and do **not** upgrade the Postgres / pyCSW /
MapServer base images (a deliberate manual step, with care, because of the data
volumes).

## History

- `001_hsv_colour_ramp.sql` — HSV colour-ramp triggers (`soil_data.class`,
  `soil_data.map`, `soil_data._ramp_color`); also fixes `map()`'s
  mapped_property join. Idempotent; already in fresh dumps.
- `002_vw_api_profile_mapset_id.sql` — `api.vw_api_profile` exposes `mapset_id`
  (DROP + CREATE, no dependents). Idempotent; already in fresh dumps.
