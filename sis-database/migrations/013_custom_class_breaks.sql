-- 013: custom class breaks for quantitative rasters.
--
-- Uniform intervals drown the spatial pattern when values are skewed (most
-- of the map lands in one class). A mapset can now opt into CUSTOM breaks:
--   * soil_data.mapset.custom_classes = TRUE marks the mapset as hand-classed;
--   * soil_data.class rows are then authoritative — value is the LOWER BOUND
--     of each interval, with its own colour and label;
--   * soil_data.class() stops regenerating rows for such mapsets;
--   * soil_data.map() renders one flat-colour STYLE per interval (the next
--     row's value closes each interval; the last runs to the layer maximum).
-- The admin legend editor writes the rows and toggles the flag.

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS custom_classes boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION soil_data.class() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  rec_layer RECORD;
  rec_property RECORD;
  range FLOAT;
  interval_size FLOAT;
  current_min FLOAT;
  current_max FLOAT;
  i INT := 1;
  color TEXT;
  v_custom BOOLEAN := FALSE;
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

  SELECT COALESCE(m.custom_classes, FALSE) INTO v_custom
  FROM soil_data.mapset m WHERE m.mapset_id = NEW.mapset_id;

  -- Custom class breaks: the admin's rows ARE the legend — never regenerate.
  IF v_custom THEN
    RETURN NEW;
  END IF;

  IF rec_property.property_type = 'quantitative' THEN
    IF rec_property.num_intervals <= 0 THEN
        RAISE EXCEPTION 'Number of intervals must be greater than 0.';
    END IF;
    IF rec_property.start_color NOT LIKE '#______' OR rec_property.end_color NOT LIKE '#______' THEN
        RAISE EXCEPTION 'Colors must be in HEX format (e.g., #F4E7D3).';
    END IF;

    range := rec_layer.max - rec_layer.min;
    IF range = 0 THEN
        RAISE EXCEPTION 'Range is 0. Cannot create intervals for layer_id %.', rec_property.layer_id;
    END IF;
    interval_size := range / rec_property.num_intervals;
    current_min := rec_layer.min;
    current_max := rec_layer.min + interval_size;

    DELETE FROM soil_data.class WHERE mapset_id = rec_layer.mapset_id;

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
$$;

CREATE OR REPLACE FUNCTION soil_data.map() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  rec_layer RECORD;
  rec_property RECORD;
  n INT;
  v_min FLOAT; v_max FLOAT; step FLOAT;
  styles TEXT := '';
  k INT; c_lo TEXT; c_hi TEXT; d_lo FLOAT; d_hi FLOAT;
  tol_m INT;
  cell_m FLOAT;
  rec_cls RECORD;
  n_cls INT;
  v_mapset TEXT;
  v_custom BOOLEAN := FALSE;
  d_next FLOAT;
BEGIN
  SELECT l.layer_id,
    CASE
      WHEN l.distance_uom='m'   THEN 'METERS'
      WHEN l.distance_uom='km'  THEN 'KILOMETERS'
      WHEN l.distance_uom='deg' THEN 'DD'
    END distance_uom,
    l.reference_system_identifier_code,
    l.extent, l.file_extension, l.stats_minimum, l.stats_maximum,
    l.distance AS cell_size, l.distance_uom AS cell_uom,
    l.mapset_id
  INTO rec_layer
  FROM soil_data.layer l
  WHERE l.layer_id = NEW.layer_id;

  SELECT p.start_color, p.end_color, COALESCE(p.num_intervals, 10) AS num_intervals,
         p.property_type
  INTO rec_property
  FROM soil_data.layer l
  JOIN soil_data.mapset m         ON m.mapset_id = l.mapset_id
  JOIN soil_data.mapped_property p ON p.mapped_property_id = m.mapped_property_id
  WHERE l.layer_id = NEW.layer_id;

  -- Query tolerance: one native cell, expressed in metres (floor 100 m,
  -- default 1000 m when the resolution is unknown). layer.distance is TEXT —
  -- cast defensively.
  cell_m := CASE WHEN rec_layer.cell_size ~ '^[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$'
                 THEN rec_layer.cell_size::float END;
  tol_m := COALESCE(CEIL(GREATEST(
             CASE rec_layer.cell_uom
               WHEN 'deg' THEN cell_m * 111320
               WHEN 'km'  THEN cell_m * 1000
               ELSE            cell_m
             END, 100)), 1000);

  n := GREATEST(rec_property.num_intervals, 2);
  v_min := rec_layer.stats_minimum;
  v_max := rec_layer.stats_maximum;
  v_mapset := rec_layer.mapset_id;

  SELECT count(*) INTO n_cls
  FROM soil_data.class WHERE mapset_id = v_mapset AND publish IS TRUE;

  SELECT COALESCE(m.custom_classes, FALSE) INTO v_custom
  FROM soil_data.mapset m WHERE m.mapset_id = v_mapset;

  IF rec_property.property_type = 'categorical' AND n_cls BETWEEN 1 AND 60 THEN
    -- Categorical: one flat-colour STYLE per class value, driven by
    -- soil_data.class — the rows the SLD and the web legend already use, so
    -- editing a class colour recolours everything coherently. (Ramps make no
    -- sense for categories; >60 classes falls back to the ramp below.)
    FOR rec_cls IN SELECT value, color FROM soil_data.class
                   WHERE mapset_id = v_mapset AND publish IS TRUE
                   ORDER BY value LOOP
      styles := styles || 'STYLE
              COLORRANGE "'||rec_cls.color||'" "'||rec_cls.color||'"
              DATARANGE '||(rec_cls.value - 0.5)||' '||(rec_cls.value + 0.5)||'
              RANGEITEM "pixel"
            END # STYLE
            ';
    END LOOP;
  ELSIF v_custom AND n_cls BETWEEN 2 AND 60 THEN
    -- Custom class breaks (quantitative): each class row's value is the
    -- LOWER BOUND of its interval; the next row's value closes it, and the
    -- last interval runs to the layer maximum. Flat colour per interval —
    -- QGIS-style classed rendering with arbitrary (non-uniform) breaks.
    FOR rec_cls IN SELECT value, color,
                          LEAD(value) OVER (ORDER BY value) AS next_value
                   FROM soil_data.class
                   WHERE mapset_id = v_mapset AND publish IS TRUE
                   ORDER BY value LOOP
      d_next := COALESCE(rec_cls.next_value::float,
                         GREATEST(COALESCE(v_max, rec_cls.value + 1), rec_cls.value + 0.000001));
      styles := styles || 'STYLE
              COLORRANGE "'||rec_cls.color||'" "'||rec_cls.color||'"
              DATARANGE '||rec_cls.value||' '||d_next||'
              RANGEITEM "pixel"
            END # STYLE
            ';
    END LOOP;
  ELSIF v_min IS NULL OR v_max IS NULL OR v_max <= v_min THEN
    styles := 'STYLE
              COLORRANGE "'||rec_property.start_color||'" "'||rec_property.end_color||'"
              DATARANGE '||COALESCE(v_min,0)||' '||COALESCE(NULLIF(v_max,v_min),COALESCE(v_min,0)+1)||'
              RANGEITEM "pixel"
            END # STYLE';
  ELSE
    step := (v_max - v_min) / n;
    FOR k IN 1..n LOOP
      c_lo := soil_data._ramp_color(rec_property.start_color, rec_property.end_color, n+1, k);
      c_hi := soil_data._ramp_color(rec_property.start_color, rec_property.end_color, n+1, k+1);
      d_lo := v_min + (k-1)*step;
      d_hi := v_min + k*step;
      styles := styles || 'STYLE
              COLORRANGE "'||c_lo||'" "'||c_hi||'"
              DATARANGE '||d_lo||' '||d_hi||'
              RANGEITEM "pixel"
            END # STYLE
            ';
    END LOOP;
  END IF;

  UPDATE soil_data.layer l SET map = 'MAP
  NAME "'||rec_layer.layer_id||'"
  EXTENT '||rec_layer.extent||'
  UNITS '||rec_layer.distance_uom||'
  SHAPEPATH "./"
  SIZE 800 600
  IMAGETYPE "PNG24"
  PROJECTION
      "init=epsg:'||rec_layer.reference_system_identifier_code||'"
  END # PROJECTION
  WEB
      METADATA
          "ows_title" "'||rec_layer.layer_id||' web-service"
          "ows_enable_request" "*"
          "ows_srs" "EPSG:'||rec_layer.reference_system_identifier_code||' EPSG:4326 EPSG:3857"
          "wms_getfeatureinfo_formatlist" "text/plain,text/html,application/json,geojson,application/vnd.ogc.gml,gml"
          "wms_feature_info_mime_type" "application/json"
      END # METADATA
  END # WEB
  LAYER
      TEMPLATE "getfeatureinfo.tmpl"
      NAME "'||rec_layer.layer_id||'"
      DATA "'||rec_layer.layer_id||'.'||rec_layer.file_extension||'"
      TYPE RASTER
      TOLERANCE '||tol_m||'
      TOLERANCEUNITS METERS
      STATUS ON
      METADATA
        "wms_include_items" "all"
        "gml_include_items" "all"
      END # METADATA
      CLASS
        NAME "'||rec_layer.layer_id||'"
        '||styles||'
      END # CLASS
  END # LAYER
END # MAP'
  WHERE l.layer_id = NEW.layer_id;

  RETURN NEW;
END
$$;



-- Refresh the stored .map text of every existing raster layer.
UPDATE soil_data.layer
   SET stats_minimum = stats_minimum
 WHERE map IS NOT NULL;
