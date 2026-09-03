-- 018: admin-defined ordering for map-view layer lists.
--
-- display_order (lower first, NULL last) on:
--   * soil_data.layer  — raster layers, ordered within the Maps panel;
--   * soil_data.mapset — soil-profile projects (stub mapsets), ordering the
--     Soil profiles panel.
-- Same convention as admin_division.display_order.

ALTER TABLE soil_data.layer
  ADD COLUMN IF NOT EXISTS display_order integer;

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS display_order integer;
