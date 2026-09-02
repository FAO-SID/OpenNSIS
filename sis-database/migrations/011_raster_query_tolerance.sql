-- 011: raster GetFeatureInfo works at any zoom level.
--
-- MapServer's raster point query buffers the click point by the layer
-- TOLERANCE. Without one, the query rectangle shrinks with the view scale,
-- and once the visitor zooms in past the raster's native resolution it can
-- fall between cell centres — GetFeatureInfo (the click popup and the
-- dynamic-legend hover cursor) silently returns nothing.
--
-- Give every raster LAYER a TOLERANCE of one native cell, in metres,
-- derived from soil_data.layer.distance/distance_uom. Then refresh the
-- stored .map text of existing layers (the API re-syncs the on-disk files
-- at startup, leaving DST-versioned DATA lines untouched).

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
BEGIN
  SELECT l.layer_id,
    CASE
      WHEN l.distance_uom='m'   THEN 'METERS'
      WHEN l.distance_uom='km'  THEN 'KILOMETERS'
      WHEN l.distance_uom='deg' THEN 'DD'
    END distance_uom,
    l.reference_system_identifier_code,
    l.extent, l.file_extension, l.stats_minimum, l.stats_maximum,
    l.distance AS cell_size, l.distance_uom AS cell_uom
  INTO rec_layer
  FROM soil_data.layer l
  WHERE l.layer_id = NEW.layer_id;

  SELECT p.start_color, p.end_color, COALESCE(p.num_intervals, 10) AS num_intervals
  INTO rec_property
  FROM soil_data.layer l
  JOIN soil_data.mapset m         ON m.mapset_id = l.mapset_id
  JOIN soil_data.mapped_property p ON p.mapped_property_id = m.mapped_property_id
  WHERE l.layer_id = NEW.layer_id;

  -- Query tolerance: one native cell, expressed in metres (floor 100 m,
  -- default 1000 m when the resolution is unknown).
  tol_m := COALESCE(CEIL(GREATEST(
             CASE rec_layer.cell_uom
               WHEN 'deg' THEN rec_layer.cell_size * 111320
               WHEN 'km'  THEN rec_layer.cell_size * 1000
               ELSE            rec_layer.cell_size
             END, 100)), 1000);

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

-- Refresh the stored .map text of every existing raster layer (fires the
-- trigger above). Touching stats_minimum with its own value is a no-op for
-- the data but is one of the trigger's listed columns.
UPDATE soil_data.layer
   SET stats_minimum = stats_minimum
 WHERE map IS NOT NULL;
