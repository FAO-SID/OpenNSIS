-- ============================================================================
-- 002_vw_api_profile_mapset_id.sql
--
-- api.vw_api_profile must expose mapset_id (= country_id || '-' || project_id)
-- so the map-view profile metadata/popup can resolve a profile's mapset. A
-- column-shape change, so DROP + CREATE (the view has no dependents); fully
-- re-runnable. Already present in fresh dumps — this converges older installs.
-- ============================================================================

DROP VIEW IF EXISTS api.vw_api_profile CASCADE;
CREATE VIEW api.vw_api_profile AS
 WITH ranked AS (
         SELECT p.profile_id AS gid,
            p.profile_code,
            proj.project_id,
            proj.name AS project_name,
            (proj.country_id || '-'::text) || proj.project_id AS mapset_id,
            pl.is_published,
            pm.profile_limit,
            pm.spatial_blur_m,
            plt.altitude,
            plt.sampling_date AS date,
            plt.geom AS raw_geom,
            row_number() OVER (PARTITION BY proj.country_id, proj.project_id ORDER BY p.profile_id) AS rn
           FROM soil_data.profile p
             JOIN soil_data.plot plt ON p.plot_id = plt.plot_id
             JOIN soil_data.site s ON plt.site_id = s.site_id
             LEFT JOIN soil_data.project_site ps ON s.site_id = ps.site_id
             LEFT JOIN soil_data.project proj ON ps.country_id = proj.country_id AND ps.project_id = proj.project_id
             LEFT JOIN soil_data.mapset pm ON pm.mapset_id = ((proj.country_id || '-'::text) || proj.project_id)
             LEFT JOIN soil_data.layer pl ON pl.layer_id = ((proj.country_id || '-'::text) || proj.project_id)
          WHERE plt.geom IS NOT NULL
        ), pub AS (
         SELECT ranked.gid,
            ranked.profile_code,
            ranked.project_name,
            ranked.mapset_id,
            ranked.altitude,
            ranked.date,
            api.blur_geom(ranked.raw_geom, ranked.gid::text, ranked.spatial_blur_m) AS geom
           FROM ranked
          WHERE ranked.is_published = true AND (ranked.profile_limit IS NULL OR ranked.rn <= ranked.profile_limit)
        )
 SELECT gid,
    profile_code,
    project_name,
    mapset_id,
    altitude,
    date,
    geom,
    st_asgeojson(geom)::json AS geometry
   FROM pub
  ORDER BY gid;

ALTER VIEW api.vw_api_profile OWNER TO sis;
GRANT SELECT ON TABLE api.vw_api_profile TO sis_r;
