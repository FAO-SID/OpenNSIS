-- Colour-ramp interpolation through HSV (hue) instead of linear RGB.
--
-- soil_data.class() built each bucket colour by lerping start_color → end_color
-- linearly in RGB. Between two distant hues (green → red) that path runs
-- straight through muddy brown/olive at the midpoint. Rotating the hue along
-- the short arc instead passes green → yellow → orange → red — a clean
-- RdYlGn-style suitability ramp. For nearby hues (the tan → brown soil ramps)
-- the short-arc path is tiny, so those ramps render essentially unchanged.
--
-- All the colour maths lives in a small, independently-testable helper; class()
-- changes by exactly one line (the per-bucket colour computation).

-- bucket colour i (1..n) of an n-step ramp from start_hex to end_hex, via HSV.
CREATE OR REPLACE FUNCTION soil_data._ramp_color(start_hex text, end_hex text, n int, i int)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  sr FLOAT; sg FLOAT; sb FLOAT; er FLOAT; eg FLOAT; eb FLOAT;
  smx FLOAT; smn FLOAT; sd FLOAT; emx FLOAT; emn FLOAT; ed FLOAT;
  sh FLOAT; ss FLOAT; sv FLOAT; eh FLOAT; es FLOAT; ev FLOAT;
  t FLOAT; dh FLOAT; h FLOAT; s FLOAT; v FLOAT;
  c FLOAT; x FLOAT; m FLOAT; rp FLOAT; gp FLOAT; bp FLOAT;
  cr INT; cg INT; cb INT;
BEGIN
  -- hex -> rgb (0..1)
  sr := (('x'||SUBSTRING(start_hex FROM 2 FOR 2))::BIT(8)::INT)/255.0;
  sg := (('x'||SUBSTRING(start_hex FROM 4 FOR 2))::BIT(8)::INT)/255.0;
  sb := (('x'||SUBSTRING(start_hex FROM 6 FOR 2))::BIT(8)::INT)/255.0;
  er := (('x'||SUBSTRING(end_hex   FROM 2 FOR 2))::BIT(8)::INT)/255.0;
  eg := (('x'||SUBSTRING(end_hex   FROM 4 FOR 2))::BIT(8)::INT)/255.0;
  eb := (('x'||SUBSTRING(end_hex   FROM 6 FOR 2))::BIT(8)::INT)/255.0;

  -- rgb -> hsv (start)
  smx := GREATEST(sr,sg,sb); smn := LEAST(sr,sg,sb); sd := smx - smn;
  sv := smx; ss := CASE WHEN smx = 0 THEN 0 ELSE sd/smx END;
  IF sd = 0 THEN sh := 0;
  ELSIF smx = sr THEN sh := 60 * (((sg - sb)/sd)::numeric % 6);
  ELSIF smx = sg THEN sh := 60 * (((sb - sr)/sd) + 2);
  ELSE                sh := 60 * (((sr - sg)/sd) + 4);
  END IF;
  IF sh < 0 THEN sh := sh + 360; END IF;

  -- rgb -> hsv (end)
  emx := GREATEST(er,eg,eb); emn := LEAST(er,eg,eb); ed := emx - emn;
  ev := emx; es := CASE WHEN emx = 0 THEN 0 ELSE ed/emx END;
  IF ed = 0 THEN eh := 0;
  ELSIF emx = er THEN eh := 60 * (((eg - eb)/ed)::numeric % 6);
  ELSIF emx = eg THEN eh := 60 * (((eb - er)/ed) + 2);
  ELSE                eh := 60 * (((er - eg)/ed) + 4);
  END IF;
  IF eh < 0 THEN eh := eh + 360; END IF;

  -- short-arc hue interpolation so green->red rotates through yellow, not magenta
  IF n <= 1 THEN t := 0; ELSE t := (i - 1)::FLOAT / (n - 1); END IF;
  dh := eh - sh;
  IF dh >  180 THEN dh := dh - 360; END IF;
  IF dh < -180 THEN dh := dh + 360; END IF;
  h := sh + t * dh;
  IF h < 0    THEN h := h + 360; END IF;
  IF h >= 360 THEN h := h - 360; END IF;
  s := ss + (es - ss) * t;
  v := sv + (ev - sv) * t;

  -- hsv -> rgb
  c := v * s;
  x := c * (1 - abs((h/60.0) - 2*floor(h/120.0) - 1));
  m := v - c;
  IF    h < 60  THEN rp:=c; gp:=x; bp:=0;
  ELSIF h < 120 THEN rp:=x; gp:=c; bp:=0;
  ELSIF h < 180 THEN rp:=0; gp:=c; bp:=x;
  ELSIF h < 240 THEN rp:=0; gp:=x; bp:=c;
  ELSIF h < 300 THEN rp:=x; gp:=0; bp:=c;
  ELSE               rp:=c; gp:=0; bp:=x;
  END IF;
  cr := GREATEST(0, LEAST(255, round((rp + m) * 255)));
  cg := GREATEST(0, LEAST(255, round((gp + m) * 255)));
  cb := GREATEST(0, LEAST(255, round((bp + m) * 255)));
  RETURN '#' || LPAD(TO_HEX(cr),2,'0') || LPAD(TO_HEX(cg),2,'0') || LPAD(TO_HEX(cb),2,'0');
END;
$$;
ALTER FUNCTION soil_data._ramp_color(text, text, int, int) OWNER TO sis;


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

ALTER FUNCTION soil_data.class() OWNER TO sis;


-- Recreate soil_data.map() — two fixes:
--   (1) JOIN the layer's actual mapped_property (the old FROM mapset, property
--       had NO join predicate, so it pulled an arbitrary property's colours —
--       why DST outputs rendered with the brown soil ramp).
--   (2) emit a piecewise COLORRANGE gradient sampled along the HSV hue arc
--       instead of one straight RGB COLORRANGE, so green->red runs through
--       yellow/orange, not brown.
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
BEGIN
  SELECT l.layer_id,
    CASE
      WHEN l.distance_uom='m'   THEN 'METERS'
      WHEN l.distance_uom='km'  THEN 'KILOMETERS'
      WHEN l.distance_uom='deg' THEN 'DD'
    END distance_uom,
    l.reference_system_identifier_code,
    l.extent, l.file_extension, l.stats_minimum, l.stats_maximum
  INTO rec_layer
  FROM soil_data.layer l
  WHERE l.layer_id = NEW.layer_id;

  SELECT p.start_color, p.end_color, COALESCE(p.num_intervals, 10) AS num_intervals
  INTO rec_property
  FROM soil_data.layer l
  JOIN soil_data.mapset m         ON m.mapset_id = l.mapset_id
  JOIN soil_data.mapped_property p ON p.mapped_property_id = m.mapped_property_id
  WHERE l.layer_id = NEW.layer_id;

  n := GREATEST(rec_property.num_intervals, 2);
  v_min := rec_layer.stats_minimum;
  v_max := rec_layer.stats_maximum;

  IF v_min IS NULL OR v_max IS NULL OR v_max <= v_min THEN
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

ALTER FUNCTION soil_data.map() OWNER TO sis;
