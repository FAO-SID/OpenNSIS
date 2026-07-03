-- ============================================================================
-- 005_mapset_hide_download.sql
--
-- Per-project "hide download" flag. When set, the map's layer control does not
-- render the per-project profile CSV download icon for that project. Purely a
-- UI affordance: unlike `locations_only`, this does NOT restrict any view — the
-- profile points and observational data still publish exactly as before. The
-- flag is surfaced to the map via /api/profile/blur (hide_download_mapset_ids).
--
-- Idempotent: ADD COLUMN IF NOT EXISTS (no view changes needed).
-- ============================================================================

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS hide_download boolean NOT NULL DEFAULT false;
