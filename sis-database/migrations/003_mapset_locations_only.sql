-- ============================================================================
-- 003_mapset_locations_only.sql
--
-- Per-project "share locations only" flag. When set, the project's profile
-- POINTS still publish (api.vw_api_profile is unchanged, so they appear on the
-- map) but NO observational data is shared: api.vw_api_observation excludes
-- those profiles, so the SIS map's data panel / CSV / click popup AND the
-- GloSIS federation (both read this view) return nothing for them.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE VIEW (output columns
-- unchanged — only an extra filter in the CTE).
-- ============================================================================

ALTER TABLE soil_data.mapset
  ADD COLUMN IF NOT EXISTS locations_only boolean NOT NULL DEFAULT false;

CREATE OR REPLACE VIEW api.vw_api_observation AS
 WITH ranked AS (
         SELECT p3.profile_id,
            p3.profile_code,
            proj.project_id,
            pl.is_published,
            pm.profile_limit,
            pm.locations_only,
            row_number() OVER (PARTITION BY proj.country_id, proj.project_id ORDER BY p3.profile_id) AS rn
           FROM soil_data.project proj
             LEFT JOIN soil_data.mapset pm ON pm.mapset_id = ((proj.country_id || '-'::text) || proj.project_id)
             LEFT JOIN soil_data.layer pl ON pl.layer_id = ((proj.country_id || '-'::text) || proj.project_id)
             LEFT JOIN soil_data.project_site sp ON sp.country_id = proj.country_id AND sp.project_id = proj.project_id
             LEFT JOIN soil_data.site s ON s.site_id = sp.site_id
             LEFT JOIN soil_data.plot p2 ON p2.site_id = s.site_id
             LEFT JOIN soil_data.profile p3 ON p3.plot_id = p2.plot_id
          WHERE p3.profile_id IS NOT NULL
        ), published AS (
         SELECT ranked.profile_id,
            ranked.profile_code
           FROM ranked
          WHERE ranked.is_published = true
            AND (ranked.profile_limit IS NULL OR ranked.rn <= ranked.profile_limit)
            AND (ranked.locations_only IS NOT TRUE)
        )
 SELECT pp.profile_code,
    e.upper_depth,
    e.lower_depth,
    o.property_num_id,
    o.procedure_num_id,
    r.value,
    o.unit_of_measure_id
   FROM published pp
     LEFT JOIN soil_data.element e ON e.profile_id = pp.profile_id
     LEFT JOIN soil_data.specimen s2 ON s2.element_id = e.element_id
     LEFT JOIN soil_data.result_num r ON r.specimen_id = s2.specimen_id
     LEFT JOIN soil_data.observation_num o ON o.observation_num_id = r.observation_num_id
  ORDER BY pp.profile_code, e.upper_depth, o.property_num_id;
