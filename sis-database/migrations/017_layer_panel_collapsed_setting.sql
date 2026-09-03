-- ============================================================================
-- 017_layer_panel_collapsed_setting.sql
--
-- Seed the LAYER_PANEL_COLLAPSED setting: whether the map view's layer panel
-- starts collapsed (just the burger glyph) or expanded. Rendered as a Yes/No
-- dropdown in Administration → Settings. New installs are seeded by the
-- deploy scripts.
--
-- Idempotent: ON CONFLICT DO NOTHING.
-- ============================================================================

INSERT INTO api.setting (key, value) VALUES ('LAYER_PANEL_COLLAPSED', 'false')
ON CONFLICT (key) DO NOTHING;
