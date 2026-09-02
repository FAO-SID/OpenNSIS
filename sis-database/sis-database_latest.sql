--
-- PostgreSQL database dump
--

\restrict IaVCJgHhGyrrcjzYIfJyV7ehzpM6ddVrUKoS5dDYY9OVI5hzgkcf7wkIJwTu42Y

-- Dumped from database version 12.22 (Ubuntu 12.22-3.pgdg22.04+1)
-- Dumped by pg_dump version 18.4 (Ubuntu 18.4-1.pgdg22.04+1)

-- Started on 2026-06-24 06:13:28 CEST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 11 (class 2615 OID 55714821)
-- Name: api; Type: SCHEMA; Schema: -; Owner: sis
--

CREATE SCHEMA api;


ALTER SCHEMA api OWNER TO sis;

--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA api; Type: COMMENT; Schema: -; Owner: sis
--

COMMENT ON SCHEMA api IS 'REST API tables';


--
-- TOC entry 12 (class 2615 OID 55714822)
-- Name: kobo; Type: SCHEMA; Schema: -; Owner: sis
--

CREATE SCHEMA kobo;


ALTER SCHEMA kobo OWNER TO sis;

--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA kobo; Type: COMMENT; Schema: -; Owner: sis
--

COMMENT ON SCHEMA kobo IS 'GloSIS data collection database schema';


--
-- TOC entry 13 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: sis
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO sis;

--
-- TOC entry 14 (class 2615 OID 55714823)
-- Name: soil_data; Type: SCHEMA; Schema: -; Owner: sis
--

CREATE SCHEMA soil_data;


ALTER SCHEMA soil_data OWNER TO sis;

--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA soil_data; Type: COMMENT; Schema: -; Owner: sis
--

COMMENT ON SCHEMA soil_data IS 'Core entities and relations from the ISO-28258 domain model';


--
-- TOC entry 15 (class 2615 OID 55714824)
-- Name: soil_data_upload; Type: SCHEMA; Schema: -; Owner: sis
--

CREATE SCHEMA soil_data_upload;


ALTER SCHEMA soil_data_upload OWNER TO sis;

--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 15
-- Name: SCHEMA soil_data_upload; Type: COMMENT; Schema: -; Owner: sis
--

COMMENT ON SCHEMA soil_data_upload IS 'Schema to upload soil data';


--
-- TOC entry 5 (class 3079 OID 55713063)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 5
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 4 (class 3079 OID 55714149)
-- Name: postgis_raster; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_raster WITH SCHEMA public;


--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION postgis_raster; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_raster IS 'PostGIS raster types and functions';


--
-- TOC entry 3 (class 3079 OID 55714710)
-- Name: postgis_sfcgal; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_sfcgal WITH SCHEMA public;


--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION postgis_sfcgal; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_sfcgal IS 'PostGIS SFCGAL functions';


--
-- TOC entry 2 (class 3079 OID 55714787)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 5226 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 1634 (class 1255 OID 55714825)
-- Name: audit_no_modify(); Type: FUNCTION; Schema: api; Owner: sis
--

CREATE FUNCTION api.audit_no_modify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'api.audit is append-only (DELETE blocked)'; END IF;
  IF NEW.audit_id    IS DISTINCT FROM OLD.audit_id    THEN RAISE EXCEPTION 'api.audit.audit_id is immutable';    END IF;
  IF NEW.action      IS DISTINCT FROM OLD.action      THEN RAISE EXCEPTION 'api.audit.action is immutable';      END IF;
  IF NEW.details     IS DISTINCT FROM OLD.details     THEN RAISE EXCEPTION 'api.audit.details is immutable';     END IF;
  IF NEW.created_at  IS DISTINCT FROM OLD.created_at  THEN RAISE EXCEPTION 'api.audit.created_at is immutable';  END IF;
  IF NEW.ip_address  IS DISTINCT FROM OLD.ip_address  THEN RAISE EXCEPTION 'api.audit.ip_address is immutable';  END IF;
  IF NEW.user_id       IS DISTINCT FROM OLD.user_id       AND NEW.user_id       IS NOT NULL THEN RAISE EXCEPTION 'api.audit.user_id can only be cleared';       END IF;
  IF NEW.api_client_id IS DISTINCT FROM OLD.api_client_id AND NEW.api_client_id IS NOT NULL THEN RAISE EXCEPTION 'api.audit.api_client_id can only be cleared'; END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION api.audit_no_modify() OWNER TO sis;

--
-- TOC entry 1635 (class 1255 OID 55714826)
-- Name: blur_geom(public.geometry, text, integer); Type: FUNCTION; Schema: api; Owner: sis
--

CREATE FUNCTION api.blur_geom(g public.geometry, seed text, radius_m integer) RETURNS public.geometry
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  h bytea;
  u1 double precision;
  u2 double precision;
BEGIN
  IF radius_m IS NULL OR radius_m <= 0 OR g IS NULL THEN
    RETURN g;
  END IF;
  h := decode(md5(seed), 'hex');
  u1 := (get_byte(h,0)::bigint*16777216 + get_byte(h,1)*65536 + get_byte(h,2)*256 + get_byte(h,3)) / 4294967295.0;
  u2 := (get_byte(h,4)::bigint*16777216 + get_byte(h,5)*65536 + get_byte(h,6)*256 + get_byte(h,7)) / 4294967295.0;
  RETURN ST_Project(g::geography, sqrt(u1) * radius_m, u2 * 2 * pi())::geometry;
END;
$$;


ALTER FUNCTION api.blur_geom(g public.geometry, seed text, radius_m integer) OWNER TO sis;

--
-- TOC entry 1636 (class 1255 OID 55714827)
-- Name: insert_dummy_data(text, text, text, integer, integer[], double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: api; Owner: sis
--

CREATE FUNCTION api.insert_dummy_data(p_country_id text DEFAULT 'BT'::text, p_project_id text DEFAULT 'dummy data'::text, p_project_name text DEFAULT 'dummy data'::text, p_num_plots integer DEFAULT 100, p_observation_ids integer[] DEFAULT NULL::integer[], p_xmin double precision DEFAULT '-1.0'::numeric, p_xmax double precision DEFAULT 1.0, p_ymin double precision DEFAULT '-1.0'::numeric, p_ymax double precision DEFAULT 1.0) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_project_id text;
    v_site_id text;
    v_stub_id text;
    v_plot_id integer;
    v_profile_id integer;
    v_element_id integer;
    v_specimen_id integer;
    v_plot_num integer;
    v_observation_rec RECORD;
    v_random_value real;
    v_random_x float;
    v_random_y float;
    v_observation_filter integer[];
BEGIN
    -- Use all observations if none specified
    IF p_observation_ids IS NULL THEN
        SELECT array_agg(observation_num_id)
        INTO v_observation_filter
        FROM soil_data.observation_num;
    ELSE
        v_observation_filter := p_observation_ids;
    END IF;

    RAISE NOTICE 'Starting dummy data insertion with parameters:';
    RAISE NOTICE '  - Country ID: %', p_country_id;
    RAISE NOTICE '  - Project ID: %', p_project_id;
    RAISE NOTICE '  - Project Name: %', p_project_name;
    RAISE NOTICE '  - Number of plots: %', p_num_plots;
    RAISE NOTICE '  - Observations: %', array_length(v_observation_filter, 1);
    RAISE NOTICE '  - X range: [%, %]', p_xmin, p_xmax;
    RAISE NOTICE '  - Y range: [%, %]', p_ymin, p_ymax;

    -- Insert project (composite PK: country_id + project_id)
    INSERT INTO soil_data.project (country_id, project_id, name)
    VALUES (p_country_id, p_project_id, p_project_name)
    RETURNING project_id INTO v_project_id;

    RAISE NOTICE 'Created project with ID: % / %', p_country_id, v_project_id;

    -- Stub mapset + layer carry the project's publication policy:
    --   is_published          -> soil_data.layer
    --   profile_limit / spatial_blur_m -> soil_data.mapset
    -- ID convention: mapset_id = layer_id = country_id || '-' || project_id.
    -- The api.vw_api_* views read is_published from this stub layer; without
    -- it every profile is filtered out.
    v_stub_id := p_country_id || '-' || v_project_id;

    INSERT INTO soil_data.mapset (country_id, project_id, mapped_property_id, mapset_id, title)
    VALUES (p_country_id, v_project_id, NULL, v_stub_id, p_project_name)
    ON CONFLICT (mapset_id) DO NOTHING;

    INSERT INTO soil_data.layer (mapset_id, layer_id, file_path, is_published)
    VALUES (v_stub_id, v_stub_id, '', TRUE)
    ON CONFLICT (layer_id) DO NOTHING;

    RAISE NOTICE 'Created stub mapset + layer with ID: %', v_stub_id;

    -- Insert site
    INSERT INTO soil_data.site (site_id)
    VALUES (p_project_id || '_site')
    RETURNING site_id INTO v_site_id;

    RAISE NOTICE 'Created site with ID: %', v_site_id;

    -- Link project and site (project_site now carries country_id)
    INSERT INTO soil_data.project_site (country_id, project_id, site_id)
    VALUES (p_country_id, v_project_id, v_site_id);

    -- Insert plots
    FOR v_plot_num IN 1..p_num_plots LOOP
        -- Generate random coordinates within specified bounds
        v_random_x := p_xmin + (random() * (p_xmax - p_xmin));
        v_random_y := p_ymin + (random() * (p_ymax - p_ymin));

        INSERT INTO soil_data.plot (site_id, altitude, sampling_date, geom, type)
        VALUES (
            v_site_id,
            100 + (random() * 500)::integer,  -- Random altitude between 100 and 600
            CURRENT_DATE - (random() * 365)::integer,
            ST_SetSRID(ST_MakePoint(v_random_x, v_random_y), 4326),
            'TrialPit'
        )
        RETURNING plot_id INTO v_plot_id;

        -- Insert profile for this plot
        INSERT INTO soil_data.profile (plot_id, profile_code)
        VALUES (v_plot_id, p_project_id || '_PROFILE_' || LPAD(v_plot_num::text, 3, '0'))
        RETURNING profile_id INTO v_profile_id;

        -- Insert 3 elements (layers) per plot
        -- Element 1: 0-30 cm
        INSERT INTO soil_data.element (profile_id, order_element, upper_depth, lower_depth, type)
        VALUES (v_profile_id, 1, 0, 30, 'Layer')
        RETURNING element_id INTO v_element_id;

        -- Insert specimen for element 1
        INSERT INTO soil_data.specimen (element_id, code)
        VALUES (v_element_id, p_project_id || '_SPEC_P' || LPAD(v_plot_num::text, 3, '0') || '_E1')
        RETURNING specimen_id INTO v_specimen_id;

        -- Insert result_num for specified observations for this specimen
        FOR v_observation_rec IN
            SELECT observation_num_id, COALESCE(value_min,0) AS value_min, COALESCE(value_max,100) AS value_max
            FROM soil_data.observation_num
            WHERE observation_num_id = ANY(v_observation_filter)
        LOOP
            -- Generate random value within bounds
            v_random_value := v_observation_rec.value_min +
                (random() * (v_observation_rec.value_max - v_observation_rec.value_min));

            INSERT INTO soil_data.result_num (observation_num_id, specimen_id, value)
            VALUES (v_observation_rec.observation_num_id, v_specimen_id, v_random_value);
        END LOOP;

        -- Element 2: 30-60 cm
        INSERT INTO soil_data.element (profile_id, order_element, upper_depth, lower_depth, type)
        VALUES (v_profile_id, 2, 30, 60, 'Layer')
        RETURNING element_id INTO v_element_id;

        -- Insert specimen for element 2
        INSERT INTO soil_data.specimen (element_id, code)
        VALUES (v_element_id, p_project_id || '_SPEC_P' || LPAD(v_plot_num::text, 3, '0') || '_E2')
        RETURNING specimen_id INTO v_specimen_id;

        -- Insert result_num for specified observations for this specimen
        FOR v_observation_rec IN
            SELECT observation_num_id, COALESCE(value_min,0) AS value_min, COALESCE(value_max,100) AS value_max
            FROM soil_data.observation_num
            WHERE observation_num_id = ANY(v_observation_filter)
        LOOP
            v_random_value := v_observation_rec.value_min +
                (random() * (v_observation_rec.value_max - v_observation_rec.value_min));

            INSERT INTO soil_data.result_num (observation_num_id, specimen_id, value)
            VALUES (v_observation_rec.observation_num_id, v_specimen_id, v_random_value);
        END LOOP;

        -- Element 3: 60-100 cm
        INSERT INTO soil_data.element (profile_id, order_element, upper_depth, lower_depth, type)
        VALUES (v_profile_id, 3, 60, 100, 'Layer')
        RETURNING element_id INTO v_element_id;

        -- Insert specimen for element 3
        INSERT INTO soil_data.specimen (element_id, code)
        VALUES (v_element_id, p_project_id || '_SPEC_P' || LPAD(v_plot_num::text, 3, '0') || '_E3')
        RETURNING specimen_id INTO v_specimen_id;

        -- Insert result_num for specified observations for this specimen
        FOR v_observation_rec IN
            SELECT observation_num_id, COALESCE(value_min,0) AS value_min, COALESCE(value_max,100) AS value_max
            FROM soil_data.observation_num
            WHERE observation_num_id = ANY(v_observation_filter)
        LOOP
            v_random_value := v_observation_rec.value_min +
                (random() * (v_observation_rec.value_max - v_observation_rec.value_min));

            INSERT INTO soil_data.result_num (observation_num_id, specimen_id, value)
            VALUES (v_observation_rec.observation_num_id, v_specimen_id, v_random_value);
        END LOOP;

        IF v_plot_num % GREATEST(1, p_num_plots / 10) = 0 THEN
            RAISE NOTICE 'Created % plots...', v_plot_num;
        END IF;
    END LOOP;

    RAISE NOTICE 'Dummy data insertion completed successfully!';
    RAISE NOTICE 'Total records created:';
    RAISE NOTICE '  - 1 project';
    RAISE NOTICE '  - 1 stub mapset + 1 stub layer';
    RAISE NOTICE '  - 1 site';
    RAISE NOTICE '  - % plots', p_num_plots;
    RAISE NOTICE '  - % profiles', p_num_plots;
    RAISE NOTICE '  - % elements (3 per plot)', p_num_plots * 3;
    RAISE NOTICE '  - % specimens (1 per element)', p_num_plots * 3;
    RAISE NOTICE '  - % physical/chemical results (% observations × % specimens)',
        array_length(v_observation_filter, 1) * p_num_plots * 3,
        array_length(v_observation_filter, 1),
        p_num_plots * 3;
END;
$$;


ALTER FUNCTION api.insert_dummy_data(p_country_id text, p_project_id text, p_project_name text, p_num_plots integer, p_observation_ids integer[], p_xmin double precision, p_xmax double precision, p_ymin double precision, p_ymax double precision) OWNER TO sis;

--
-- TOC entry 5227 (class 0 OID 0)
-- Dependencies: 1636
-- Name: FUNCTION insert_dummy_data(p_country_id text, p_project_id text, p_project_name text, p_num_plots integer, p_observation_ids integer[], p_xmin double precision, p_xmax double precision, p_ymin double precision, p_ymax double precision); Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON FUNCTION api.insert_dummy_data(p_country_id text, p_project_id text, p_project_name text, p_num_plots integer, p_observation_ids integer[], p_xmin double precision, p_xmax double precision, p_ymin double precision, p_ymax double precision) IS 'docker exec sis-database psql -U sis -d sis -c "SELECT api.insert_dummy_data(
	                                                  p_country_id := ''BT'',
                                                    p_project_id := ''DUMMY_DATA_1'',
                                                    p_project_name := ''Dummy data 1'',
                                                    p_num_plots := 200,
                                                    p_observation_ids := ARRAY[911,912,913],
                                                    p_xmin := 89.11,
                                                    p_xmax := 92.12,
                                                    p_ymin := 26.71,
                                                    p_ymax := 28.28
                                                )"';


--
-- TOC entry 1637 (class 1255 OID 55714829)
-- Name: _ramp_color(text, text, integer, integer); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data._ramp_color(start_hex text, end_hex text, n integer, i integer) RETURNS text
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


ALTER FUNCTION soil_data._ramp_color(start_hex text, end_hex text, n integer, i integer) OWNER TO sis;

--
-- TOC entry 1638 (class 1255 OID 55714830)
-- Name: check_result_value(); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data.check_result_value() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    observation soil_data.observation_num%ROWTYPE;
BEGIN
    SELECT * 
      INTO observation
      FROM soil_data.observation_num
     WHERE observation_num_id = NEW.observation_num_id;
    
    IF NEW.value < observation.value_min OR NEW.value > observation.value_max THEN
        RAISE EXCEPTION 'Result value outside admissable bounds for the related observation.';
    ELSE
        RETURN NEW;
    END IF; 
END;
$$;


ALTER FUNCTION soil_data.check_result_value() OWNER TO sis;

--
-- TOC entry 5228 (class 0 OID 0)
-- Dependencies: 1638
-- Name: FUNCTION check_result_value(); Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON FUNCTION soil_data.check_result_value() IS 'Checks if the value assigned to a result record is within the numerical bounds declared in the related observations (fields value_min and value_max).';


--
-- TOC entry 1639 (class 1255 OID 55714831)
-- Name: class(); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data.class() RETURNS trigger
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

--
-- TOC entry 5230 (class 0 OID 0)
-- Dependencies: 1639
-- Name: FUNCTION class(); Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON FUNCTION soil_data.class() IS 'Trigger function that automatically generates classification intervals and colors for quantitative properties in mapsets based on layer statistics. Creates class entries with interpolated colors between start and end colors.';


--
-- TOC entry 1640 (class 1255 OID 55714832)
-- Name: map(); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data.map() RETURNS trigger
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


ALTER FUNCTION soil_data.map() OWNER TO sis;

--
-- TOC entry 5232 (class 0 OID 0)
-- Dependencies: 1640
-- Name: FUNCTION map(); Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON FUNCTION soil_data.map() IS 'Trigger function that generates MapServer MAP file content for raster layers. Creates the complete MAP configuration including projection, WMS metadata, and styling based on property colors and layer statistics.';


--
-- TOC entry 1641 (class 1255 OID 55714833)
-- Name: mapset_publication_not_future(); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data.mapset_publication_not_future() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.publication_date IS NOT NULL AND NEW.publication_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'publication_date (%) cannot be in the future', NEW.publication_date;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION soil_data.mapset_publication_not_future() OWNER TO sis;

--
-- TOC entry 1642 (class 1255 OID 55714834)
-- Name: sld(); Type: FUNCTION; Schema: soil_data; Owner: sis
--

