-- 015: per-project symbology for soil-profile layers.
--
-- Admins choose how each project's profile points render in the map view:
-- marker shape, size, colour and opacity. Stored on the project's stub
-- mapset ('<CC>-<PROJ>'), like the other per-project presentation policies
-- (profile_limit, spatial_blur_m, locations_only, hide_download).
-- NULLs mean the app defaults (circle, 8 px, auto palette colour, 0.8).

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS marker_shape   text,
  ADD COLUMN IF NOT EXISTS marker_size    real,
  ADD COLUMN IF NOT EXISTS marker_color   text,
  ADD COLUMN IF NOT EXISTS marker_opacity real;
