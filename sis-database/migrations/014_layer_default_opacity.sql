-- 014: per-layer default opacity for the map view.
--
-- Admins can set the opacity a raster starts with when activated in the map
-- view (the slider still lets visitors change it). NULL means fully opaque.
-- Validated 0-1 by the API.

ALTER TABLE soil_data.layer
  ADD COLUMN IF NOT EXISTS default_opacity real;
