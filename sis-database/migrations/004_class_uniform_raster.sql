-- ============================================================================
-- 004_class_uniform_raster.sql
--
-- soil_data.class() crashed on a uniform raster (stats_minimum == stats_maximum,
-- i.e. range = 0) — it RAISEd referencing rec_property.layer_id, a field that
-- record does not have (UndefinedColumn), aborting registration. This hits
-- constant DST outputs. Handle range = 0 by emitting a single class/colour
-- instead of raising. Idempotent (CREATE OR REPLACE).
-- ============================================================================

CREATE OR REPLACE FUNCTION soil_data.class()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  rec_layer RECORD;
  rec_property RECORD;
  range FLOAT;
  interval_size FLOAT;
  current_min FLOAT;
  current_max FLOAT;
  i INT := 1;
  color TEXT;
BEGIN
  SELECT mapset_id, min(stats_minimum) min, max(stats_maximum) max
  INTO rec_layer
  FROM soil_data.layer
  WHERE mapset_id = NEW.mapset_id
  GROUP BY mapset_id;

  SELECT property_type, num_intervals, start_color, end_color
  INTO rec_property
  FROM soil_data.mapped_property
  WHERE mapped_property_id = split_part(NEW.mapset_id,'-',3);

  IF rec_property.property_type = 'quantitative' THEN
    IF rec_property.num_intervals <= 0 THEN
        RAISE EXCEPTION 'Number of intervals must be greater than 0.';
    END IF;
    IF rec_property.start_color NOT LIKE '#______' OR rec_property.end_color NOT LIKE '#______' THEN
        RAISE EXCEPTION 'Colors must be in HEX format (e.g., #F4E7D3).';
    END IF;

    range := rec_layer.max - rec_layer.min;
    DELETE FROM soil_data.class WHERE mapset_id = rec_layer.mapset_id;

    IF range = 0 THEN
        -- Uniform raster (min = max): a single value → one class / one colour.
        -- The old code RAISEd here referencing a non-existent
        -- rec_property.layer_id, which crashed registration for constant
        -- rasters (e.g. some DST outputs).
        INSERT INTO soil_data.class (mapset_id, value, code, "label", color, opacity, publish)
        VALUES (rec_layer.mapset_id,
                COALESCE(rec_layer.min::numeric(30,2), 0),
                COALESCE(rec_layer.min::numeric(30,2), 0) || '',
                COALESCE(rec_layer.min::numeric(30,2), 0) || '',
                soil_data._ramp_color(rec_property.start_color, rec_property.end_color, 1, 1),
                1, 't')
        ON CONFLICT (mapset_id, value) DO UPDATE SET
            code = EXCLUDED.code, label = EXCLUDED.label, color = EXCLUDED.color,
            opacity = EXCLUDED.opacity, publish = EXCLUDED.publish;
        RETURN NEW;
    END IF;

    interval_size := range / rec_property.num_intervals;
    current_min := rec_layer.min;
    current_max := rec_layer.min + interval_size;

    WHILE i <= rec_property.num_intervals LOOP
        -- HSV short-arc ramp (was a linear RGB lerp that muddied green->red).
        color := soil_data._ramp_color(rec_property.start_color, rec_property.end_color,
                                       rec_property.num_intervals, i);

        INSERT INTO soil_data.class (mapset_id, value, code, "label", color, opacity, publish)
        VALUES (rec_layer.mapset_id,
                COALESCE(current_min::numeric(30,2),0),
                COALESCE(current_min::numeric(30,2),0) || ' - ' || COALESCE(current_max::numeric(30,2),0),
                COALESCE(current_min::numeric(30,2),0) || ' - ' || COALESCE(current_max::numeric(30,2),0),
                color, 1, 't')
        ON CONFLICT (mapset_id, value)
        DO UPDATE SET code = EXCLUDED.code, label = EXCLUDED.label,
            color = EXCLUDED.color, opacity = EXCLUDED.opacity, publish = EXCLUDED.publish;

        current_min := current_max;
        current_max := current_max + interval_size;
        i := i + 1;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$
;
