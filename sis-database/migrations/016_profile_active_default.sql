-- 016: soil-profile layers can be published but not active by default.
--
-- active_default = FALSE keeps the project's checkbox unticked when the map
-- view loads (data stays published and downloadable; visitors can tick it).
-- NULL means TRUE (current behaviour).

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS active_default boolean;
