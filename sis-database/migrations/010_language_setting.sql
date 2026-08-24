-- ============================================================================
-- 010_language_setting.sql
--
-- Seed the LANGUAGE setting (instance default UI language) on existing
-- installs, so it appears in Administration → Settings where it renders as a
-- dropdown of the languages the application ships. New installs are seeded
-- by the deploy scripts; visitors can override via the map's selector.
--
-- Idempotent: ON CONFLICT DO NOTHING.
-- ============================================================================

INSERT INTO api.setting (key, value) VALUES ('LANGUAGE', 'en')
ON CONFLICT (key) DO NOTHING;
