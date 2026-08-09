-- ============================================================================
-- 006_plot_profile_code_not_unique.sql
--
-- plot_code / profile_code are real-world labels, not database identifiers —
-- the surrogate keys plot_id / profile_id are the identity of a row. The
-- global UNIQUE constraints on the codes made the ETL ingest upsert on them
-- (ON CONFLICT (plot_code) / (profile_code)), so a CSV whose codes also occur
-- in another project's data silently captured and rewrote *that* project's
-- plots and profiles instead of creating its own. On the Vietnam instance this
-- merged three provincial datasets into the national AFACI profile tree, and
-- they were destroyed with it when the AFACI profiles were deleted.
--
-- Drop the UNIQUE constraints (soil_data.profile carries two redundant ones)
-- and replace them with plain indexes that support the ingest's new
-- site-scoped lookups. The ingest no longer uses ON CONFLICT on the codes.
--
-- Idempotent: DROP CONSTRAINT IF EXISTS / CREATE INDEX IF NOT EXISTS.
-- ============================================================================

ALTER TABLE soil_data.plot    DROP CONSTRAINT IF EXISTS uk_plot_code;
ALTER TABLE soil_data.profile DROP CONSTRAINT IF EXISTS uk_profile_code;
ALTER TABLE soil_data.profile DROP CONSTRAINT IF EXISTS unq_profile_code;

CREATE INDEX IF NOT EXISTS idx_plot_site_id_plot_code
  ON soil_data.plot (site_id, plot_code);
CREATE INDEX IF NOT EXISTS idx_profile_plot_id
  ON soil_data.profile (plot_id);
