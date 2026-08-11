-- ============================================================================
-- 008_admin_divisions.sql
--
-- Administrative division layers: admin-uploaded polygon boundaries (country,
-- provinces, municipalities, …) shown on the map under an "Administrative
-- divisions" group. Each layer has a custom name (levels differ per country)
-- and customisable symbology. Deliberately outside the mapset/layer model —
-- these carry no catalogue metadata and never publish to pyCSW or the
-- federation.
--
-- Idempotent: CREATE TABLE / INDEX IF NOT EXISTS.
-- ============================================================================

CREATE TABLE IF NOT EXISTS api.admin_division (
    division_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text    NOT NULL,
    display_order integer NOT NULL DEFAULT 0,
    stroke_color  text    NOT NULL DEFAULT '#444444',
    stroke_width  real    NOT NULL DEFAULT 1.5,
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
    geom        geometry(MultiPolygon, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_admin_division_feature_division
    ON api.admin_division_feature (division_id);
CREATE INDEX IF NOT EXISTS idx_admin_division_feature_geom
    ON api.admin_division_feature USING gist (geom);
