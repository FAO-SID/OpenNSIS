-- ============================================================================
-- 007_mapset_period_allow_equal.sql
--
-- Allow a mapset time period to be a single instant: begin <= end instead of
-- strictly begin < end. Datasets whose plots all carry one sampling date (the
-- VN cam_hg / cam_vinh CSVs) produce begin = end on the stub mapset, and the
-- strict check made the whole ingest transaction fail on the final metadata
-- update. Per Eloi's decision (2026-08-09): begin = end is acceptable.
--
-- The related mapset_publication_after_period_end_check (publication_date >
-- time_period_end) is left as-is.
--
-- Idempotent: DROP CONSTRAINT IF EXISTS then re-ADD; a re-run recreates the
-- same relaxed constraint.
-- ============================================================================

ALTER TABLE soil_data.mapset
  DROP CONSTRAINT IF EXISTS mapset_period_dates_order_check;
ALTER TABLE soil_data.mapset
  ADD CONSTRAINT mapset_period_dates_order_check
  CHECK (time_period_begin IS NULL OR time_period_end IS NULL
         OR time_period_begin <= time_period_end);
