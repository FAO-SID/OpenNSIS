-- ============================================================================
-- 009_admin_division_stroke_type.sql
--
-- Stroke type for administrative division layers: continuous (solid),
-- dashed, dotted or dash-dot outlines, editable alongside the other
-- symbology fields. Values are validated in the API.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS.
-- ============================================================================

ALTER TABLE api.admin_division
  ADD COLUMN IF NOT EXISTS stroke_type text NOT NULL DEFAULT 'solid';