CREATE FUNCTION soil_data.sld() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  rec RECORD;
  sub_rec RECORD;
  part_1 text := '<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor xmlns="http://www.opengis.net/sld" version="1.0.0" xmlns:sld="http://www.opengis.net/sld" xmlns:gml="http://www.opengis.net/gml" xmlns:ogc="http://www.opengis.net/ogc">
  <UserLayer>
    <sld:LayerFeatureConstraints>
      <sld:FeatureTypeConstraint/>
    </sld:LayerFeatureConstraints>
    <sld:UserStyle>
      <sld:Name>LAYER_NAME</sld:Name>
      <sld:FeatureTypeStyle>
        <sld:Rule>
          <sld:RasterSymbolizer>
            <sld:ChannelSelection>
              <sld:GrayChannel>
                <sld:SourceChannelName>1</sld:SourceChannelName>
              </sld:GrayChannel>
            </sld:ChannelSelection>
            <sld:ColorMap type="property_type">';
  part_2 text :='';
  new_row text;
  part_3 text := '
            </sld:ColorMap>
          </sld:RasterSymbolizer>
        </sld:Rule>
      </sld:FeatureTypeStyle>
    </sld:UserStyle>
  </UserLayer>
</StyledLayerDescriptor>';
BEGIN
    FOR rec IN SELECT DISTINCT NEW.mapset_id,
            CASE WHEN p.property_type='categorical'  THEN 'values'
                 WHEN p.property_type='quantitative' THEN 'intervals'
              END property_type
            FROM soil_data.mapset m,
                 soil_data.mapped_property p
            WHERE split_part(NEW.mapset_id,'-',3) = p.mapped_property_id
            ORDER BY NEW.mapset_id
    LOOP
      FOR sub_rec IN SELECT code, value, color, opacity, label
                     FROM soil_data.class
                     WHERE mapset_id = NEW.mapset_id AND publish IS TRUE
                     ORDER BY value
      LOOP
        SELECT E'\n             <sld:ColorMapEntry quantity="' ||sub_rec.value|| '" color="' ||sub_rec.color|| '" opacity="' ||sub_rec.opacity|| '" label="' ||sub_rec.label|| '"/>' INTO new_row;
        SELECT part_2 || new_row INTO part_2;
      END LOOP;
      UPDATE soil_data.mapset SET sld = replace(replace(part_1,'LAYER_NAME',NEW.mapset_id),'property_type',rec.property_type) || part_2 || part_3 WHERE mapset_id = NEW.mapset_id;
      SELECT '' INTO part_2;
      SELECT '' INTO new_row;
    END LOOP;
  RETURN NEW;
END
$$;


ALTER FUNCTION soil_data.sld() OWNER TO sis;

--
-- TOC entry 5234 (class 0 OID 0)
-- Dependencies: 1642
-- Name: FUNCTION sld(); Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON FUNCTION soil_data.sld() IS 'Trigger function that generates Styled Layer Descriptor (SLD) XML for mapsets. Creates OGC-compliant SLD documents with ColorMap entries based on the class table for map styling.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 225 (class 1259 OID 55714835)
-- Name: api_client; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.api_client (
    api_client_id text NOT NULL,
    api_key text NOT NULL,
    is_active boolean DEFAULT true,
    created_at date DEFAULT CURRENT_DATE,
    expires_at date,
    last_login timestamp without time zone,
    description text DEFAULT ''::text NOT NULL
);


ALTER TABLE api.api_client OWNER TO sis;

--
-- TOC entry 5236 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE api_client; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api.api_client IS 'For server-to-server authentication';


--
-- TOC entry 5237 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.api_client_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.api_client_id IS 'Unique identifier for the API client';


--
-- TOC entry 5238 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.api_key; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.api_key IS 'Secret API key for authentication';


--
-- TOC entry 5239 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.is_active; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.is_active IS 'Flag indicating whether the client is active';


--
-- TOC entry 5240 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.created_at; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.created_at IS 'Date when the client was created';


--
-- TOC entry 5241 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.expires_at; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.expires_at IS 'Date when the API key expires';


--
-- TOC entry 5242 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.last_login; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.last_login IS 'Timestamp of the last successful authentication';


--
-- TOC entry 5243 (class 0 OID 0)
-- Dependencies: 225
-- Name: COLUMN api_client.description; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.api_client.description IS 'Description of the API client purpose';


--
-- TOC entry 226 (class 1259 OID 55714844)
-- Name: audit; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.audit (
    audit_id integer NOT NULL,
    user_id text,
    api_client_id text,
    action text,
    details jsonb,
    ip_address inet,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE api.audit OWNER TO sis;

--
-- TOC entry 5245 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE audit; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api.audit IS 'Track authentication attempts and API usage';


--
-- TOC entry 5246 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.audit_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.audit_id IS 'Synthetic primary key for the audit record';


--
-- TOC entry 5247 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.user_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.user_id IS 'Reference to the user who performed the action';


--
-- TOC entry 5248 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.api_client_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.api_client_id IS 'Reference to the API client that performed the action';


--
-- TOC entry 5249 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.action; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.action IS 'Type of action performed';


--
-- TOC entry 5250 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.details; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.details IS 'JSON object with action details';


--
-- TOC entry 5251 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.ip_address; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.ip_address IS 'IP address from which the action was performed';


--
-- TOC entry 5252 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN audit.created_at; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.audit.created_at IS 'Timestamp when the action occurred';


--
-- TOC entry 227 (class 1259 OID 55714851)
-- Name: audit_audit_id_seq; Type: SEQUENCE; Schema: api; Owner: sis
--

ALTER TABLE api.audit ALTER COLUMN audit_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME api.audit_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 55714853)
-- Name: dst_recipe; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.dst_recipe (
    recipe_id text NOT NULL,
    name text NOT NULL,
    description text,
    recipe jsonb NOT NULL,
    output_layer_id text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    run_status text,
    run_started_at timestamp with time zone,
    run_finished_at timestamp with time zone,
    run_error text,
    metadata_status text,
    metadata_error text,
    run_triggered_by text,
    CONSTRAINT dst_recipe_metadata_status_check CHECK (((metadata_status IS NULL) OR (metadata_status = ANY (ARRAY['skipped'::text, 'succeeded'::text, 'failed'::text])))),
    CONSTRAINT dst_recipe_run_status_check CHECK (((run_status IS NULL) OR (run_status = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text]))))
);


ALTER TABLE api.dst_recipe OWNER TO sis;

--
-- TOC entry 229 (class 1259 OID 55714863)
-- Name: setting; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.setting (
    key text NOT NULL,
    value text
);


ALTER TABLE api.setting OWNER TO sis;

--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE setting; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api.setting IS 'Key-value store for API configuration settings';


--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 229
-- Name: COLUMN setting.key; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.setting.key IS 'Setting identifier key';


--
-- TOC entry 5257 (class 0 OID 0)
-- Dependencies: 229
-- Name: COLUMN setting.value; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.setting.value IS 'Setting value';


--
-- TOC entry 230 (class 1259 OID 55714869)
-- Name: uploaded_dataset; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.uploaded_dataset (
    user_id text,
    project_id text,
    table_name text NOT NULL,
    file_name text NOT NULL,
    upload_date date DEFAULT CURRENT_DATE,
    ingestion_date date,
    status text,
    depth_if_topsoil smallint,
    n_rows integer,
    n_col smallint,
    has_cords boolean,
    cords_epsg integer,
    cords_check boolean DEFAULT false,
    note text,
    country_id text NOT NULL,
    CONSTRAINT uploaded_dataset_status_check CHECK ((status = ANY (ARRAY['Uploaded'::text, 'Ingested'::text, 'Removed'::text])))
);


ALTER TABLE api.uploaded_dataset OWNER TO sis;

--
-- TOC entry 5259 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE uploaded_dataset; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api.uploaded_dataset IS 'Tracks datasets uploaded by users for ingestion into the soil data schema';


--
-- TOC entry 5260 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.user_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.user_id IS 'Reference to the user who uploaded the dataset';


--
-- TOC entry 5261 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.project_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.project_id IS 'Reference to the project this dataset belongs to';


--
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.table_name; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.table_name IS 'Name of the staging table containing the uploaded data';


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.file_name; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.file_name IS 'Original filename of the uploaded file';


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.upload_date; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.upload_date IS 'Date when the file was uploaded';


--
-- TOC entry 5265 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.ingestion_date; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.ingestion_date IS 'Date when the data was ingested into the main schema';


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.status; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.status IS 'Current status: Uploaded, Ingested, or Removed';


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.depth_if_topsoil; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.depth_if_topsoil IS 'Depth in cm if this is topsoil data';


--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.n_rows; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.n_rows IS 'Number of rows in the uploaded dataset';


--
-- TOC entry 5269 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.n_col; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.n_col IS 'Number of columns in the uploaded dataset';


--
-- TOC entry 5270 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.has_cords; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.has_cords IS 'Flag indicating whether the dataset contains coordinates';


--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.cords_epsg; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.cords_epsg IS 'EPSG code of the coordinate reference system';


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.cords_check; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.cords_check IS 'Flag indicating whether coordinates have been validated';


--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN uploaded_dataset.note; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset.note IS 'Additional notes about the dataset';


--
-- TOC entry 231 (class 1259 OID 55714878)
-- Name: uploaded_dataset_column; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.uploaded_dataset_column (
    table_name text NOT NULL,
    column_name text NOT NULL,
    destination_table text,
    destination_column text,
    property_num_id text,
    procedure_num_id text,
    unit_of_measure_id text,
    ignore_column boolean DEFAULT false,
    note text,
    validation text
);


ALTER TABLE api.uploaded_dataset_column OWNER TO sis;

--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE uploaded_dataset_column; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api.uploaded_dataset_column IS 'Column mapping configuration for uploaded datasets';


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.table_name; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.table_name IS 'Reference to the uploaded dataset table';


--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.column_name; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.column_name IS 'Name of the column in the uploaded dataset';


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.property_num_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.property_num_id IS 'Mapped soil property identifier';


--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.procedure_num_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.procedure_num_id IS 'Mapped analytical procedure identifier';


--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.unit_of_measure_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.unit_of_measure_id IS 'Mapped unit of measure identifier';


--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.ignore_column; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.ignore_column IS 'Flag to ignore this column during ingestion';


--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN uploaded_dataset_column.note; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api.uploaded_dataset_column.note IS 'Additional notes about the column mapping';


--
-- TOC entry 232 (class 1259 OID 55714885)
-- Name: uploaded_dataset_edit; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api.uploaded_dataset_edit (
    edit_id integer NOT NULL,
    table_name text NOT NULL,
    row_id integer NOT NULL,
    column_name text NOT NULL,
    old_value text,
    new_value text,
    user_id text,
    edited_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE api.uploaded_dataset_edit OWNER TO sis;

--
-- TOC entry 233 (class 1259 OID 55714892)
-- Name: uploaded_dataset_edit_edit_id_seq; Type: SEQUENCE; Schema: api; Owner: sis
--

CREATE SEQUENCE api.uploaded_dataset_edit_edit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE api.uploaded_dataset_edit_edit_id_seq OWNER TO sis;

--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 233
-- Name: uploaded_dataset_edit_edit_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: sis
--

ALTER SEQUENCE api.uploaded_dataset_edit_edit_id_seq OWNED BY api.uploaded_dataset_edit.edit_id;


--
-- TOC entry 234 (class 1259 OID 55714894)
-- Name: user; Type: TABLE; Schema: api; Owner: sis
--

CREATE TABLE api."user" (
    user_id text NOT NULL,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true,
    is_admin boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_DATE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_login timestamp without time zone,
    password_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    failed_login_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone
);


ALTER TABLE api."user" OWNER TO sis;

--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE "user"; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON TABLE api."user" IS 'For human users who log in through the web application';


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".user_id; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".user_id IS 'Unique identifier for the user (typically email or username)';


--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".password_hash; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".password_hash IS 'Bcrypt hash of the user password';


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".is_active; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".is_active IS 'Flag indicating whether the user account is active';


--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".is_admin; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".is_admin IS 'Flag indicating whether the user has administrator privileges';


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".created_at; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".created_at IS 'Timestamp when the user was created';


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".updated_at; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".updated_at IS 'Timestamp of the last update to the user record';


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN "user".last_login; Type: COMMENT; Schema: api; Owner: sis
--

COMMENT ON COLUMN api."user".last_login IS 'Timestamp of the last successful login';


--
-- TOC entry 235 (class 1259 OID 55714906)
-- Name: element; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.element (
    element_id integer NOT NULL,
    profile_id integer NOT NULL,
    order_element integer,
    upper_depth integer NOT NULL,
    lower_depth integer NOT NULL,
    type text NOT NULL,
    horizon text,
    CONSTRAINT element_check CHECK ((lower_depth > upper_depth)),
    CONSTRAINT element_order_element_check CHECK ((order_element > 0)),
    CONSTRAINT element_type_check CHECK ((type = ANY (ARRAY['Horizon'::text, 'Layer'::text]))),
    CONSTRAINT element_upper_depth_check CHECK ((upper_depth >= 0)),
    CONSTRAINT element_upper_depth_check1 CHECK ((upper_depth <= 1000))
);


ALTER TABLE soil_data.element OWNER TO sis;

--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE element; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.element IS 'ProfileElement is the super-class of Horizon and Layer, which share the same basic properties. Horizons develop in a layer, which in turn have been developed throught geogenesis or anthropogenic action. Layers can be used to describe common characteristics of a set of adjoining horizons. For the time being no assocation is previewed between Horizon and Layer.';


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.element_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.element_id IS 'Synthetic primary key.';


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.profile_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.profile_id IS 'Reference to the Profile to which this element belongs';


--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.order_element; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.order_element IS 'Order of this element within the Profile';


--
-- TOC entry 5299 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.upper_depth; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.upper_depth IS 'Upper depth of this profile element in centimetres.';


--
-- TOC entry 5300 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.lower_depth; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.lower_depth IS 'Lower depth of this profile element in centimetres.';


--
-- TOC entry 5301 (class 0 OID 0)
-- Dependencies: 235
-- Name: COLUMN element.type; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.element.type IS 'Type of profile element, Horizon or Layer';


--
-- TOC entry 236 (class 1259 OID 55714917)
-- Name: layer; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.layer (
    mapset_id text NOT NULL,
    dimension_depth text,
    dimension_stats text,
    layer_id text NOT NULL,
    file_extension text,
    is_published boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    file_path text NOT NULL,
    file_size integer,
    file_size_pretty text,
    reference_layer boolean DEFAULT false,
    reference_system_identifier_code text,
    distance text,
    distance_uom text,
    extent text,
    west_bound_longitude numeric(4,1),
    east_bound_longitude numeric(4,1),
    south_bound_latitude numeric(4,1),
    north_bound_latitude numeric(4,1),
    distribution_format text,
    compression text,
    raster_size_x real,
    raster_size_y real,
    pixel_size_x real,
    pixel_size_y real,
    origin_x real,
    origin_y real,
    spatial_reference text,
    data_type text,
    no_data_value double precision,
    stats_minimum real,
    stats_maximum real,
    stats_mean real,
    stats_std_dev real,
    scale text,
    n_bands integer,
    metadata text[],
    map text,
    file_orig_name text NOT NULL,
    costum_name text,
    CONSTRAINT layer_dimension_stats_check CHECK ((dimension_stats = ANY (ARRAY['MEAN'::text, 'SDEV'::text, 'UNCT'::text, 'X'::text]))),
    CONSTRAINT layer_distance_uom_check CHECK ((distance_uom = ANY (ARRAY['m'::text, 'km'::text, 'deg'::text])))
);


ALTER TABLE soil_data.layer OWNER TO sis;

--
-- TOC entry 5303 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE layer; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.layer IS 'Raster layer metadata and file information for spatial data';


--
-- TOC entry 5304 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.mapset_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.mapset_id IS 'Reference to the parent mapset';


--
-- TOC entry 5305 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.dimension_depth; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.dimension_depth IS 'Depth dimension value (e.g., 0-5cm, 5-15cm)';


--
-- TOC entry 5306 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.dimension_stats; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.dimension_stats IS 'Statistical dimension: MEAN, SDEV, UNCT, or X';


--
-- TOC entry 5307 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.layer_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.layer_id IS 'Unique identifier for the layer';


--
-- TOC entry 5308 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.file_extension; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.file_extension IS 'File extension (e.g., tif, nc)';


--
-- TOC entry 5309 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.file_path; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.file_path IS 'File system path to the raster file';


--
-- TOC entry 5310 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.file_size; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.file_size IS 'File size in bytes';


--
-- TOC entry 5311 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.file_size_pretty; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.file_size_pretty IS 'Human-readable file size';


--
-- TOC entry 5312 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.reference_layer; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.reference_layer IS 'Flag indicating if this is the reference layer for the mapset';


--
-- TOC entry 5313 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.reference_system_identifier_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.reference_system_identifier_code IS 'EPSG code of the coordinate reference system';


--
-- TOC entry 5314 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.distance; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.distance IS 'Spatial resolution value';


--
-- TOC entry 5315 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.distance_uom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.distance_uom IS 'Unit of measure for distance: m, km, or deg';


--
-- TOC entry 5316 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.extent; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.extent IS 'Bounding box extent as text';


--
-- TOC entry 5317 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.west_bound_longitude; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.west_bound_longitude IS 'Western boundary longitude';


--
-- TOC entry 5318 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.east_bound_longitude; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.east_bound_longitude IS 'Eastern boundary longitude';


--
-- TOC entry 5319 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.south_bound_latitude; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.south_bound_latitude IS 'Southern boundary latitude';


--
-- TOC entry 5320 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.north_bound_latitude; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.north_bound_latitude IS 'Northern boundary latitude';


--
-- TOC entry 5321 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.distribution_format; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.distribution_format IS 'Data distribution format';


--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.compression; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.compression IS 'Compression type used';


--
-- TOC entry 5323 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.raster_size_x; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.raster_size_x IS 'Number of columns in the raster';


--
-- TOC entry 5324 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.raster_size_y; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.raster_size_y IS 'Number of rows in the raster';


--
-- TOC entry 5325 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.pixel_size_x; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.pixel_size_x IS 'Pixel width in map units';


--
-- TOC entry 5326 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.pixel_size_y; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.pixel_size_y IS 'Pixel height in map units';


--
-- TOC entry 5327 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.origin_x; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.origin_x IS 'X coordinate of the raster origin';


--
-- TOC entry 5328 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.origin_y; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.origin_y IS 'Y coordinate of the raster origin';


--
-- TOC entry 5329 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.spatial_reference; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.spatial_reference IS 'Full spatial reference definition';


--
-- TOC entry 5330 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.data_type; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.data_type IS 'Raster data type (e.g., Float32, Int16)';


--
-- TOC entry 5331 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.no_data_value; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.no_data_value IS 'NoData value for the raster';


--
-- TOC entry 5332 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.stats_minimum; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.stats_minimum IS 'Minimum value in the raster';


--
-- TOC entry 5333 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.stats_maximum; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.stats_maximum IS 'Maximum value in the raster';


--
-- TOC entry 5334 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.stats_mean; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.stats_mean IS 'Mean value in the raster';


--
-- TOC entry 5335 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.stats_std_dev; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.stats_std_dev IS 'Standard deviation of values in the raster';


--
-- TOC entry 5336 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.scale; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.scale IS 'Map scale (e.g., 1:250000)';


--
-- TOC entry 5337 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.n_bands; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.n_bands IS 'Number of bands in the raster';


--
-- TOC entry 5338 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.metadata; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.metadata IS 'Array of additional metadata strings';


--
-- TOC entry 5339 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN layer.map; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.layer.map IS 'Generated MapServer MAP file content';


--
-- TOC entry 237 (class 1259 OID 55714928)
-- Name: mapset; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.mapset (
    country_id text NOT NULL,
    project_id text NOT NULL,
    mapped_property_id text,
    mapset_id text NOT NULL,
    costum_group text,
    parent_identifier uuid,
    file_identifier uuid DEFAULT public.uuid_generate_v1(),
    language_code text DEFAULT 'eng'::text,
    metadata_standard_name text DEFAULT 'ISO 19115/19139'::text,
    metadata_standard_version text DEFAULT '1.0'::text,
    reference_system_identifier_code_space text DEFAULT 'EPSG'::text,
    title text,
    unit_of_measure_id text,
    creation_date date,
    publication_date date,
    revision_date date,
    edition text,
    citation_md_identifier_code text,
    citation_md_identifier_code_space text DEFAULT 'doi'::text,
    abstract text,
    status text DEFAULT 'completed'::text,
    update_frequency text DEFAULT 'asNeeded'::text,
    md_browse_graphic text,
    keyword_theme text[],
    keyword_place text[],
    keyword_discipline text[] DEFAULT '{"Soil science"}'::text[],
    access_constraints text DEFAULT 'copyright'::text,
    use_constraints text DEFAULT 'license'::text,
    other_constraints text,
    spatial_representation_type_code text DEFAULT 'grid'::text,
    presentation_form text DEFAULT 'mapDigital'::text,
    topic_category text[] DEFAULT '{geoscientificInformation,environment}'::text[],
    time_period_begin date,
    time_period_end date,
    scope_code text DEFAULT 'dataset'::text,
    lineage_statement text,
    lineage_source_uuidref text,
    lineage_source_title text,
    profile_limit integer,
    spatial_blur_m integer,
    xml text,
    sld text,
    CONSTRAINT mapset_access_constraints_check CHECK ((access_constraints = ANY (ARRAY['copyright'::text, 'patent'::text, 'patentPending'::text, 'trademark'::text, 'license'::text, 'intellectualPropertyRights'::text, 'restricted'::text, 'otherRestrictions'::text]))),
    CONSTRAINT mapset_citation_md_identifier_code_space_check CHECK ((citation_md_identifier_code_space = ANY (ARRAY['doi'::text, 'uuid'::text]))),
    CONSTRAINT mapset_period_dates_order_check CHECK (((time_period_begin IS NULL) OR (time_period_end IS NULL) OR (time_period_begin <= time_period_end))),
    CONSTRAINT mapset_presentation_form_check CHECK ((presentation_form = ANY (ARRAY['mapDigital'::text, 'tableDigital'::text, 'mapHardcopy'::text, 'atlasHardcopy'::text]))),
    CONSTRAINT mapset_publication_after_period_end_check CHECK (((publication_date IS NULL) OR (time_period_end IS NULL) OR (publication_date > time_period_end))),
    CONSTRAINT mapset_spatial_representation_type_code_check CHECK ((spatial_representation_type_code = ANY (ARRAY['grid'::text, 'vector'::text, 'textTable'::text, 'tin'::text, 'stereoModel'::text, 'video'::text]))),
    CONSTRAINT mapset_status_check CHECK ((status = ANY (ARRAY['completed'::text, 'historicalArchive'::text, 'obsolete'::text, 'onGoing'::text, 'planned'::text, 'required'::text, 'underDevelopment'::text]))),
    CONSTRAINT mapset_update_frequency_check CHECK ((update_frequency = ANY (ARRAY['continual'::text, 'daily'::text, 'weekly'::text, 'fortnightly'::text, 'monthly'::text, 'quarterly'::text, 'biannually'::text, 'annually'::text, 'asNeeded'::text, 'irregular'::text, 'notPlanned'::text, 'unknown'::text]))),
    CONSTRAINT mapset_use_constraints_check CHECK ((use_constraints = ANY (ARRAY['copyright'::text, 'patent'::text, 'patentPending'::text, 'trademark'::text, 'license'::text, 'intellectualPropertyRights'::text, 'restricted'::text, 'otherRestrictions'::text]))),
    CONSTRAINT project_license_check CHECK (((other_constraints IS NULL) OR (other_constraints = ANY (ARRAY['CC BY'::text, 'CC BY-SA'::text, 'CC BY-NC'::text, 'CC BY-NC-SA'::text, 'CC BY-ND'::text, 'CC BY-NC-ND'::text, 'CC0'::text, 'Public Domain Mark'::text])))),
    CONSTRAINT project_profile_limit_check CHECK (((profile_limit IS NULL) OR (profile_limit > 0))),
    CONSTRAINT project_spatial_blur_check CHECK (((spatial_blur_m IS NULL) OR (spatial_blur_m >= 0)))
);


ALTER TABLE soil_data.mapset OWNER TO sis;

--
-- TOC entry 5341 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE mapset; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.mapset IS 'Mapset metadata container for organizing related spatial layers with ISO 19139 compliant metadata';


--
-- TOC entry 5342 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.country_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.country_id IS 'Reference to the country';


--
-- TOC entry 5343 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.project_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.project_id IS 'Reference to the project';


--
-- TOC entry 5344 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.mapped_property_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.mapped_property_id IS 'Reference to the soil property';


--
-- TOC entry 5345 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.mapset_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.mapset_id IS 'Unique identifier for the mapset';


--
-- TOC entry 5346 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.parent_identifier; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.parent_identifier IS 'UUID of a parent mapset for hierarchical relationships';


--
-- TOC entry 5347 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.file_identifier; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.file_identifier IS 'UUID for ISO 19139 metadata identification';


--
-- TOC entry 5348 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.language_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.language_code IS 'ISO 639-2 language code for metadata';


--
-- TOC entry 5349 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.metadata_standard_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.metadata_standard_name IS 'Name of the metadata standard used';


--
-- TOC entry 5350 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.metadata_standard_version; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.metadata_standard_version IS 'Version of the metadata standard';


--
-- TOC entry 5351 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.reference_system_identifier_code_space; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.reference_system_identifier_code_space IS 'Code space for CRS (typically EPSG)';


--
-- TOC entry 5352 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.title; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.title IS 'Title of the mapset for display';


--
-- TOC entry 5353 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.unit_of_measure_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.unit_of_measure_id IS 'Reference to the unit of measure';


--
-- TOC entry 5354 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.creation_date; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.creation_date IS 'Date when the mapset was created';


--
-- TOC entry 5355 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.publication_date; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.publication_date IS 'Date when the mapset was published';


--
-- TOC entry 5356 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.revision_date; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.revision_date IS 'Date of the last revision';


--
-- TOC entry 5357 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.edition; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.edition IS 'Edition or version identifier';


--
-- TOC entry 5358 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.citation_md_identifier_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.citation_md_identifier_code IS 'DOI or other persistent identifier';


--
-- TOC entry 5359 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.citation_md_identifier_code_space; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.citation_md_identifier_code_space IS 'Code space for identifier: doi or uuid';


--
-- TOC entry 5360 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.abstract; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.abstract IS 'Abstract describing the mapset content';


--
-- TOC entry 5361 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.status; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.status IS 'ISO 19115 MD_ProgressCode: completed, onGoing, etc.';


--
-- TOC entry 5362 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.update_frequency; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.update_frequency IS 'ISO 19115 MD_MaintenanceFrequencyCode';


--
-- TOC entry 5363 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.md_browse_graphic; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.md_browse_graphic IS 'URL to a browse graphic/thumbnail';


--
-- TOC entry 5364 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.keyword_theme; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.keyword_theme IS 'Array of thematic keywords';


--
-- TOC entry 5365 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.keyword_place; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.keyword_place IS 'Array of place keywords';


--
-- TOC entry 5366 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.keyword_discipline; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.keyword_discipline IS 'Array of discipline keywords';


--
-- TOC entry 5367 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.access_constraints; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.access_constraints IS 'ISO 19115 MD_RestrictionCode for access';


--
-- TOC entry 5368 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.use_constraints; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.use_constraints IS 'ISO 19115 MD_RestrictionCode for use';


--
-- TOC entry 5369 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.other_constraints; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.other_constraints IS 'Text description of other constraints';


--
-- TOC entry 5370 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.spatial_representation_type_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.spatial_representation_type_code IS 'ISO 19115 MD_SpatialRepresentationTypeCode';


--
-- TOC entry 5371 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.presentation_form; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.presentation_form IS 'ISO 19115 CI_PresentationFormCode';


--
-- TOC entry 5372 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.topic_category; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.topic_category IS 'Array of ISO 19115 MD_TopicCategoryCode values';


--
-- TOC entry 5373 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.time_period_begin; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.time_period_begin IS 'Start date of the temporal extent';


--
-- TOC entry 5374 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.time_period_end; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.time_period_end IS 'End date of the temporal extent';


--
-- TOC entry 5375 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.scope_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.scope_code IS 'ISO 19115 MD_ScopeCode';


--
-- TOC entry 5376 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.lineage_statement; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.lineage_statement IS 'Statement describing data lineage';


--
-- TOC entry 5377 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.lineage_source_uuidref; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.lineage_source_uuidref IS 'UUID reference to source data';


--
-- TOC entry 5378 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.lineage_source_title; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.lineage_source_title IS 'Title of source data';


--
-- TOC entry 5379 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.xml; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.xml IS 'Generated ISO 19139 XML metadata';


--
-- TOC entry 5380 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN mapset.sld; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapset.sld IS 'Generated SLD XML for styling';


--
-- TOC entry 238 (class 1259 OID 55714961)
-- Name: observation_num; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.observation_num (
    observation_num_id integer NOT NULL,
    property_num_id text NOT NULL,
    procedure_num_id text NOT NULL,
    unit_of_measure_id text NOT NULL,
    value_min real,
    value_max real,
    typical_min real,
    typical_max real,
    CONSTRAINT obs_num_bounds_consistent CHECK ((((value_min IS NULL) OR (value_max IS NULL) OR (value_min <= value_max)) AND ((typical_min IS NULL) OR (typical_max IS NULL) OR (typical_min <= typical_max)) AND ((value_min IS NULL) OR (typical_min IS NULL) OR (value_min <= typical_min)) AND ((value_max IS NULL) OR (typical_max IS NULL) OR (typical_max <= value_max))))
);


ALTER TABLE soil_data.observation_num OWNER TO sis;

--
-- TOC entry 5382 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE observation_num; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.observation_num IS 'Physio-chemical observations for the Element feature of interest';


--
-- TOC entry 5383 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.observation_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.observation_num_id IS 'Synthetic primary key for the observation';


--
-- TOC entry 5384 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.property_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.property_num_id IS 'Foreign key to the corresponding property';


--
-- TOC entry 5385 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.procedure_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.procedure_num_id IS 'Foreign key to the corresponding procedure';


--
-- TOC entry 5386 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.unit_of_measure_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.unit_of_measure_id IS 'Foreign key to the corresponding unit of measure (if applicable)';


--
-- TOC entry 5387 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.value_min; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.value_min IS 'Minimum admissable value for this combination of property, procedure and unit of measure';


--
-- TOC entry 5388 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN observation_num.value_max; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.observation_num.value_max IS 'Maximum admissable value for this combination of property, procedure and unit of measure';


--
-- TOC entry 239 (class 1259 OID 55714968)
-- Name: plot; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.plot (
    plot_id integer NOT NULL,
    site_id text NOT NULL,
    plot_code text,
    parent_plot_id integer,
    type text,
    altitude smallint,
    sampling_date date,
    positional_accuracy smallint,
    geom public.geometry(Point,4326),
    is_surface boolean DEFAULT false,
    csv text,
    CONSTRAINT plot_type_check CHECK ((type = ANY (ARRAY['TrialPit'::text, 'Borehole'::text])))
);


ALTER TABLE soil_data.plot OWNER TO sis;

--
-- TOC entry 5390 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE plot; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.plot IS 'Elementary area or location where individual observations are made and/or samples are taken. Plot is the main spatial feature of interest in ISO-28258. Plot has three sub-classes: Borehole, Pit and Surface. Surface features its own table since it has its own properties and a different geometry.';


--
-- TOC entry 5391 (class 0 OID 0)
-- Dependencies: 239
-- Name: COLUMN plot.plot_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.plot.plot_id IS 'Synthetic primary key.';


--
-- TOC entry 5392 (class 0 OID 0)
-- Dependencies: 239
-- Name: COLUMN plot.site_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.plot.site_id IS 'Foreign key to Site table.';


--
-- TOC entry 240 (class 1259 OID 55714976)
-- Name: profile; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.profile (
    profile_id integer NOT NULL,
    plot_id integer NOT NULL,
    profile_code character varying
);


ALTER TABLE soil_data.profile OWNER TO sis;

--
-- TOC entry 5394 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE profile; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.profile IS 'An abstract, ordered set of soil horizons and/or layers.';


--
-- TOC entry 5395 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN profile.profile_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.profile.profile_id IS 'Synthetic primary key.';


--
-- TOC entry 5396 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN profile.plot_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.profile.plot_id IS 'Foreign key to Plot feature of interest';


--
-- TOC entry 5397 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN profile.profile_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.profile.profile_code IS 'Natural primary key, if existing';


--
-- TOC entry 241 (class 1259 OID 55714982)
-- Name: project; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.project (
    country_id text NOT NULL,
    project_id text NOT NULL,
    name character varying NOT NULL,
    description text
);


ALTER TABLE soil_data.project OWNER TO sis;

--
-- TOC entry 5399 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE project; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.project IS 'Provides the context of the data collection as a prerequisite for the proper use or reuse of these data.';


--
-- TOC entry 5400 (class 0 OID 0)
-- Dependencies: 241
-- Name: COLUMN project.project_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project.project_id IS 'Synthetic primary key.';


--
-- TOC entry 5401 (class 0 OID 0)
-- Dependencies: 241
-- Name: COLUMN project.name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project.name IS 'Natural key with project name.';


--
-- TOC entry 242 (class 1259 OID 55714988)
-- Name: project_site; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.project_site (
    country_id text NOT NULL,
    project_id text NOT NULL,
    site_id text NOT NULL
);


ALTER TABLE soil_data.project_site OWNER TO sis;

--
-- TOC entry 5403 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE project_site; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.project_site IS 'Junction table linking projects to sites (many-to-many relationship)';


--
-- TOC entry 5404 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN project_site.project_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project_site.project_id IS 'Reference to the project';


--
-- TOC entry 5405 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN project_site.site_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project_site.site_id IS 'Reference to the site';


--
-- TOC entry 243 (class 1259 OID 55714994)
-- Name: result_num; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_num (
    observation_num_id integer NOT NULL,
    specimen_id integer NOT NULL,
    value real NOT NULL
);


ALTER TABLE soil_data.result_num OWNER TO sis;

--
-- TOC entry 244 (class 1259 OID 55714997)
-- Name: site; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.site (
    site_id text NOT NULL,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE soil_data.site OWNER TO sis;

--
-- TOC entry 5407 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE site; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.site IS 'Defined area which is subject to a soil quality investigation. Site is not a spatial feature of interest, but provides the link between the spatial features of interest (Plot) to the Project. The geometry can either be a location (point) or extent (polygon) but not both at the same time.';


--
-- TOC entry 5408 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN site.site_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.site.site_id IS 'Synthetic primary key.';


--
-- TOC entry 5409 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN site.geom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.site.geom IS 'Site extent expressed with geodetic coordinates of the site. Note the uncertainty associated with the WGS84 datum ensemble.';


--
-- TOC entry 245 (class 1259 OID 55715003)
-- Name: specimen; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.specimen (
    specimen_id integer NOT NULL,
    element_id integer NOT NULL,
    code character varying
);


ALTER TABLE soil_data.specimen OWNER TO sis;

--
-- TOC entry 5411 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE specimen; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.specimen IS 'Soil Specimen is defined in ISO-28258 as: "a subtype of SF_Specimen. Soil Specimen may be taken in the Site, Plot, Profile, or ProfileElement including their subtypes." In this database Specimen is for now only associated to Plot for simplification.';


--
-- TOC entry 5412 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN specimen.specimen_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.specimen.specimen_id IS 'Synthetic primary key.';


--
-- TOC entry 5413 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN specimen.element_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.specimen.element_id IS 'Foreign key to the associated soil Plot';


--
-- TOC entry 5414 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN specimen.code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.specimen.code IS 'External code used to identify the soil Specimen (if used).';


--
-- TOC entry 246 (class 1259 OID 55715009)
-- Name: vw_api_manifest; Type: VIEW; Schema: api; Owner: sis
--

CREATE VIEW api.vw_api_manifest AS
 WITH ranked AS (
         SELECT p.profile_id,
            proj.project_id,
            pl.is_published,
            pm.profile_limit,
            pm.spatial_blur_m,
            plt.geom AS raw_geom,
            row_number() OVER (PARTITION BY proj.country_id, proj.project_id ORDER BY p.profile_id) AS rn
           FROM ((((((soil_data.profile p
             JOIN soil_data.plot plt ON ((p.plot_id = plt.plot_id)))
             JOIN soil_data.site s_1 ON ((plt.site_id = s_1.site_id)))
             LEFT JOIN soil_data.project_site ps ON ((s_1.site_id = ps.site_id)))
             LEFT JOIN soil_data.project proj ON (((ps.country_id = proj.country_id) AND (ps.project_id = proj.project_id))))
             LEFT JOIN soil_data.mapset pm ON ((pm.mapset_id = ((proj.country_id || '-'::text) || proj.project_id))))
             LEFT JOIN soil_data.layer pl ON ((pl.layer_id = ((proj.country_id || '-'::text) || proj.project_id))))
          WHERE (plt.geom IS NOT NULL)
        ), published AS (
         SELECT ranked.profile_id,
            api.blur_geom(ranked.raw_geom, (ranked.profile_id)::text, ranked.spatial_blur_m) AS geom
           FROM ranked
          WHERE ((ranked.is_published = true) AND ((ranked.profile_limit IS NULL) OR (ranked.rn <= ranked.profile_limit)))
        )
 SELECT opc.property_num_id AS property,
    count(DISTINCT pp.profile_id) AS profiles,
    count(*) AS observations,
    public.st_envelope(public.st_collect(pp.geom)) AS geom
   FROM ((((published pp
     JOIN soil_data.element e ON ((e.profile_id = pp.profile_id)))
     JOIN soil_data.specimen s ON ((s.element_id = e.element_id)))
     JOIN soil_data.result_num rpc ON ((rpc.specimen_id = s.specimen_id)))
     JOIN soil_data.observation_num opc ON ((opc.observation_num_id = rpc.observation_num_id)))
  GROUP BY opc.property_num_id
  ORDER BY opc.property_num_id;


ALTER VIEW api.vw_api_manifest OWNER TO sis;

--
-- TOC entry 247 (class 1259 OID 55715014)
-- Name: vw_api_observation; Type: VIEW; Schema: api; Owner: sis
--

CREATE VIEW api.vw_api_observation AS
 WITH ranked AS (
         SELECT p3.profile_id,
            p3.profile_code,
            proj.project_id,
            pl.is_published,
            pm.profile_limit,
            row_number() OVER (PARTITION BY proj.country_id, proj.project_id ORDER BY p3.profile_id) AS rn
           FROM ((((((soil_data.project proj
             LEFT JOIN soil_data.mapset pm ON ((pm.mapset_id = ((proj.country_id || '-'::text) || proj.project_id))))
             LEFT JOIN soil_data.layer pl ON ((pl.layer_id = ((proj.country_id || '-'::text) || proj.project_id))))
             LEFT JOIN soil_data.project_site sp ON (((sp.country_id = proj.country_id) AND (sp.project_id = proj.project_id))))
             LEFT JOIN soil_data.site s ON ((s.site_id = sp.site_id)))
             LEFT JOIN soil_data.plot p2 ON ((p2.site_id = s.site_id)))
             LEFT JOIN soil_data.profile p3 ON ((p3.plot_id = p2.plot_id)))
          WHERE (p3.profile_id IS NOT NULL)
        ), published AS (
         SELECT ranked.profile_id,
            ranked.profile_code
           FROM ranked
          WHERE ((ranked.is_published = true) AND ((ranked.profile_limit IS NULL) OR (ranked.rn <= ranked.profile_limit)))
        )
 SELECT pp.profile_code,
    e.upper_depth,
    e.lower_depth,
    o.property_num_id,
    o.procedure_num_id,
    r.value,
    o.unit_of_measure_id
   FROM ((((published pp
     LEFT JOIN soil_data.element e ON ((e.profile_id = pp.profile_id)))
     LEFT JOIN soil_data.specimen s2 ON ((s2.element_id = e.element_id)))
     LEFT JOIN soil_data.result_num r ON ((r.specimen_id = s2.specimen_id)))
     LEFT JOIN soil_data.observation_num o ON ((o.observation_num_id = r.observation_num_id)))
  ORDER BY pp.profile_code, e.upper_depth, o.property_num_id;


ALTER VIEW api.vw_api_observation OWNER TO sis;

--
-- TOC entry 248 (class 1259 OID 55715019)
-- Name: vw_api_profile; Type: VIEW; Schema: api; Owner: sis
--

CREATE VIEW api.vw_api_profile AS
 WITH ranked AS (
         SELECT p.profile_id AS gid,
            p.profile_code,
            proj.project_id,
            proj.name AS project_name,
            ((proj.country_id || '-'::text) || proj.project_id) AS mapset_id,
            pl.is_published,
            pm.profile_limit,
            pm.spatial_blur_m,
            plt.altitude,
            plt.sampling_date AS date,
            plt.geom AS raw_geom,
            row_number() OVER (PARTITION BY proj.country_id, proj.project_id ORDER BY p.profile_id) AS rn
           FROM ((((((soil_data.profile p
             JOIN soil_data.plot plt ON ((p.plot_id = plt.plot_id)))
             JOIN soil_data.site s ON ((plt.site_id = s.site_id)))
             LEFT JOIN soil_data.project_site ps ON ((s.site_id = ps.site_id)))
             LEFT JOIN soil_data.project proj ON (((ps.country_id = proj.country_id) AND (ps.project_id = proj.project_id))))
             LEFT JOIN soil_data.mapset pm ON ((pm.mapset_id = ((proj.country_id || '-'::text) || proj.project_id))))
             LEFT JOIN soil_data.layer pl ON ((pl.layer_id = ((proj.country_id || '-'::text) || proj.project_id))))
          WHERE (plt.geom IS NOT NULL)
        ), pub AS (
         SELECT ranked.gid,
            ranked.profile_code,
            ranked.project_name,
            ranked.mapset_id,
            ranked.altitude,
            ranked.date,
            api.blur_geom(ranked.raw_geom, (ranked.gid)::text, ranked.spatial_blur_m) AS geom
           FROM ranked
          WHERE ((ranked.is_published = true) AND ((ranked.profile_limit IS NULL) OR (ranked.rn <= ranked.profile_limit)))
        )
 SELECT pub.gid,
    pub.profile_code,
    pub.project_name,
    pub.mapset_id,
    pub.altitude,
    pub.date,
    pub.geom,
    (public.st_asgeojson(pub.geom))::json AS geometry
   FROM pub
  ORDER BY pub.gid;


ALTER VIEW api.vw_api_profile OWNER TO sis;

--
-- TOC entry 249 (class 1259 OID 55715024)
-- Name: vw_glosis_federation_token; Type: VIEW; Schema: api; Owner: sis
--

CREATE VIEW api.vw_glosis_federation_token AS
 SELECT api_client.api_client_id,
    api_client.api_key,
    api_client.is_active,
    api_client.expires_at
   FROM api.api_client
  WHERE (api_client.description = 'glosis-federation'::text);


ALTER VIEW api.vw_glosis_federation_token OWNER TO sis;

--
-- TOC entry 250 (class 1259 OID 55715028)
-- Name: category_desc; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.category_desc (
    category_desc_id text NOT NULL,
    notation text,
    category_name text,
    definition text,
    uri text
);


ALTER TABLE soil_data.category_desc OWNER TO sis;

--
-- TOC entry 5420 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE category_desc; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.category_desc IS 'Controlled vocabulary categories for descriptive properties. Contains thesaurus entries from GloSIS or other vocabularies.';


--
-- TOC entry 5421 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN category_desc.category_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.category_desc.category_desc_id IS 'Primary key identifier for the category';


--
-- TOC entry 251 (class 1259 OID 55715034)
-- Name: class; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.class (
    mapset_id text NOT NULL,
    value real NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    color text NOT NULL,
    opacity real NOT NULL,
    publish boolean NOT NULL
);


ALTER TABLE soil_data.class OWNER TO sis;

--
-- TOC entry 5423 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE class; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.class IS 'Legend classes for mapsets defining color and label for value ranges or categories';


--
-- TOC entry 5424 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.mapset_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.mapset_id IS 'Reference to the mapset this class belongs to';


--
-- TOC entry 5425 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.value; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.value IS 'Numeric value (for quantitative) or category code (for categorical)';


--
-- TOC entry 5426 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.code IS 'Short code for the class';


--
-- TOC entry 5427 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.label; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.label IS 'Display label for the class in legends';


--
-- TOC entry 5428 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.color; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.color IS 'Hex color code for map display (e.g., #FF5733)';


--
-- TOC entry 5429 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.opacity; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.opacity IS 'Opacity value from 0 to 1';


--
-- TOC entry 5430 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN class.publish; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.class.publish IS 'Flag indicating whether this class should be published';


--
-- TOC entry 252 (class 1259 OID 55715040)
-- Name: country; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.country (
    country_id character(2) NOT NULL,
    iso3_code character(3),
    gaul_code integer,
    color_code character(3),
    ar text,
    en text,
    es text,
    fr text,
    pt text,
    ru text,
    zh text,
    status text,
    disp_area character varying(3),
    capital text,
    continent text,
    un_reg text,
    geom_centroid public.geometry(Point,4326),
    geom_convexhull public.geometry(MultiPolygon,4326)
);


ALTER TABLE soil_data.country OWNER TO sis;

--
-- TOC entry 5432 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE country; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.country IS 'Reference table of countries with ISO codes and multilingual names';


--
-- TOC entry 5433 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.country_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.country_id IS 'ISO 3166-1 alpha-2 country code (primary key)';


--
-- TOC entry 5434 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.iso3_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.iso3_code IS 'ISO 3166-1 alpha-3 country code';


--
-- TOC entry 5435 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.gaul_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.gaul_code IS 'FAO GAUL country code';


--
-- TOC entry 5436 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.color_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.color_code IS 'Color code for map display';


--
-- TOC entry 5437 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.ar; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.ar IS 'Country name in Arabic';


--
-- TOC entry 5438 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.en; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.en IS 'Country name in English';


--
-- TOC entry 5439 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.es; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.es IS 'Country name in Spanish';


--
-- TOC entry 5440 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.fr; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.fr IS 'Country name in French';


--
-- TOC entry 5441 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.pt; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.pt IS 'Country name in Portuguese';


--
-- TOC entry 5442 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.ru; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.ru IS 'Country name in Russian';


--
-- TOC entry 5443 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.zh; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.zh IS 'Country name in Chinese';


--
-- TOC entry 5444 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.status; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.status IS 'Country status (e.g., Member State, Territory)';


--
-- TOC entry 5445 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.disp_area; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.disp_area IS 'Disputed area indicator';


--
-- TOC entry 5446 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.capital; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.capital IS 'Capital city name';


--
-- TOC entry 5447 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.continent; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.continent IS 'Continent name';


--
-- TOC entry 5448 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN country.un_reg; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.country.un_reg IS 'UN region classification';


--
-- TOC entry 253 (class 1259 OID 55715046)
-- Name: element_element_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.element ALTER COLUMN element_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.element_element_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 254 (class 1259 OID 55715048)
-- Name: individual; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.individual (
    individual_id text NOT NULL,
    email text
);


ALTER TABLE soil_data.individual OWNER TO sis;

--
-- TOC entry 5451 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE individual; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.individual IS 'Individuals associated with soil data collection, analysis, or project management';


--
-- TOC entry 5452 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN individual.individual_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.individual.individual_id IS 'Unique identifier for the individual (typically name)';


--
-- TOC entry 5453 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN individual.email; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.individual.email IS 'Email address of the individual';


--
-- TOC entry 255 (class 1259 OID 55715054)
-- Name: languages; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.languages (
    language_code text NOT NULL,
    language_name text NOT NULL
);


ALTER TABLE soil_data.languages OWNER TO sis;

--
-- TOC entry 5455 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE languages; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.languages IS 'Reference table of supported languages for translations';


--
-- TOC entry 5456 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN languages.language_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.languages.language_code IS 'ISO 639-1 two-letter language code';


--
-- TOC entry 5457 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN languages.language_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.languages.language_name IS 'Full name of the language in English';


--
-- TOC entry 256 (class 1259 OID 55715060)
-- Name: mapped_property; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.mapped_property (
    mapped_property_id text NOT NULL,
    name text NOT NULL,
    property_num_id text,
    min real,
    max real,
    property_type text NOT NULL,
    num_intervals smallint NOT NULL,
    start_color text NOT NULL,
    end_color text NOT NULL,
    keyword_theme text[],
    CONSTRAINT property_property_type_check CHECK ((property_type = ANY (ARRAY['quantitative'::text, 'categorical'::text])))
);


ALTER TABLE soil_data.mapped_property OWNER TO sis;

--
-- TOC entry 5459 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE mapped_property; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.mapped_property IS 'Soil properties for spatial data layers with visualization settings';


--
-- TOC entry 5460 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.mapped_property_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.mapped_property_id IS 'Unique identifier for the property';


--
-- TOC entry 5461 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.name IS 'Human-readable name of the property';


--
-- TOC entry 5462 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.property_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.property_num_id IS 'Reference to the numerical property definition';


--
-- TOC entry 5463 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.min; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.min IS 'Expected minimum value for the property';


--
-- TOC entry 5464 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.max; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.max IS 'Expected maximum value for the property';


--
-- TOC entry 5465 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.property_type; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.property_type IS 'Type: quantitative or categorical';


--
-- TOC entry 5466 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.num_intervals; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.num_intervals IS 'Number of classification intervals for legends';


--
-- TOC entry 5467 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.start_color; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.start_color IS 'Start color for gradient (hex format)';


--
-- TOC entry 5468 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.end_color; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.end_color IS 'End color for gradient (hex format)';


--
-- TOC entry 5469 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN mapped_property.keyword_theme; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.mapped_property.keyword_theme IS 'Array of thematic keywords for this property';


--
-- TOC entry 257 (class 1259 OID 55715067)
-- Name: observation_desc; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.observation_desc (
    procedure_desc_id text NOT NULL,
    property_desc_id text NOT NULL,
    category_desc_id text NOT NULL,
    category_order smallint,
    plot boolean,
    surface boolean,
    profile boolean,
    element boolean
);


ALTER TABLE soil_data.observation_desc OWNER TO sis;

--
-- TOC entry 258 (class 1259 OID 55715073)
-- Name: observation_num_observation_num_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.observation_num ALTER COLUMN observation_num_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.observation_num_observation_num_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 259 (class 1259 OID 55715075)
-- Name: organisation; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.organisation (
    organisation_id text NOT NULL,
    url text,
    email text,
    country text,
    city text,
    postal_code text,
    delivery_point text,
    phone text,
    facsimile text
);


ALTER TABLE soil_data.organisation OWNER TO sis;

--
-- TOC entry 5472 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE organisation; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.organisation IS 'Organizations involved in soil data projects and surveys';


--
-- TOC entry 5473 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.organisation_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.organisation_id IS 'Unique identifier for the organization (typically name)';


--
-- TOC entry 5474 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.url; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.url IS 'Website URL of the organization';


--
-- TOC entry 5475 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.email; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.email IS 'Contact email for the organization';


--
-- TOC entry 5476 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.country; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.country IS 'Country where the organization is located';


--
-- TOC entry 5477 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.city; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.city IS 'City where the organization is located';


--
-- TOC entry 5478 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.postal_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.postal_code IS 'Postal code of the organization address';


--
-- TOC entry 5479 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.delivery_point; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.delivery_point IS 'Street address of the organization';


--
-- TOC entry 5480 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.phone; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.phone IS 'Phone number of the organization';


--
-- TOC entry 5481 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN organisation.facsimile; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.organisation.facsimile IS 'Fax number of the organization';


--
-- TOC entry 260 (class 1259 OID 55715081)
-- Name: plot_plot_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.plot ALTER COLUMN plot_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.plot_plot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 261 (class 1259 OID 55715083)
-- Name: procedure_desc; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_desc (
    procedure_desc_id text NOT NULL,
    reference character varying,
    uri character varying NOT NULL
);


ALTER TABLE soil_data.procedure_desc OWNER TO sis;

--
-- TOC entry 5484 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE procedure_desc; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.procedure_desc IS 'Descriptive Procedures for all features of interest. In most cases the procedure is described in a document such as the FAO Guidelines for Soil Description or the World Reference Base of Soil Resources.';


--
-- TOC entry 5485 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN procedure_desc.procedure_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.procedure_desc.procedure_desc_id IS 'Synthetic primary key.';


--
-- TOC entry 5486 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN procedure_desc.reference; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.procedure_desc.reference IS 'Long and human readable reference to the publication.';


--
-- TOC entry 5487 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN procedure_desc.uri; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.procedure_desc.uri IS 'URI to the corresponding publication, optimally a DOI. Follow this URI for the full definition of the procedure.';


--
-- TOC entry 262 (class 1259 OID 55715089)
-- Name: procedure_model; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_model (
    procedure_model_id integer NOT NULL,
    procedure_name text
);


ALTER TABLE soil_data.procedure_model OWNER TO sis;

--
-- TOC entry 263 (class 1259 OID 55715095)
-- Name: procedure_model_def; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_model_def (
    procedure_model_id integer NOT NULL,
    key text NOT NULL,
    value text NOT NULL
);


ALTER TABLE soil_data.procedure_model_def OWNER TO sis;

--
-- TOC entry 264 (class 1259 OID 55715101)
-- Name: procedure_model_procedure_model_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.procedure_model ALTER COLUMN procedure_model_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.procedure_model_procedure_model_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 265 (class 1259 OID 55715103)
-- Name: procedure_num; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_num (
    procedure_num_id text NOT NULL,
    broader_id text,
    procedure_name text,
    reference text,
    citation text,
    uri text
);


ALTER TABLE soil_data.procedure_num OWNER TO sis;

--
-- TOC entry 5489 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE procedure_num; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.procedure_num IS 'Physio-chemical Procedures for the Profile Element feature of interest';


--
-- TOC entry 5490 (class 0 OID 0)
-- Dependencies: 265
-- Name: COLUMN procedure_num.procedure_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.procedure_num.procedure_num_id IS 'Synthetic primary key.';


--
-- TOC entry 5491 (class 0 OID 0)
-- Dependencies: 265
-- Name: COLUMN procedure_num.broader_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.procedure_num.broader_id IS 'Foreign key to brader procedure in the hierarchy';


--
-- TOC entry 266 (class 1259 OID 55715109)
-- Name: procedure_spectrometer; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_spectrometer (
    procedure_spectrometer_id integer NOT NULL,
    procedure_name text
);


ALTER TABLE soil_data.procedure_spectrometer OWNER TO sis;

--
-- TOC entry 267 (class 1259 OID 55715115)
-- Name: procedure_spectrometer_def; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.procedure_spectrometer_def (
    procedure_spectrometer_id integer NOT NULL,
    key text NOT NULL,
    value text NOT NULL
);


ALTER TABLE soil_data.procedure_spectrometer_def OWNER TO sis;

--
-- TOC entry 268 (class 1259 OID 55715121)
-- Name: procedure_spectrometer_procedure_spectrometer_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.procedure_spectrometer ALTER COLUMN procedure_spectrometer_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.procedure_spectrometer_procedure_spectrometer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 269 (class 1259 OID 55715123)
-- Name: profile_profile_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.profile ALTER COLUMN profile_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.profile_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 270 (class 1259 OID 55715125)
-- Name: proj_x_org_x_ind; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.proj_x_org_x_ind (
    country_id text NOT NULL,
    project_id text NOT NULL,
    organisation_id text NOT NULL,
    individual_id text NOT NULL,
    "position" text NOT NULL,
    tag text NOT NULL,
    role text NOT NULL,
    CONSTRAINT proj_x_org_x_ind_role_check CHECK ((role = ANY (ARRAY['author'::text, 'custodian'::text, 'distributor'::text, 'originator'::text, 'owner'::text, 'pointOfContact'::text, 'principalInvestigator'::text, 'processor'::text, 'publisher'::text, 'resourceProvider'::text, 'user'::text]))),
    CONSTRAINT proj_x_org_x_ind_tag_check CHECK ((tag = ANY (ARRAY['contact'::text, 'pointOfContact'::text])))
);


ALTER TABLE soil_data.proj_x_org_x_ind OWNER TO sis;

--
-- TOC entry 5494 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE proj_x_org_x_ind; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.proj_x_org_x_ind IS 'Junction table linking projects, organizations, and individuals with their roles';


--
-- TOC entry 5495 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind.project_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind.project_id IS 'Reference to the project';


--
-- TOC entry 5496 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind.organisation_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind.organisation_id IS 'Reference to the organization';


--
-- TOC entry 5497 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind.individual_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind.individual_id IS 'Reference to the individual';


--
-- TOC entry 5498 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind."position"; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind."position" IS 'Position or job title of the individual within the organization';


--
-- TOC entry 5499 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind.tag; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind.tag IS 'Contact type: contact or pointOfContact';


--
-- TOC entry 5500 (class 0 OID 0)
-- Dependencies: 270
-- Name: COLUMN proj_x_org_x_ind.role; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.proj_x_org_x_ind.role IS 'ISO 19115 CI_RoleCode: author, custodian, distributor, etc.';


--
-- TOC entry 271 (class 1259 OID 55715133)
-- Name: project_soil_map; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.project_soil_map (
    country_id text NOT NULL,
    project_id text NOT NULL,
    soil_map_id integer NOT NULL,
    remarks text
);


ALTER TABLE soil_data.project_soil_map OWNER TO sis;

--
-- TOC entry 5502 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE project_soil_map; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.project_soil_map IS 'Links soil maps to projects (relatedMap many-to-many)';


--
-- TOC entry 5503 (class 0 OID 0)
-- Dependencies: 271
-- Name: COLUMN project_soil_map.project_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project_soil_map.project_id IS 'Reference to the project';


--
-- TOC entry 5504 (class 0 OID 0)
-- Dependencies: 271
-- Name: COLUMN project_soil_map.soil_map_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project_soil_map.soil_map_id IS 'Reference to the soil map (relatedMap)';


--
-- TOC entry 5505 (class 0 OID 0)
-- Dependencies: 271
-- Name: COLUMN project_soil_map.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.project_soil_map.remarks IS 'Additional remarks or notes';


--
-- TOC entry 272 (class 1259 OID 55715139)
-- Name: property_desc; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.property_desc (
    property_desc_id text NOT NULL,
    property_name text,
    definition text,
    uri text
);


ALTER TABLE soil_data.property_desc OWNER TO sis;

--
-- TOC entry 5507 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE property_desc; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.property_desc IS 'Descriptive soil properties used for categorical observations';


--
-- TOC entry 5508 (class 0 OID 0)
-- Dependencies: 272
-- Name: COLUMN property_desc.property_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.property_desc.property_desc_id IS 'Primary key identifier for the property';


--
-- TOC entry 5509 (class 0 OID 0)
-- Dependencies: 272
-- Name: COLUMN property_desc.property_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.property_desc.property_name IS 'Human-readable display name for the property';


--
-- TOC entry 273 (class 1259 OID 55715145)
-- Name: property_num; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.property_num (
    property_num_id text NOT NULL,
    property_name text,
    definition text,
    uri text
);


ALTER TABLE soil_data.property_num OWNER TO sis;

--
-- TOC entry 5511 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE property_num; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.property_num IS 'Physio-chemical properties for the Element feature of interest';


--
-- TOC entry 5512 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN property_num.property_num_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.property_num.property_num_id IS 'Synthetic primary key.';


--
-- TOC entry 274 (class 1259 OID 55715151)
-- Name: result_desc_element; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_desc_element (
    element_id integer NOT NULL,
    property_desc_id text NOT NULL,
    category_desc_id text NOT NULL
);


ALTER TABLE soil_data.result_desc_element OWNER TO sis;

--
-- TOC entry 5514 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE result_desc_element; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.result_desc_element IS 'Descriptive results for the Element feature interest.';


--
-- TOC entry 5515 (class 0 OID 0)
-- Dependencies: 274
-- Name: COLUMN result_desc_element.element_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_element.element_id IS 'Foreign key to the corresponding Element feature of interest.';


--
-- TOC entry 5516 (class 0 OID 0)
-- Dependencies: 274
-- Name: COLUMN result_desc_element.property_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_element.property_desc_id IS 'Foreign key to property_desc_element table.';


--
-- TOC entry 5517 (class 0 OID 0)
-- Dependencies: 274
-- Name: COLUMN result_desc_element.category_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_element.category_desc_id IS 'Foreign key to thesaurus_desc_element table.';


--
-- TOC entry 275 (class 1259 OID 55715157)
-- Name: result_desc_plot; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_desc_plot (
    plot_id integer NOT NULL,
    property_desc_id text NOT NULL,
    category_desc_id text NOT NULL
);


ALTER TABLE soil_data.result_desc_plot OWNER TO sis;

--
-- TOC entry 5519 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE result_desc_plot; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.result_desc_plot IS 'Descriptive results for the Plot feature interest.';


--
-- TOC entry 5520 (class 0 OID 0)
-- Dependencies: 275
-- Name: COLUMN result_desc_plot.plot_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_plot.plot_id IS 'Foreign key to the corresponding Plot feature of interest.';


--
-- TOC entry 5521 (class 0 OID 0)
-- Dependencies: 275
-- Name: COLUMN result_desc_plot.property_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_plot.property_desc_id IS 'Foreign key to property_desc_plot table.';


--
-- TOC entry 5522 (class 0 OID 0)
-- Dependencies: 275
-- Name: COLUMN result_desc_plot.category_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_plot.category_desc_id IS 'Foreign key to thesaurus_desc_plot table.';


--
-- TOC entry 276 (class 1259 OID 55715163)
-- Name: result_desc_profile; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_desc_profile (
    profile_id integer NOT NULL,
    property_desc_id text NOT NULL,
    category_desc_id text NOT NULL
);


ALTER TABLE soil_data.result_desc_profile OWNER TO sis;

--
-- TOC entry 5524 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE result_desc_profile; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.result_desc_profile IS 'Descriptive results for the Profile feature interest.';


--
-- TOC entry 5525 (class 0 OID 0)
-- Dependencies: 276
-- Name: COLUMN result_desc_profile.profile_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_profile.profile_id IS 'Foreign key to the corresponding Profile feature of interest.';


--
-- TOC entry 5526 (class 0 OID 0)
-- Dependencies: 276
-- Name: COLUMN result_desc_profile.property_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_profile.property_desc_id IS 'Foreign key to property_desc_profile table.';


--
-- TOC entry 5527 (class 0 OID 0)
-- Dependencies: 276
-- Name: COLUMN result_desc_profile.category_desc_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.result_desc_profile.category_desc_id IS 'Foreign key to thesaurus_desc_profile table.';


--
-- TOC entry 277 (class 1259 OID 55715169)
-- Name: result_desc_surface; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_desc_surface (
    surface_id integer NOT NULL,
    property_desc_id text NOT NULL,
    category_desc_id text NOT NULL
);


ALTER TABLE soil_data.result_desc_surface OWNER TO sis;

--
-- TOC entry 278 (class 1259 OID 55715175)
-- Name: result_spectral; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.result_spectral (
    result_spectral_id integer NOT NULL,
    observation_num_id integer NOT NULL,
    procedure_model_id integer NOT NULL,
    value real NOT NULL
);


ALTER TABLE soil_data.result_spectral OWNER TO sis;

--
-- TOC entry 279 (class 1259 OID 55715178)
-- Name: result_spectral_result_spectral_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.result_spectral ALTER COLUMN result_spectral_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.result_spectral_result_spectral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 280 (class 1259 OID 55715180)
-- Name: soil_map; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_map (
    soil_map_id integer NOT NULL,
    name text NOT NULL,
    description text,
    scale_denominator integer,
    spatial_resolution_m numeric(10,2),
    publication_date date,
    remarks text,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE soil_data.soil_map OWNER TO sis;

--
-- TOC entry 5529 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE soil_map; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_map IS 'A soil map containing delineated mapping units (ISO 28258 SoilMap feature)';


--
-- TOC entry 5530 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.soil_map_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.soil_map_id IS 'Unique identifier for the soil map';


--
-- TOC entry 5531 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.name IS 'Name of the soil map';


--
-- TOC entry 5532 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.description; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.description IS 'Detailed description of the soil map';


--
-- TOC entry 5533 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.scale_denominator; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.scale_denominator IS 'Map scale denominator (e.g., 50000 for 1:50,000)';


--
-- TOC entry 5534 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.spatial_resolution_m; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.spatial_resolution_m IS 'Spatial resolution in meters';


--
-- TOC entry 5535 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.publication_date; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.publication_date IS 'Date when the map was published';


--
-- TOC entry 5536 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.remarks IS 'Additional remarks or notes';


--
-- TOC entry 5537 (class 0 OID 0)
-- Dependencies: 280
-- Name: COLUMN soil_map.geom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_map.geom IS 'Polygon geometry representing the map extent (EPSG:4326)';


--
-- TOC entry 281 (class 1259 OID 55715186)
-- Name: soil_map_soil_map_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.soil_map ALTER COLUMN soil_map_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.soil_map_soil_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 282 (class 1259 OID 55715188)
-- Name: soil_mapping_unit; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_mapping_unit (
    mapping_unit_id integer NOT NULL,
    category_id integer NOT NULL,
    explanation text,
    remarks text,
    geom public.geometry(MultiPolygon,4326) NOT NULL
);


ALTER TABLE soil_data.soil_mapping_unit OWNER TO sis;

--
-- TOC entry 5540 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE soil_mapping_unit; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_mapping_unit IS 'Delineated polygon on a soil map (ISO 28258 SoilMappingUnit feature)';


--
-- TOC entry 5541 (class 0 OID 0)
-- Dependencies: 282
-- Name: COLUMN soil_mapping_unit.mapping_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit.mapping_unit_id IS 'Unique identifier for the mapping unit';


--
-- TOC entry 5542 (class 0 OID 0)
-- Dependencies: 282
-- Name: COLUMN soil_mapping_unit.category_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit.category_id IS 'Reference to the mapping unit category (required, many-to-one)';


--
-- TOC entry 5543 (class 0 OID 0)
-- Dependencies: 282
-- Name: COLUMN soil_mapping_unit.explanation; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit.explanation IS 'Explanation or description of the mapping unit';


--
-- TOC entry 5544 (class 0 OID 0)
-- Dependencies: 282
-- Name: COLUMN soil_mapping_unit.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit.remarks IS 'Additional remarks or notes';


--
-- TOC entry 5545 (class 0 OID 0)
-- Dependencies: 282
-- Name: COLUMN soil_mapping_unit.geom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit.geom IS 'MultiPolygon geometry of the mapping unit (EPSG:4326)';


--
-- TOC entry 283 (class 1259 OID 55715194)
-- Name: soil_mapping_unit_category; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_mapping_unit_category (
    category_id integer NOT NULL,
    soil_map_id integer,
    parent_category_id integer,
    name text NOT NULL,
    description text,
    legend_order integer,
    symbol text,
    colour_rgb text,
    remarks text
);


ALTER TABLE soil_data.soil_mapping_unit_category OWNER TO sis;

--
-- TOC entry 5547 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE soil_mapping_unit_category; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_mapping_unit_category IS 'Legend category describing soil types in a map with hierarchical subcategories (ISO 28258 SoilMappingUnitCategory)';


--
-- TOC entry 5548 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.category_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.category_id IS 'Unique identifier for the category';


--
-- TOC entry 5549 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.soil_map_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.soil_map_id IS 'Reference to soil map - only set for root categories (rootCategory relationship)';


--
-- TOC entry 5550 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.parent_category_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.parent_category_id IS 'Reference to parent category for subcategory hierarchy';


--
-- TOC entry 5551 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.name IS 'Name of the mapping unit category';


--
-- TOC entry 5552 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.description; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.description IS 'Detailed description of the category';


--
-- TOC entry 5553 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.legend_order; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.legend_order IS 'Order in the map legend';


--
-- TOC entry 5554 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.symbol; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.symbol IS 'Symbol used in the map legend';


--
-- TOC entry 5555 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.colour_rgb; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.colour_rgb IS 'RGB colour code for map display (e.g., #A52A2A)';


--
-- TOC entry 5556 (class 0 OID 0)
-- Dependencies: 283
-- Name: COLUMN soil_mapping_unit_category.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_category.remarks IS 'Additional remarks or notes';


--
-- TOC entry 284 (class 1259 OID 55715200)
-- Name: soil_mapping_unit_category_category_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.soil_mapping_unit_category ALTER COLUMN category_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.soil_mapping_unit_category_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 285 (class 1259 OID 55715202)
-- Name: soil_mapping_unit_mapping_unit_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.soil_mapping_unit ALTER COLUMN mapping_unit_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.soil_mapping_unit_mapping_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 286 (class 1259 OID 55715204)
-- Name: soil_mapping_unit_profile; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_mapping_unit_profile (
    mapping_unit_id integer NOT NULL,
    profile_id integer NOT NULL,
    is_representative boolean DEFAULT true,
    remarks text
);


ALTER TABLE soil_data.soil_mapping_unit_profile OWNER TO sis;

--
-- TOC entry 5560 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE soil_mapping_unit_profile; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_mapping_unit_profile IS 'Links profiles to mapping units (profile relationship 0..*)';


--
-- TOC entry 5561 (class 0 OID 0)
-- Dependencies: 286
-- Name: COLUMN soil_mapping_unit_profile.mapping_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_profile.mapping_unit_id IS 'Reference to the soil mapping unit (SMU)';


--
-- TOC entry 5562 (class 0 OID 0)
-- Dependencies: 286
-- Name: COLUMN soil_mapping_unit_profile.profile_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_profile.profile_id IS 'Reference to the soil profile';


--
-- TOC entry 5563 (class 0 OID 0)
-- Dependencies: 286
-- Name: COLUMN soil_mapping_unit_profile.is_representative; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_profile.is_representative IS 'Whether this profile is representative for the mapping unit';


--
-- TOC entry 5564 (class 0 OID 0)
-- Dependencies: 286
-- Name: COLUMN soil_mapping_unit_profile.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_mapping_unit_profile.remarks IS 'Additional remarks or notes';


--
-- TOC entry 287 (class 1259 OID 55715211)
-- Name: soil_typological_unit; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_typological_unit (
    typological_unit_id integer NOT NULL,
    name text NOT NULL,
    classification_scheme text NOT NULL,
    classification_version text NOT NULL,
    description text,
    remarks text
);


ALTER TABLE soil_data.soil_typological_unit OWNER TO sis;

--
-- TOC entry 5566 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE soil_typological_unit; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_typological_unit IS 'Soil type classification unit (ISO 28258 SoilTypologicalUnit feature)';


--
-- TOC entry 5567 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.typological_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.typological_unit_id IS 'Unique identifier for the typological unit';


--
-- TOC entry 5568 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.name IS 'Name of the soil typological unit';


--
-- TOC entry 5569 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.classification_scheme; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.classification_scheme IS 'Classification scheme used (e.g., WRB, Soil Taxonomy)';


--
-- TOC entry 5570 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.classification_version; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.classification_version IS 'Version of the Classification scheme used';


--
-- TOC entry 5571 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.description; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.description IS 'Detailed description of the typological unit';


--
-- TOC entry 5572 (class 0 OID 0)
-- Dependencies: 287
-- Name: COLUMN soil_typological_unit.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit.remarks IS 'Additional remarks or notes';


--
-- TOC entry 288 (class 1259 OID 55715217)
-- Name: soil_typological_unit_mapping_unit; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_typological_unit_mapping_unit (
    typological_unit_id integer NOT NULL,
    mapping_unit_id integer NOT NULL,
    percentage smallint NOT NULL,
    remarks text,
    CONSTRAINT chk_percentage_range CHECK (((percentage > 0) AND (percentage <= 100)))
);


ALTER TABLE soil_data.soil_typological_unit_mapping_unit OWNER TO sis;

--
-- TOC entry 5574 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE soil_typological_unit_mapping_unit; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_typological_unit_mapping_unit IS 'Links typological units to mapping units with percentage composition (representedUnit/mapRepresentation). Percentages per SMU should sum to 100%.';


--
-- TOC entry 5575 (class 0 OID 0)
-- Dependencies: 288
-- Name: COLUMN soil_typological_unit_mapping_unit.typological_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_mapping_unit.typological_unit_id IS 'Reference to the soil typological unit (STU)';


--
-- TOC entry 5576 (class 0 OID 0)
-- Dependencies: 288
-- Name: COLUMN soil_typological_unit_mapping_unit.mapping_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_mapping_unit.mapping_unit_id IS 'Reference to the soil mapping unit (SMU)';


--
-- TOC entry 5577 (class 0 OID 0)
-- Dependencies: 288
-- Name: COLUMN soil_typological_unit_mapping_unit.percentage; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_mapping_unit.percentage IS 'Percentage of the STU within the SMU (sum per SMU should equal 100)';


--
-- TOC entry 5578 (class 0 OID 0)
-- Dependencies: 288
-- Name: COLUMN soil_typological_unit_mapping_unit.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_mapping_unit.remarks IS 'Additional remarks or notes';


--
-- TOC entry 289 (class 1259 OID 55715224)
-- Name: soil_typological_unit_profile; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.soil_typological_unit_profile (
    typological_unit_id integer NOT NULL,
    profile_id integer NOT NULL,
    is_typical boolean DEFAULT true,
    remarks text
);


ALTER TABLE soil_data.soil_typological_unit_profile OWNER TO sis;

--
-- TOC entry 5580 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE soil_typological_unit_profile; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.soil_typological_unit_profile IS 'Links profiles to typological units as typical profiles (typicalProfile relationship)';


--
-- TOC entry 5581 (class 0 OID 0)
-- Dependencies: 289
-- Name: COLUMN soil_typological_unit_profile.typological_unit_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_profile.typological_unit_id IS 'Reference to the typological unit';


--
-- TOC entry 5582 (class 0 OID 0)
-- Dependencies: 289
-- Name: COLUMN soil_typological_unit_profile.profile_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_profile.profile_id IS 'Reference to the profile (typicalProfile)';


--
-- TOC entry 5583 (class 0 OID 0)
-- Dependencies: 289
-- Name: COLUMN soil_typological_unit_profile.is_typical; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_profile.is_typical IS 'Whether this is a typical profile for the typological unit';


--
-- TOC entry 5584 (class 0 OID 0)
-- Dependencies: 289
-- Name: COLUMN soil_typological_unit_profile.remarks; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.soil_typological_unit_profile.remarks IS 'Additional remarks or notes';


--
-- TOC entry 290 (class 1259 OID 55715231)
-- Name: soil_typological_unit_typological_unit_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.soil_typological_unit ALTER COLUMN typological_unit_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.soil_typological_unit_typological_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 291 (class 1259 OID 55715233)
-- Name: specimen_specimen_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.specimen ALTER COLUMN specimen_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.specimen_specimen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 292 (class 1259 OID 55715235)
-- Name: spectral_sample; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.spectral_sample (
    spectral_sample_id text NOT NULL,
    specimen_id integer NOT NULL
);


ALTER TABLE soil_data.spectral_sample OWNER TO sis;

--
-- TOC entry 293 (class 1259 OID 55715241)
-- Name: spectrum; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.spectrum (
    spectrum_id integer NOT NULL,
    spectral_sample_id text NOT NULL,
    procedure_spectrometer_id integer NOT NULL,
    spectral_scale text,
    unity text,
    is_spec_reso_homo boolean,
    spectral_resolution real,
    spectrum jsonb,
    CONSTRAINT spectrum_spectral_resolution_check CHECK ((((is_spec_reso_homo IS TRUE) AND (spectral_resolution IS NOT NULL) AND (spectral_resolution > (0)::double precision)) OR ((is_spec_reso_homo IS NOT TRUE) AND (spectral_resolution IS NULL)))),
    CONSTRAINT spectrum_spectral_scale_check CHECK ((spectral_scale = ANY (ARRAY['wavelength'::text, 'wavenumber'::text]))),
    CONSTRAINT spectrum_unity_check CHECK ((((spectral_scale = 'wavelength'::text) AND (unity = ANY (ARRAY['micrometers'::text, 'nanometers'::text]))) OR ((spectral_scale = 'wavenumber'::text) AND (unity = 'cm⁻¹'::text)) OR ((spectral_scale IS NULL) AND (unity IS NULL))))
);


ALTER TABLE soil_data.spectrum OWNER TO sis;

--
-- TOC entry 5588 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.spectrum_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.spectrum_id IS 'Surrogate primary key (identity).';


--
-- TOC entry 5589 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.spectral_sample_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.spectral_sample_id IS 'Foreign key to soil_data.spectral_sample: the sample this spectrum was measured on.';


--
-- TOC entry 5590 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.procedure_spectrometer_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.procedure_spectrometer_id IS 'Foreign key to soil_data.procedure_spectrometer: the spectrometer/measurement procedure that produced this spectrum.';


--
-- TOC entry 5591 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.spectral_scale; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.spectral_scale IS 'Type of spectral axis: ''wavelength'' or ''wavenumber''.';


--
-- TOC entry 5592 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.unity; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.unity IS 'Unit of the spectral axis. For spectral_scale = ''wavelength'': ''micrometers'' or ''nanometers''. For spectral_scale = ''wavenumber'': ''cm⁻¹''.';


--
-- TOC entry 5593 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.is_spec_reso_homo; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.is_spec_reso_homo IS 'TRUE if the spectral resolution is homogeneous across the spectrum. When TRUE, spectral_resolution holds the single resolution value; otherwise spectral_resolution is NULL.';


--
-- TOC entry 5594 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.spectral_resolution; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.spectral_resolution IS 'Spectral resolution (positive, in the unit given by unity), set only when is_spec_reso_homo is TRUE.';


--
-- TOC entry 5595 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN spectrum.spectrum; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.spectrum.spectrum IS 'The measured spectrum as JSON, with the axis defined by spectral_scale and unity.';


--
-- TOC entry 294 (class 1259 OID 55715250)
-- Name: spectrum_spectrum_id_seq; Type: SEQUENCE; Schema: soil_data; Owner: sis
--

ALTER TABLE soil_data.spectrum ALTER COLUMN spectrum_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME soil_data.spectrum_spectrum_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 295 (class 1259 OID 55715252)
-- Name: spectrum_x_result_spectral; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.spectrum_x_result_spectral (
    result_spectral_id integer NOT NULL,
    spectrum_id integer NOT NULL
);


ALTER TABLE soil_data.spectrum_x_result_spectral OWNER TO sis;

--
-- TOC entry 296 (class 1259 OID 55715255)
-- Name: translate; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.translate (
    table_name text NOT NULL,
    column_name text NOT NULL,
    language_code text NOT NULL,
    string text NOT NULL,
    translation text
);


ALTER TABLE soil_data.translate OWNER TO sis;

--
-- TOC entry 5596 (class 0 OID 0)
-- Dependencies: 296
-- Name: TABLE translate; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.translate IS 'Multilingual translations for database content';


--
-- TOC entry 5597 (class 0 OID 0)
-- Dependencies: 296
-- Name: COLUMN translate.table_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.translate.table_name IS 'Name of the source table containing the translatable content';


--
-- TOC entry 5598 (class 0 OID 0)
-- Dependencies: 296
-- Name: COLUMN translate.column_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.translate.column_name IS 'Name of the column containing the translatable content';


--
-- TOC entry 5599 (class 0 OID 0)
-- Dependencies: 296
-- Name: COLUMN translate.language_code; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.translate.language_code IS 'Target language code (ISO 639-1)';


--
-- TOC entry 5600 (class 0 OID 0)
-- Dependencies: 296
-- Name: COLUMN translate.string; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.translate.string IS 'Original string to be translated';


--
-- TOC entry 5601 (class 0 OID 0)
-- Dependencies: 296
-- Name: COLUMN translate.translation; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.translate.translation IS 'Translated string in the target language';


--
-- TOC entry 297 (class 1259 OID 55715261)
-- Name: unit_conversion; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.unit_conversion (
    unit_from text NOT NULL,
    operation text NOT NULL,
    value real NOT NULL,
    unit_to text NOT NULL,
    CONSTRAINT unit_conversion_no_self_reference CHECK ((unit_from <> unit_to)),
    CONSTRAINT unit_conversion_operation_check CHECK ((operation = ANY (ARRAY['*'::text, '/'::text])))
);


ALTER TABLE soil_data.unit_conversion OWNER TO sis;

--
-- TOC entry 298 (class 1259 OID 55715269)
-- Name: unit_of_measure; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.unit_of_measure (
    unit_of_measure_id text NOT NULL,
    unit_name character varying NOT NULL,
    unit_type text,
    uri text NOT NULL
);


ALTER TABLE soil_data.unit_of_measure OWNER TO sis;

--
-- TOC entry 5604 (class 0 OID 0)
-- Dependencies: 298
-- Name: TABLE unit_of_measure; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.unit_of_measure IS 'Unit of measure';


--
-- TOC entry 5605 (class 0 OID 0)
-- Dependencies: 298
-- Name: COLUMN unit_of_measure.unit_of_measure_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.unit_of_measure.unit_of_measure_id IS 'Synthetic primary key.';


--
-- TOC entry 5606 (class 0 OID 0)
-- Dependencies: 298
-- Name: COLUMN unit_of_measure.unit_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.unit_of_measure.unit_name IS 'Short label for this unit of measure';


--
-- TOC entry 299 (class 1259 OID 55715275)
-- Name: url; Type: TABLE; Schema: soil_data; Owner: sis
--

CREATE TABLE soil_data.url (
    mapset_id text NOT NULL,
    protocol text NOT NULL,
    url text NOT NULL,
    url_name text,
    url_description text,
    CONSTRAINT url_protocol_check CHECK ((protocol = ANY (ARRAY['OGC:WFS'::text, 'OGC:WCS'::text, 'OGC:WMS'::text, 'OGC:WMTS'::text, 'OGC:WMS-1.3.0-http-get-capabilities'::text, 'OGC:WMS-1.1.1-http-get-map'::text, 'OGC:WMS-1.3.0-http-get-map'::text, 'WWW:LINK-1.0-http--link'::text, 'WWW:LINK-1.0-http--related'::text, 'WWW:DOWNLOAD-1.0-http--download'::text])))
);


ALTER TABLE soil_data.url OWNER TO sis;

--
-- TOC entry 5608 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE url; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON TABLE soil_data.url IS 'Online resource URLs for mapsets (download, WMS, WFS, etc.)';


--
-- TOC entry 5609 (class 0 OID 0)
-- Dependencies: 299
-- Name: COLUMN url.mapset_id; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.url.mapset_id IS 'Reference to the mapset';


--
-- TOC entry 5610 (class 0 OID 0)
-- Dependencies: 299
-- Name: COLUMN url.protocol; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.url.protocol IS 'OGC or WWW protocol identifier';


--
-- TOC entry 5611 (class 0 OID 0)
-- Dependencies: 299
-- Name: COLUMN url.url; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.url.url IS 'Full URL to the resource';


--
-- TOC entry 5612 (class 0 OID 0)
-- Dependencies: 299
-- Name: COLUMN url.url_name; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.url.url_name IS 'Display name for the URL';


--
-- TOC entry 5613 (class 0 OID 0)
-- Dependencies: 299
-- Name: COLUMN url.url_description; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON COLUMN soil_data.url.url_description IS 'Description of what the URL provides';


--
-- TOC entry 4789 (class 2604 OID 55715282)
-- Name: uploaded_dataset_edit edit_id; Type: DEFAULT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_edit ALTER COLUMN edit_id SET DEFAULT nextval('api.uploaded_dataset_edit_edit_id_seq'::regclass);


--
-- TOC entry 4856 (class 2606 OID 55715284)
-- Name: api_client api_client_api_key_key; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.api_client
    ADD CONSTRAINT api_client_api_key_key UNIQUE (api_key);


--
-- TOC entry 4858 (class 2606 OID 55715286)
-- Name: api_client api_client_id_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.api_client
    ADD CONSTRAINT api_client_id_pkey PRIMARY KEY (api_client_id);


--
-- TOC entry 4860 (class 2606 OID 55715288)
-- Name: audit audit_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.audit
    ADD CONSTRAINT audit_pkey PRIMARY KEY (audit_id);


--
-- TOC entry 4862 (class 2606 OID 55715290)
-- Name: dst_recipe dst_recipe_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.dst_recipe
    ADD CONSTRAINT dst_recipe_pkey PRIMARY KEY (recipe_id);


--
-- TOC entry 4864 (class 2606 OID 55715292)
-- Name: setting setting_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.setting
    ADD CONSTRAINT setting_pkey PRIMARY KEY (key);


--
-- TOC entry 4868 (class 2606 OID 55715294)
-- Name: uploaded_dataset_column uploaded_dataset_column_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_column
    ADD CONSTRAINT uploaded_dataset_column_pkey PRIMARY KEY (table_name, column_name);


--
-- TOC entry 4871 (class 2606 OID 55715296)
-- Name: uploaded_dataset_edit uploaded_dataset_edit_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_edit
    ADD CONSTRAINT uploaded_dataset_edit_pkey PRIMARY KEY (edit_id);


--
-- TOC entry 4866 (class 2606 OID 55715298)
-- Name: uploaded_dataset uploaded_dataset_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset
    ADD CONSTRAINT uploaded_dataset_pkey PRIMARY KEY (table_name);


--
-- TOC entry 4873 (class 2606 OID 55715300)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4913 (class 2606 OID 55715302)
-- Name: category_desc category_desc_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.category_desc
    ADD CONSTRAINT category_desc_pkey PRIMARY KEY (category_desc_id);


--
-- TOC entry 4915 (class 2606 OID 55715304)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (mapset_id, value);


--
-- TOC entry 4919 (class 2606 OID 55715306)
-- Name: country country_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);


--
-- TOC entry 4875 (class 2606 OID 55715308)
-- Name: element element_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.element
    ADD CONSTRAINT element_pkey PRIMARY KEY (element_id);


--
-- TOC entry 4921 (class 2606 OID 55715310)
-- Name: individual individual_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.individual
    ADD CONSTRAINT individual_pkey PRIMARY KEY (individual_id);


--
-- TOC entry 4923 (class 2606 OID 55715312)
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (language_code);


--
-- TOC entry 4879 (class 2606 OID 55715314)
-- Name: layer layer_file_orig_name_unique; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.layer
    ADD CONSTRAINT layer_file_orig_name_unique UNIQUE (file_orig_name);


--
-- TOC entry 4881 (class 2606 OID 55715316)
-- Name: layer layer_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.layer
    ADD CONSTRAINT layer_pkey PRIMARY KEY (layer_id);


--
-- TOC entry 4883 (class 2606 OID 55715318)
-- Name: mapset mapset_mapset_id_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.mapset
    ADD CONSTRAINT mapset_mapset_id_pkey PRIMARY KEY (mapset_id);


--
-- TOC entry 4927 (class 2606 OID 55715320)
-- Name: observation_desc observation_desc_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_desc
    ADD CONSTRAINT observation_desc_pkey PRIMARY KEY (property_desc_id, category_desc_id);


--
-- TOC entry 4885 (class 2606 OID 55715322)
-- Name: observation_num observation_num_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_num
    ADD CONSTRAINT observation_num_pkey PRIMARY KEY (observation_num_id);


--
-- TOC entry 4887 (class 2606 OID 55715324)
-- Name: observation_num observation_num_property_num_id_procedure_num_key; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_num
    ADD CONSTRAINT observation_num_property_num_id_procedure_num_key UNIQUE (property_num_id, procedure_num_id);


--
-- TOC entry 4929 (class 2606 OID 55715326)
-- Name: organisation organisation_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.organisation
    ADD CONSTRAINT organisation_pkey PRIMARY KEY (organisation_id);


--
-- TOC entry 4889 (class 2606 OID 55715328)
-- Name: plot plot_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.plot
    ADD CONSTRAINT plot_pkey PRIMARY KEY (plot_id);


--
-- TOC entry 4931 (class 2606 OID 55715330)
-- Name: procedure_desc procedure_desc_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_desc
    ADD CONSTRAINT procedure_desc_pkey PRIMARY KEY (procedure_desc_id);


--
-- TOC entry 4933 (class 2606 OID 55715332)
-- Name: procedure_desc procedure_desc_uri_key; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_desc
    ADD CONSTRAINT procedure_desc_uri_key UNIQUE (uri);


--
-- TOC entry 4937 (class 2606 OID 55715334)
-- Name: procedure_model_def procedure_model_def_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_model_def
    ADD CONSTRAINT procedure_model_def_pkey PRIMARY KEY (procedure_model_id, key);


--
-- TOC entry 4935 (class 2606 OID 55715336)
-- Name: procedure_model procedure_model_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_model
    ADD CONSTRAINT procedure_model_pkey PRIMARY KEY (procedure_model_id);


--
-- TOC entry 4939 (class 2606 OID 55715338)
-- Name: procedure_num procedure_num_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_num
    ADD CONSTRAINT procedure_num_pkey PRIMARY KEY (procedure_num_id);


--
-- TOC entry 4943 (class 2606 OID 55715340)
-- Name: procedure_spectrometer_def procedure_spectrometer_def_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_spectrometer_def
    ADD CONSTRAINT procedure_spectrometer_def_pkey PRIMARY KEY (procedure_spectrometer_id, key);


--
-- TOC entry 4941 (class 2606 OID 55715342)
-- Name: procedure_spectrometer procedure_spectrometer_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_spectrometer
    ADD CONSTRAINT procedure_spectrometer_pkey PRIMARY KEY (procedure_spectrometer_id);


--
-- TOC entry 4893 (class 2606 OID 55715344)
-- Name: profile profile_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.profile
    ADD CONSTRAINT profile_pkey PRIMARY KEY (profile_id);


--
-- TOC entry 4945 (class 2606 OID 55715346)
-- Name: proj_x_org_x_ind proj_x_org_x_ind_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.proj_x_org_x_ind
    ADD CONSTRAINT proj_x_org_x_ind_pkey PRIMARY KEY (country_id, project_id, organisation_id, individual_id, "position", tag, role);


--
-- TOC entry 4899 (class 2606 OID 55715348)
-- Name: project project_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (country_id, project_id);


--
-- TOC entry 4903 (class 2606 OID 55715350)
-- Name: project_site project_site_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_site
    ADD CONSTRAINT project_site_pkey PRIMARY KEY (project_id, site_id);


--
-- TOC entry 4947 (class 2606 OID 55715352)
-- Name: project_soil_map project_soil_map_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_soil_map
    ADD CONSTRAINT project_soil_map_pkey PRIMARY KEY (project_id, soil_map_id);


--
-- TOC entry 4949 (class 2606 OID 55715354)
-- Name: property_desc property_desc_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.property_desc
    ADD CONSTRAINT property_desc_pkey PRIMARY KEY (property_desc_id);


--
-- TOC entry 4951 (class 2606 OID 55715356)
-- Name: property_num property_num_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.property_num
    ADD CONSTRAINT property_num_pkey PRIMARY KEY (property_num_id);


--
-- TOC entry 4925 (class 2606 OID 55715358)
-- Name: mapped_property property_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.mapped_property
    ADD CONSTRAINT property_pkey PRIMARY KEY (mapped_property_id);


--
-- TOC entry 4953 (class 2606 OID 55715360)
-- Name: result_desc_element result_desc_element_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_element
    ADD CONSTRAINT result_desc_element_pkey PRIMARY KEY (element_id, property_desc_id);


--
-- TOC entry 4955 (class 2606 OID 55715362)
-- Name: result_desc_plot result_desc_plot_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_plot
    ADD CONSTRAINT result_desc_plot_pkey PRIMARY KEY (plot_id, property_desc_id);


--
-- TOC entry 4957 (class 2606 OID 55715364)
-- Name: result_desc_profile result_desc_profile_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_profile
    ADD CONSTRAINT result_desc_profile_pkey PRIMARY KEY (profile_id, property_desc_id);


--
-- TOC entry 4959 (class 2606 OID 55715366)
-- Name: result_desc_surface result_desc_surface_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_surface
    ADD CONSTRAINT result_desc_surface_pkey PRIMARY KEY (surface_id, property_desc_id);


--
-- TOC entry 4905 (class 2606 OID 55715368)
-- Name: result_num result_num_specimen_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_num
    ADD CONSTRAINT result_num_specimen_pkey PRIMARY KEY (observation_num_id, specimen_id);


--
-- TOC entry 4961 (class 2606 OID 55715370)
-- Name: result_spectral result_spectral_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_spectral
    ADD CONSTRAINT result_spectral_pkey PRIMARY KEY (result_spectral_id);


--
-- TOC entry 4907 (class 2606 OID 55715372)
-- Name: site site_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (site_id);


--
-- TOC entry 4964 (class 2606 OID 55715374)
-- Name: soil_map soil_map_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_map
    ADD CONSTRAINT soil_map_pkey PRIMARY KEY (soil_map_id);


--
-- TOC entry 4972 (class 2606 OID 55715376)
-- Name: soil_mapping_unit_category soil_mapping_unit_category_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_category
    ADD CONSTRAINT soil_mapping_unit_category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4968 (class 2606 OID 55715378)
-- Name: soil_mapping_unit soil_mapping_unit_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit
    ADD CONSTRAINT soil_mapping_unit_pkey PRIMARY KEY (mapping_unit_id);


--
-- TOC entry 4974 (class 2606 OID 55715380)
-- Name: soil_mapping_unit_profile soil_mapping_unit_profile_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_profile
    ADD CONSTRAINT soil_mapping_unit_profile_pkey PRIMARY KEY (mapping_unit_id, profile_id);


--
-- TOC entry 4978 (class 2606 OID 55715382)
-- Name: soil_typological_unit_mapping_unit soil_typological_unit_mapping_unit_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_mapping_unit
    ADD CONSTRAINT soil_typological_unit_mapping_unit_pkey PRIMARY KEY (typological_unit_id, mapping_unit_id);


--
-- TOC entry 4976 (class 2606 OID 55715384)
-- Name: soil_typological_unit soil_typological_unit_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit
    ADD CONSTRAINT soil_typological_unit_pkey PRIMARY KEY (typological_unit_id);


--
-- TOC entry 4980 (class 2606 OID 55715386)
-- Name: soil_typological_unit_profile soil_typological_unit_profile_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_profile
    ADD CONSTRAINT soil_typological_unit_profile_pkey PRIMARY KEY (typological_unit_id, profile_id);


--
-- TOC entry 4909 (class 2606 OID 55715388)
-- Name: specimen specimen_code_key; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.specimen
    ADD CONSTRAINT specimen_code_key UNIQUE (code);


--
-- TOC entry 4911 (class 2606 OID 55715390)
-- Name: specimen specimen_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.specimen
    ADD CONSTRAINT specimen_pkey PRIMARY KEY (specimen_id);


--
-- TOC entry 4982 (class 2606 OID 55715392)
-- Name: spectral_sample spectral_sample_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectral_sample
    ADD CONSTRAINT spectral_sample_pkey PRIMARY KEY (spectral_sample_id);


--
-- TOC entry 4984 (class 2606 OID 55715394)
-- Name: spectrum spectrum_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum
    ADD CONSTRAINT spectrum_pkey PRIMARY KEY (spectrum_id);


--
-- TOC entry 4986 (class 2606 OID 55715396)
-- Name: spectrum_x_result_spectral spectrum_x_result_spectral_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum_x_result_spectral
    ADD CONSTRAINT spectrum_x_result_spectral_pkey PRIMARY KEY (result_spectral_id, spectrum_id);


--
-- TOC entry 4988 (class 2606 OID 55715398)
-- Name: translate translate_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.translate
    ADD CONSTRAINT translate_pkey PRIMARY KEY (table_name, column_name, language_code, string);


--
-- TOC entry 4891 (class 2606 OID 55715400)
-- Name: idx_plot_site_id_plot_code; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_plot_site_id_plot_code ON soil_data.plot USING btree (site_id, plot_code);


--
-- TOC entry 4895 (class 2606 OID 55715402)
-- Name: idx_profile_plot_id; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_profile_plot_id ON soil_data.profile USING btree (plot_id);


--
-- TOC entry 4990 (class 2606 OID 55715404)
-- Name: unit_conversion unit_conversion_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.unit_conversion
    ADD CONSTRAINT unit_conversion_pkey PRIMARY KEY (unit_from, unit_to);


--
-- TOC entry 4992 (class 2606 OID 55715406)
-- Name: unit_of_measure unit_of_measure_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.unit_of_measure
    ADD CONSTRAINT unit_of_measure_pkey PRIMARY KEY (unit_of_measure_id);


--
-- TOC entry 4877 (class 2606 OID 55715408)
-- Name: element unq_element_profile_order_element; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.element
    ADD CONSTRAINT unq_element_profile_order_element UNIQUE (profile_id, order_element);


--
-- TOC entry 4901 (class 2606 OID 55715412)
-- Name: project unq_project_name; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project
    ADD CONSTRAINT unq_project_name UNIQUE (name);


--
-- TOC entry 4994 (class 2606 OID 55715414)
-- Name: unit_of_measure unq_unit_of_measure_uri; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.unit_of_measure
    ADD CONSTRAINT unq_unit_of_measure_uri UNIQUE (uri);


--
-- TOC entry 4996 (class 2606 OID 55715416)
-- Name: url url_pkey; Type: CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.url
    ADD CONSTRAINT url_pkey PRIMARY KEY (mapset_id, protocol, url);


--
-- TOC entry 4869 (class 1259 OID 55715417)
-- Name: idx_uploaded_dataset_edit_table; Type: INDEX; Schema: api; Owner: sis
--

CREATE INDEX idx_uploaded_dataset_edit_table ON api.uploaded_dataset_edit USING btree (table_name);


--
-- TOC entry 4916 (class 1259 OID 55715418)
-- Name: country_geom_centroid_idx; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX country_geom_centroid_idx ON soil_data.country USING gist (geom_centroid);


--
-- TOC entry 4917 (class 1259 OID 55715419)
-- Name: country_geom_convexhull_idx; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX country_geom_convexhull_idx ON soil_data.country USING gist (geom_convexhull);


--
-- TOC entry 4969 (class 1259 OID 55715420)
-- Name: idx_category_map; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_category_map ON soil_data.soil_mapping_unit_category USING btree (soil_map_id);


--
-- TOC entry 5615 (class 0 OID 0)
-- Dependencies: 4969
-- Name: INDEX idx_category_map; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON INDEX soil_data.idx_category_map IS 'Index on soil map for root categories';


--
-- TOC entry 4970 (class 1259 OID 55715421)
-- Name: idx_category_parent; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_category_parent ON soil_data.soil_mapping_unit_category USING btree (parent_category_id);


--
-- TOC entry 5616 (class 0 OID 0)
-- Dependencies: 4970
-- Name: INDEX idx_category_parent; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON INDEX soil_data.idx_category_parent IS 'Index on parent category for hierarchy traversal';


--
-- TOC entry 4965 (class 1259 OID 55715422)
-- Name: idx_mapping_unit_category; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_mapping_unit_category ON soil_data.soil_mapping_unit USING btree (category_id);


--
-- TOC entry 5617 (class 0 OID 0)
-- Dependencies: 4965
-- Name: INDEX idx_mapping_unit_category; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON INDEX soil_data.idx_mapping_unit_category IS 'Index on category for joining with category table';


--
-- TOC entry 4966 (class 1259 OID 55715423)
-- Name: idx_mapping_unit_geom; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_mapping_unit_geom ON soil_data.soil_mapping_unit USING gist (geom);


--
-- TOC entry 5618 (class 0 OID 0)
-- Dependencies: 4966
-- Name: INDEX idx_mapping_unit_geom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON INDEX soil_data.idx_mapping_unit_geom IS 'Spatial index on mapping unit geometry';


--
-- TOC entry 4962 (class 1259 OID 55715424)
-- Name: idx_soil_map_geom; Type: INDEX; Schema: soil_data; Owner: sis
--

CREATE INDEX idx_soil_map_geom ON soil_data.soil_map USING gist (geom);


--
-- TOC entry 5619 (class 0 OID 0)
-- Dependencies: 4962
-- Name: INDEX idx_soil_map_geom; Type: COMMENT; Schema: soil_data; Owner: sis
--

COMMENT ON INDEX soil_data.idx_soil_map_geom IS 'Spatial index on soil map extent geometry';


--
-- TOC entry 5065 (class 2620 OID 55715425)
-- Name: audit audit_no_delete; Type: TRIGGER; Schema: api; Owner: sis
--

CREATE TRIGGER audit_no_delete BEFORE DELETE ON api.audit FOR EACH ROW EXECUTE FUNCTION api.audit_no_modify();


--
-- TOC entry 5066 (class 2620 OID 55715426)
-- Name: audit audit_no_update; Type: TRIGGER; Schema: api; Owner: sis
--

CREATE TRIGGER audit_no_update BEFORE UPDATE ON api.audit FOR EACH ROW EXECUTE FUNCTION api.audit_no_modify();


--
-- TOC entry 5067 (class 2620 OID 55715427)
-- Name: layer class_func_on_layer_table; Type: TRIGGER; Schema: soil_data; Owner: sis
--

CREATE TRIGGER class_func_on_layer_table AFTER UPDATE OF stats_minimum, stats_maximum ON soil_data.layer FOR EACH ROW EXECUTE FUNCTION soil_data.class();


--
-- TOC entry 5068 (class 2620 OID 55715428)
-- Name: layer map_func_on_layer_table; Type: TRIGGER; Schema: soil_data; Owner: sis
--

CREATE TRIGGER map_func_on_layer_table AFTER UPDATE OF layer_id, mapset_id, distance_uom, reference_system_identifier_code, extent, file_extension, stats_minimum, stats_maximum ON soil_data.layer FOR EACH ROW EXECUTE FUNCTION soil_data.map();


--
-- TOC entry 5069 (class 2620 OID 55715429)
-- Name: mapset mapset_publication_not_future_trg; Type: TRIGGER; Schema: soil_data; Owner: sis
--

CREATE TRIGGER mapset_publication_not_future_trg BEFORE INSERT OR UPDATE OF publication_date ON soil_data.mapset FOR EACH ROW EXECUTE FUNCTION soil_data.mapset_publication_not_future();


--
-- TOC entry 5071 (class 2620 OID 55715430)
-- Name: class sld_func_on_class_table; Type: TRIGGER; Schema: soil_data; Owner: sis
--

CREATE TRIGGER sld_func_on_class_table AFTER INSERT OR UPDATE ON soil_data.class FOR EACH ROW EXECUTE FUNCTION soil_data.sld();


--
-- TOC entry 5070 (class 2620 OID 55715431)
-- Name: result_num trg_check_result_value; Type: TRIGGER; Schema: soil_data; Owner: sis
--

CREATE TRIGGER trg_check_result_value BEFORE INSERT OR UPDATE ON soil_data.result_num FOR EACH ROW EXECUTE FUNCTION soil_data.check_result_value();


--
-- TOC entry 4997 (class 2606 OID 55715432)
-- Name: audit audit_api_client_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.audit
    ADD CONSTRAINT audit_api_client_id_fkey FOREIGN KEY (api_client_id) REFERENCES api.api_client(api_client_id) ON UPDATE CASCADE;


--
-- TOC entry 4998 (class 2606 OID 55715437)
-- Name: audit audit_user_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.audit
    ADD CONSTRAINT audit_user_id_fkey FOREIGN KEY (user_id) REFERENCES api."user"(user_id) ON UPDATE CASCADE;


--
-- TOC entry 4999 (class 2606 OID 55715442)
-- Name: dst_recipe dst_recipe_created_by_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.dst_recipe
    ADD CONSTRAINT dst_recipe_created_by_fkey FOREIGN KEY (created_by) REFERENCES api."user"(user_id) ON UPDATE CASCADE;


--
-- TOC entry 5000 (class 2606 OID 55715447)
-- Name: dst_recipe dst_recipe_run_triggered_by_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.dst_recipe
    ADD CONSTRAINT dst_recipe_run_triggered_by_fkey FOREIGN KEY (run_triggered_by) REFERENCES api."user"(user_id) ON UPDATE CASCADE;


--
-- TOC entry 5003 (class 2606 OID 55715452)
-- Name: uploaded_dataset_column uploaded_dataset_column_procedure_num_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_column
    ADD CONSTRAINT uploaded_dataset_column_procedure_num_id_fkey FOREIGN KEY (procedure_num_id) REFERENCES soil_data.procedure_num(procedure_num_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5004 (class 2606 OID 55715457)
-- Name: uploaded_dataset_column uploaded_dataset_column_property_num_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_column
    ADD CONSTRAINT uploaded_dataset_column_property_num_id_fkey FOREIGN KEY (property_num_id) REFERENCES soil_data.property_num(property_num_id) ON UPDATE CASCADE;


--
-- TOC entry 5005 (class 2606 OID 55715462)
-- Name: uploaded_dataset_column uploaded_dataset_column_table_name_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_column
    ADD CONSTRAINT uploaded_dataset_column_table_name_fkey FOREIGN KEY (table_name) REFERENCES api.uploaded_dataset(table_name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5006 (class 2606 OID 55715467)
-- Name: uploaded_dataset_column uploaded_dataset_column_unit_of_measure_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_column
    ADD CONSTRAINT uploaded_dataset_column_unit_of_measure_id_fkey FOREIGN KEY (unit_of_measure_id) REFERENCES soil_data.unit_of_measure(unit_of_measure_id) ON UPDATE CASCADE;


--
-- TOC entry 5007 (class 2606 OID 55715472)
-- Name: uploaded_dataset_edit uploaded_dataset_edit_table_name_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset_edit
    ADD CONSTRAINT uploaded_dataset_edit_table_name_fkey FOREIGN KEY (table_name) REFERENCES api.uploaded_dataset(table_name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5001 (class 2606 OID 55715477)
-- Name: uploaded_dataset uploaded_dataset_project_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset
    ADD CONSTRAINT uploaded_dataset_project_id_fkey FOREIGN KEY (country_id, project_id) REFERENCES soil_data.project(country_id, project_id) ON UPDATE CASCADE;


--
-- TOC entry 5002 (class 2606 OID 55715482)
-- Name: uploaded_dataset uploaded_dataset_user_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: sis
--

ALTER TABLE ONLY api.uploaded_dataset
    ADD CONSTRAINT uploaded_dataset_user_id_fkey FOREIGN KEY (user_id) REFERENCES api."user"(user_id) ON UPDATE CASCADE;


--
-- TOC entry 5024 (class 2606 OID 55715487)
-- Name: class class_mapset_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.class
    ADD CONSTRAINT class_mapset_id_fkey FOREIGN KEY (mapset_id) REFERENCES soil_data.mapset(mapset_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5008 (class 2606 OID 55715492)
-- Name: element element_profile_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.element
    ADD CONSTRAINT element_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES soil_data.profile(profile_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5037 (class 2606 OID 55715497)
-- Name: result_desc_element fk_element; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_element
    ADD CONSTRAINT fk_element FOREIGN KEY (element_id) REFERENCES soil_data.element(element_id);


--
-- TOC entry 5039 (class 2606 OID 55715502)
-- Name: result_desc_plot fk_plot; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_plot
    ADD CONSTRAINT fk_plot FOREIGN KEY (plot_id) REFERENCES soil_data.plot(plot_id);


--
-- TOC entry 5041 (class 2606 OID 55715507)
-- Name: result_desc_profile fk_profile; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_profile
    ADD CONSTRAINT fk_profile FOREIGN KEY (profile_id) REFERENCES soil_data.profile(profile_id);


--
-- TOC entry 5019 (class 2606 OID 55715512)
-- Name: project_site fk_project; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_site
    ADD CONSTRAINT fk_project FOREIGN KEY (country_id, project_id) REFERENCES soil_data.project(country_id, project_id);


--
-- TOC entry 5020 (class 2606 OID 55715517)
-- Name: project_site fk_site; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_site
    ADD CONSTRAINT fk_site FOREIGN KEY (site_id) REFERENCES soil_data.site(site_id);


--
-- TOC entry 5043 (class 2606 OID 55715522)
-- Name: result_desc_surface fk_surface; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_surface
    ADD CONSTRAINT fk_surface FOREIGN KEY (surface_id) REFERENCES soil_data.plot(plot_id);


--
-- TOC entry 5009 (class 2606 OID 55715527)
-- Name: layer layer_mapset_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.layer
    ADD CONSTRAINT layer_mapset_id_fkey FOREIGN KEY (mapset_id) REFERENCES soil_data.mapset(mapset_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5025 (class 2606 OID 55715532)
-- Name: mapped_property mapped_property_property_num_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.mapped_property
    ADD CONSTRAINT mapped_property_property_num_id_fkey FOREIGN KEY (property_num_id) REFERENCES soil_data.property_num(property_num_id) ON UPDATE CASCADE;


--
-- TOC entry 5010 (class 2606 OID 55715537)
-- Name: mapset mapset_country_id_project_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.mapset
    ADD CONSTRAINT mapset_country_id_project_id_fkey FOREIGN KEY (country_id, project_id) REFERENCES soil_data.project(country_id, project_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5011 (class 2606 OID 55715542)
-- Name: mapset mapset_mapped_property_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.mapset
    ADD CONSTRAINT mapset_mapped_property_id_fkey FOREIGN KEY (mapped_property_id) REFERENCES soil_data.mapped_property(mapped_property_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5012 (class 2606 OID 55715547)
-- Name: observation_num observation_bum_unit_of_measure_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_num
    ADD CONSTRAINT observation_bum_unit_of_measure_id_fkey FOREIGN KEY (unit_of_measure_id) REFERENCES soil_data.unit_of_measure(unit_of_measure_id) ON UPDATE CASCADE;


--
-- TOC entry 5026 (class 2606 OID 55715552)
-- Name: observation_desc observation_desc_category_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_desc
    ADD CONSTRAINT observation_desc_category_desc_id_fkey FOREIGN KEY (category_desc_id) REFERENCES soil_data.category_desc(category_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5027 (class 2606 OID 55715557)
-- Name: observation_desc observation_desc_procedure_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_desc
    ADD CONSTRAINT observation_desc_procedure_desc_id_fkey FOREIGN KEY (procedure_desc_id) REFERENCES soil_data.procedure_desc(procedure_desc_id) ON UPDATE CASCADE;


--
-- TOC entry 5028 (class 2606 OID 55715562)
-- Name: observation_desc observation_desc_property_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_desc
    ADD CONSTRAINT observation_desc_property_desc_id_fkey FOREIGN KEY (property_desc_id) REFERENCES soil_data.property_desc(property_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5013 (class 2606 OID 55715567)
-- Name: observation_num observation_num_procedure_num_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_num
    ADD CONSTRAINT observation_num_procedure_num_id_fkey FOREIGN KEY (procedure_num_id) REFERENCES soil_data.procedure_num(procedure_num_id) ON UPDATE CASCADE;


--
-- TOC entry 5014 (class 2606 OID 55715572)
-- Name: observation_num observation_num_property_num_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.observation_num
    ADD CONSTRAINT observation_num_property_num_id_fkey FOREIGN KEY (property_num_id) REFERENCES soil_data.property_num(property_num_id) ON UPDATE CASCADE;


--
-- TOC entry 5015 (class 2606 OID 55715577)
-- Name: plot plot_parent_plot_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.plot
    ADD CONSTRAINT plot_parent_plot_id_fkey FOREIGN KEY (parent_plot_id) REFERENCES soil_data.plot(plot_id);


--
-- TOC entry 5016 (class 2606 OID 55715582)
-- Name: plot plot_site_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.plot
    ADD CONSTRAINT plot_site_id_fkey FOREIGN KEY (site_id) REFERENCES soil_data.site(site_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5029 (class 2606 OID 55715587)
-- Name: procedure_model_def procedure_model_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_model_def
    ADD CONSTRAINT procedure_model_id_fkey FOREIGN KEY (procedure_model_id) REFERENCES soil_data.procedure_model(procedure_model_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5030 (class 2606 OID 55715592)
-- Name: procedure_num procedure_num_broader_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_num
    ADD CONSTRAINT procedure_num_broader_id_fkey FOREIGN KEY (broader_id) REFERENCES soil_data.procedure_num(procedure_num_id) ON UPDATE CASCADE;


--
-- TOC entry 5031 (class 2606 OID 55715597)
-- Name: procedure_spectrometer_def procedure_spectrometer_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.procedure_spectrometer_def
    ADD CONSTRAINT procedure_spectrometer_id_fkey FOREIGN KEY (procedure_spectrometer_id) REFERENCES soil_data.procedure_spectrometer(procedure_spectrometer_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5017 (class 2606 OID 55715602)
-- Name: profile profile_plot_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.profile
    ADD CONSTRAINT profile_plot_id_fkey FOREIGN KEY (plot_id) REFERENCES soil_data.plot(plot_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5032 (class 2606 OID 55715607)
-- Name: proj_x_org_x_ind proj_x_org_x_ind_country_id_project_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.proj_x_org_x_ind
    ADD CONSTRAINT proj_x_org_x_ind_country_id_project_id_fkey FOREIGN KEY (country_id, project_id) REFERENCES soil_data.project(country_id, project_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5033 (class 2606 OID 55715612)
-- Name: proj_x_org_x_ind proj_x_org_x_ind_individual_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.proj_x_org_x_ind
    ADD CONSTRAINT proj_x_org_x_ind_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES soil_data.individual(individual_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5034 (class 2606 OID 55715617)
-- Name: proj_x_org_x_ind proj_x_org_x_ind_organisation_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.proj_x_org_x_ind
    ADD CONSTRAINT proj_x_org_x_ind_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES soil_data.organisation(organisation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5018 (class 2606 OID 55715622)
-- Name: project project_country_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project
    ADD CONSTRAINT project_country_id_fkey FOREIGN KEY (country_id) REFERENCES soil_data.country(country_id) ON UPDATE CASCADE;


--
-- TOC entry 5035 (class 2606 OID 55715627)
-- Name: project_soil_map project_soil_map_project_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_soil_map
    ADD CONSTRAINT project_soil_map_project_id_fkey FOREIGN KEY (country_id, project_id) REFERENCES soil_data.project(country_id, project_id) ON DELETE CASCADE;


--
-- TOC entry 5036 (class 2606 OID 55715632)
-- Name: project_soil_map project_soil_map_soil_map_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.project_soil_map
    ADD CONSTRAINT project_soil_map_soil_map_id_fkey FOREIGN KEY (soil_map_id) REFERENCES soil_data.soil_map(soil_map_id) ON DELETE CASCADE;


--
-- TOC entry 5038 (class 2606 OID 55715637)
-- Name: result_desc_element result_desc_element_property_desc_id_category_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_element
    ADD CONSTRAINT result_desc_element_property_desc_id_category_desc_id_fkey FOREIGN KEY (property_desc_id, category_desc_id) REFERENCES soil_data.observation_desc(property_desc_id, category_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5040 (class 2606 OID 55715642)
-- Name: result_desc_plot result_desc_plot_property_desc_id_category_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_plot
    ADD CONSTRAINT result_desc_plot_property_desc_id_category_desc_id_fkey FOREIGN KEY (property_desc_id, category_desc_id) REFERENCES soil_data.observation_desc(property_desc_id, category_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5042 (class 2606 OID 55715647)
-- Name: result_desc_profile result_desc_profile_property_desc_id_category_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_profile
    ADD CONSTRAINT result_desc_profile_property_desc_id_category_desc_id_fkey FOREIGN KEY (property_desc_id, category_desc_id) REFERENCES soil_data.observation_desc(property_desc_id, category_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5044 (class 2606 OID 55715652)
-- Name: result_desc_surface result_desc_surface_property_desc_id_category_desc_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_desc_surface
    ADD CONSTRAINT result_desc_surface_property_desc_id_category_desc_id_fkey FOREIGN KEY (property_desc_id, category_desc_id) REFERENCES soil_data.observation_desc(property_desc_id, category_desc_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5021 (class 2606 OID 55715657)
-- Name: result_num result_num_observation_num_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_num
    ADD CONSTRAINT result_num_observation_num_id_fkey FOREIGN KEY (observation_num_id) REFERENCES soil_data.observation_num(observation_num_id);


--
-- TOC entry 5022 (class 2606 OID 55715662)
-- Name: result_num result_num_specimen_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_num
    ADD CONSTRAINT result_num_specimen_id_fkey FOREIGN KEY (specimen_id) REFERENCES soil_data.specimen(specimen_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5045 (class 2606 OID 55715667)
-- Name: result_spectral result_spectral_observation_num_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_spectral
    ADD CONSTRAINT result_spectral_observation_num_id_fkey FOREIGN KEY (observation_num_id) REFERENCES soil_data.observation_num(observation_num_id);


--
-- TOC entry 5046 (class 2606 OID 55715672)
-- Name: result_spectral result_spectral_procedure_model_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.result_spectral
    ADD CONSTRAINT result_spectral_procedure_model_id_fkey FOREIGN KEY (procedure_model_id) REFERENCES soil_data.procedure_model(procedure_model_id) ON UPDATE CASCADE;


--
-- TOC entry 5047 (class 2606 OID 55715677)
-- Name: soil_mapping_unit soil_mapping_unit_category_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit
    ADD CONSTRAINT soil_mapping_unit_category_id_fkey FOREIGN KEY (category_id) REFERENCES soil_data.soil_mapping_unit_category(category_id) ON DELETE CASCADE;


--
-- TOC entry 5048 (class 2606 OID 55715682)
-- Name: soil_mapping_unit_category soil_mapping_unit_category_parent_category_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_category
    ADD CONSTRAINT soil_mapping_unit_category_parent_category_id_fkey FOREIGN KEY (parent_category_id) REFERENCES soil_data.soil_mapping_unit_category(category_id) ON DELETE CASCADE;


--
-- TOC entry 5049 (class 2606 OID 55715687)
-- Name: soil_mapping_unit_category soil_mapping_unit_category_soil_map_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_category
    ADD CONSTRAINT soil_mapping_unit_category_soil_map_id_fkey FOREIGN KEY (soil_map_id) REFERENCES soil_data.soil_map(soil_map_id) ON DELETE CASCADE;


--
-- TOC entry 5050 (class 2606 OID 55715692)
-- Name: soil_mapping_unit_profile soil_mapping_unit_profile_mapping_unit_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_profile
    ADD CONSTRAINT soil_mapping_unit_profile_mapping_unit_id_fkey FOREIGN KEY (mapping_unit_id) REFERENCES soil_data.soil_mapping_unit(mapping_unit_id) ON DELETE CASCADE;


--
-- TOC entry 5051 (class 2606 OID 55715697)
-- Name: soil_mapping_unit_profile soil_mapping_unit_profile_profile_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_mapping_unit_profile
    ADD CONSTRAINT soil_mapping_unit_profile_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES soil_data.profile(profile_id) ON DELETE CASCADE;


--
-- TOC entry 5052 (class 2606 OID 55715702)
-- Name: soil_typological_unit_mapping_unit soil_typological_unit_mapping_unit_mapping_unit_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_mapping_unit
    ADD CONSTRAINT soil_typological_unit_mapping_unit_mapping_unit_id_fkey FOREIGN KEY (mapping_unit_id) REFERENCES soil_data.soil_mapping_unit(mapping_unit_id) ON DELETE CASCADE;


--
-- TOC entry 5053 (class 2606 OID 55715707)
-- Name: soil_typological_unit_mapping_unit soil_typological_unit_mapping_unit_typological_unit_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_mapping_unit
    ADD CONSTRAINT soil_typological_unit_mapping_unit_typological_unit_id_fkey FOREIGN KEY (typological_unit_id) REFERENCES soil_data.soil_typological_unit(typological_unit_id) ON DELETE CASCADE;


--
-- TOC entry 5054 (class 2606 OID 55715712)
-- Name: soil_typological_unit_profile soil_typological_unit_profile_profile_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_profile
    ADD CONSTRAINT soil_typological_unit_profile_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES soil_data.profile(profile_id) ON DELETE CASCADE;


--
-- TOC entry 5055 (class 2606 OID 55715717)
-- Name: soil_typological_unit_profile soil_typological_unit_profile_typological_unit_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.soil_typological_unit_profile
    ADD CONSTRAINT soil_typological_unit_profile_typological_unit_id_fkey FOREIGN KEY (typological_unit_id) REFERENCES soil_data.soil_typological_unit(typological_unit_id) ON DELETE CASCADE;


--
-- TOC entry 5023 (class 2606 OID 55715722)
-- Name: specimen specimen_element_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.specimen
    ADD CONSTRAINT specimen_element_id_fkey FOREIGN KEY (element_id) REFERENCES soil_data.element(element_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5056 (class 2606 OID 55715727)
-- Name: spectral_sample spectral_sample_specimen_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectral_sample
    ADD CONSTRAINT spectral_sample_specimen_id_fkey FOREIGN KEY (specimen_id) REFERENCES soil_data.specimen(specimen_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5057 (class 2606 OID 55715732)
-- Name: spectrum spectrum_procedure_spectrometer_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum
    ADD CONSTRAINT spectrum_procedure_spectrometer_id_fkey FOREIGN KEY (procedure_spectrometer_id) REFERENCES soil_data.procedure_spectrometer(procedure_spectrometer_id) ON UPDATE CASCADE;


--
-- TOC entry 5058 (class 2606 OID 55715737)
-- Name: spectrum spectrum_spectral_sample_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum
    ADD CONSTRAINT spectrum_spectral_sample_id_fkey FOREIGN KEY (spectral_sample_id) REFERENCES soil_data.spectral_sample(spectral_sample_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5059 (class 2606 OID 55715742)
-- Name: spectrum_x_result_spectral spectrum_x_result_spectral_result_spectral_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum_x_result_spectral
    ADD CONSTRAINT spectrum_x_result_spectral_result_spectral_id_fkey FOREIGN KEY (result_spectral_id) REFERENCES soil_data.result_spectral(result_spectral_id) ON UPDATE CASCADE;


--
-- TOC entry 5060 (class 2606 OID 55715747)
-- Name: spectrum_x_result_spectral spectrum_x_result_spectral_spectrum_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.spectrum_x_result_spectral
    ADD CONSTRAINT spectrum_x_result_spectral_spectrum_id_fkey FOREIGN KEY (spectrum_id) REFERENCES soil_data.spectrum(spectrum_id) ON UPDATE CASCADE;


--
-- TOC entry 5061 (class 2606 OID 55715752)
-- Name: translate translate_language_code_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.translate
    ADD CONSTRAINT translate_language_code_fkey FOREIGN KEY (language_code) REFERENCES soil_data.languages(language_code);


--
-- TOC entry 5062 (class 2606 OID 55715757)
-- Name: unit_conversion unit_conversion_unit_from_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.unit_conversion
    ADD CONSTRAINT unit_conversion_unit_from_fkey FOREIGN KEY (unit_from) REFERENCES soil_data.unit_of_measure(unit_of_measure_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5063 (class 2606 OID 55715762)
-- Name: unit_conversion unit_conversion_unit_to_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.unit_conversion
    ADD CONSTRAINT unit_conversion_unit_to_fkey FOREIGN KEY (unit_to) REFERENCES soil_data.unit_of_measure(unit_of_measure_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5064 (class 2606 OID 55715767)
-- Name: url url_mapset_id_fkey; Type: FK CONSTRAINT; Schema: soil_data; Owner: sis
--

ALTER TABLE ONLY soil_data.url
    ADD CONSTRAINT url_mapset_id_fkey FOREIGN KEY (mapset_id) REFERENCES soil_data.mapset(mapset_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA api; Type: ACL; Schema: -; Owner: sis
--

GRANT USAGE ON SCHEMA api TO sis_r;
GRANT USAGE ON SCHEMA api TO sis_glosis;


--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA kobo; Type: ACL; Schema: -; Owner: sis
--

GRANT USAGE ON SCHEMA kobo TO sis_r;
GRANT ALL ON SCHEMA kobo TO kobo;


--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 13
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: sis
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA soil_data; Type: ACL; Schema: -; Owner: sis
--

GRANT USAGE ON SCHEMA soil_data TO sis_r;


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 15
-- Name: SCHEMA soil_data_upload; Type: ACL; Schema: -; Owner: sis
--

GRANT USAGE ON SCHEMA soil_data_upload TO sis_r;


--
-- TOC entry 5229 (class 0 OID 0)
-- Dependencies: 1638
-- Name: FUNCTION check_result_value(); Type: ACL; Schema: soil_data; Owner: sis
--

GRANT ALL ON FUNCTION soil_data.check_result_value() TO sis_r;


--
-- TOC entry 5231 (class 0 OID 0)
-- Dependencies: 1639
-- Name: FUNCTION class(); Type: ACL; Schema: soil_data; Owner: sis
--

GRANT ALL ON FUNCTION soil_data.class() TO sis_r;


--
-- TOC entry 5233 (class 0 OID 0)
-- Dependencies: 1640
-- Name: FUNCTION map(); Type: ACL; Schema: soil_data; Owner: sis
--

GRANT ALL ON FUNCTION soil_data.map() TO sis_r;


--
-- TOC entry 5235 (class 0 OID 0)
-- Dependencies: 1642
-- Name: FUNCTION sld(); Type: ACL; Schema: soil_data; Owner: sis
--

GRANT ALL ON FUNCTION soil_data.sld() TO sis_r;


--
-- TOC entry 5244 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE api_client; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.api_client TO sis_r;


--
-- TOC entry 5253 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE audit; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.audit TO sis_r;
GRANT INSERT ON TABLE api.audit TO sis_glosis;


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE dst_recipe; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.dst_recipe TO sis_r;


--
-- TOC entry 5258 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE setting; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.setting TO sis_r;
GRANT SELECT ON TABLE api.setting TO sis_glosis;


--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE uploaded_dataset; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.uploaded_dataset TO sis_r;


--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE uploaded_dataset_column; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.uploaded_dataset_column TO sis_r;


--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE uploaded_dataset_edit; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.uploaded_dataset_edit TO sis_r;


--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE "user"; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api."user" TO sis_r;


--
-- TOC entry 5302 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE element; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.element TO sis_r;


--
-- TOC entry 5340 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE layer; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.layer TO sis_r;


--
-- TOC entry 5381 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE mapset; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.mapset TO sis_r;


--
-- TOC entry 5389 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE observation_num; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.observation_num TO sis_r;


--
-- TOC entry 5393 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE plot; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.plot TO sis_r;


--
-- TOC entry 5398 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE profile; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.profile TO sis_r;


--
-- TOC entry 5402 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE project; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.project TO sis_r;


--
-- TOC entry 5406 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE project_site; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.project_site TO sis_r;


--
-- TOC entry 5410 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE site; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.site TO sis_r;


--
-- TOC entry 5415 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE specimen; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.specimen TO sis_r;


--
-- TOC entry 5416 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE vw_api_manifest; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.vw_api_manifest TO sis_r;


--
-- TOC entry 5417 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE vw_api_observation; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.vw_api_observation TO sis_r;


--
-- TOC entry 5418 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE vw_api_profile; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.vw_api_profile TO sis_r;


--
-- TOC entry 5419 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE vw_glosis_federation_token; Type: ACL; Schema: api; Owner: sis
--

GRANT SELECT ON TABLE api.vw_glosis_federation_token TO sis_r;
GRANT SELECT ON TABLE api.vw_glosis_federation_token TO sis_glosis;


--
-- TOC entry 5422 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE category_desc; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.category_desc TO sis_r;


--
-- TOC entry 5431 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE class; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.class TO sis_r;


--
-- TOC entry 5449 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE country; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.country TO sis_r;


--
-- TOC entry 5450 (class 0 OID 0)
-- Dependencies: 253
-- Name: SEQUENCE element_element_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.element_element_id_seq TO sis_r;


--
-- TOC entry 5454 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE individual; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.individual TO sis_r;


--
-- TOC entry 5458 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE languages; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.languages TO sis_r;


--
-- TOC entry 5470 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE mapped_property; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.mapped_property TO sis_r;


--
-- TOC entry 5471 (class 0 OID 0)
-- Dependencies: 258
-- Name: SEQUENCE observation_num_observation_num_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.observation_num_observation_num_id_seq TO sis_r;


--
-- TOC entry 5482 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE organisation; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.organisation TO sis_r;


--
-- TOC entry 5483 (class 0 OID 0)
-- Dependencies: 260
-- Name: SEQUENCE plot_plot_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.plot_plot_id_seq TO sis_r;


--
-- TOC entry 5488 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE procedure_desc; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.procedure_desc TO sis_r;


--
-- TOC entry 5492 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE procedure_num; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.procedure_num TO sis_r;


--
-- TOC entry 5493 (class 0 OID 0)
-- Dependencies: 269
-- Name: SEQUENCE profile_profile_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.profile_profile_id_seq TO sis_r;


--
-- TOC entry 5501 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE proj_x_org_x_ind; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.proj_x_org_x_ind TO sis_r;


--
-- TOC entry 5506 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE project_soil_map; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.project_soil_map TO sis_r;


--
-- TOC entry 5510 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE property_desc; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.property_desc TO sis_r;


--
-- TOC entry 5513 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE property_num; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.property_num TO sis_r;


--
-- TOC entry 5518 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE result_desc_element; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.result_desc_element TO sis_r;


--
-- TOC entry 5523 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE result_desc_plot; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.result_desc_plot TO sis_r;


--
-- TOC entry 5528 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE result_desc_profile; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.result_desc_profile TO sis_r;


--
-- TOC entry 5538 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE soil_map; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_map TO sis_r;


--
-- TOC entry 5539 (class 0 OID 0)
-- Dependencies: 281
-- Name: SEQUENCE soil_map_soil_map_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.soil_map_soil_map_id_seq TO sis_r;


--
-- TOC entry 5546 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE soil_mapping_unit; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_mapping_unit TO sis_r;


--
-- TOC entry 5557 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE soil_mapping_unit_category; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_mapping_unit_category TO sis_r;


--
-- TOC entry 5558 (class 0 OID 0)
-- Dependencies: 284
-- Name: SEQUENCE soil_mapping_unit_category_category_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.soil_mapping_unit_category_category_id_seq TO sis_r;


--
-- TOC entry 5559 (class 0 OID 0)
-- Dependencies: 285
-- Name: SEQUENCE soil_mapping_unit_mapping_unit_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.soil_mapping_unit_mapping_unit_id_seq TO sis_r;


--
-- TOC entry 5565 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE soil_mapping_unit_profile; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_mapping_unit_profile TO sis_r;


--
-- TOC entry 5573 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE soil_typological_unit; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_typological_unit TO sis_r;


--
-- TOC entry 5579 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE soil_typological_unit_mapping_unit; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_typological_unit_mapping_unit TO sis_r;


--
-- TOC entry 5585 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE soil_typological_unit_profile; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.soil_typological_unit_profile TO sis_r;


--
-- TOC entry 5586 (class 0 OID 0)
-- Dependencies: 290
-- Name: SEQUENCE soil_typological_unit_typological_unit_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.soil_typological_unit_typological_unit_id_seq TO sis_r;


--
-- TOC entry 5587 (class 0 OID 0)
-- Dependencies: 291
-- Name: SEQUENCE specimen_specimen_id_seq; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON SEQUENCE soil_data.specimen_specimen_id_seq TO sis_r;


--
-- TOC entry 5602 (class 0 OID 0)
-- Dependencies: 296
-- Name: TABLE translate; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.translate TO sis_r;


--
-- TOC entry 5603 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE unit_conversion; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.unit_conversion TO sis_r;


--
-- TOC entry 5607 (class 0 OID 0)
-- Dependencies: 298
-- Name: TABLE unit_of_measure; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.unit_of_measure TO sis_r;


--
-- TOC entry 5614 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE url; Type: ACL; Schema: soil_data; Owner: sis
--

GRANT SELECT ON TABLE soil_data.url TO sis_r;


--
-- TOC entry 3569 (class 826 OID 55715772)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: api; Owner: sis
--

ALTER DEFAULT PRIVILEGES FOR ROLE sis IN SCHEMA api GRANT SELECT ON TABLES TO sis_r;


--
-- TOC entry 3570 (class 826 OID 55715773)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: soil_data; Owner: sis
--

ALTER DEFAULT PRIVILEGES FOR ROLE sis IN SCHEMA soil_data GRANT SELECT ON TABLES TO sis_r;


--
-- TOC entry 3571 (class 826 OID 55715774)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: soil_data_upload; Owner: sis
--

ALTER DEFAULT PRIVILEGES FOR ROLE sis IN SCHEMA soil_data_upload GRANT SELECT ON TABLES TO sis_r;


-- Completed on 2026-06-24 06:13:28 CEST

--
-- PostgreSQL database dump complete
--

\unrestrict IaVCJgHhGyrrcjzYIfJyV7ehzpM6ddVrUKoS5dDYY9OVI5hzgkcf7wkIJwTu42Y


-- ============================================================================
-- Administrative division layers (kept in step with migration 008)
-- ============================================================================

CREATE TABLE IF NOT EXISTS api.admin_division (
    division_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text    NOT NULL,
    display_order integer NOT NULL DEFAULT 0,
    stroke_color  text    NOT NULL DEFAULT '#444444',
    stroke_width  real    NOT NULL DEFAULT 1.5,
    stroke_type   text    NOT NULL DEFAULT 'solid',
    fill_color    text    NOT NULL DEFAULT '#cccccc',
    fill_opacity  real    NOT NULL DEFAULT 0,
    is_published  boolean NOT NULL DEFAULT true,
    feature_count integer NOT NULL DEFAULT 0,
    file_name     text,
    uploaded_by   text,
    uploaded_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api.admin_division_feature (
    feature_id  bigint  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    division_id integer NOT NULL
                REFERENCES api.admin_division(division_id) ON DELETE CASCADE,
    properties  jsonb,
    geom        public.geometry(MultiPolygon, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_admin_division_feature_division
    ON api.admin_division_feature (division_id);
CREATE INDEX IF NOT EXISTS idx_admin_division_feature_geom
    ON api.admin_division_feature USING gist (geom);
