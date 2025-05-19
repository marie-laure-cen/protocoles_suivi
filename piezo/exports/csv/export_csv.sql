DROP VIEW  IF EXISTS  gn_monitoring.v_export_piezo_site;

CREATE OR REPLACE VIEW gn_monitoring.v_export_piezo_site AS

WITH source AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
	)
 SELECT 
      -- piézomètre
    tsg.sites_group_code AS id_site,
    tbs.base_site_code as piezo,
    tbs.base_site_name as protocole,
    (tsc.data -> 'modele')::text as modele,
    tbs.base_site_description AS site_comments,
    tbs.altitude_min,
    tbs.altitude_max,
    -- Infos générales
     m.module_code AS suivi,
    tbs.id_base_site AS unique_id_piezo,
    -- géométrie
    tbs.geom AS the_geom_4326,
    st_centroid(tbs.geom) AS the_geom_point,
    tbs.geom_local
  FROM gn_monitoring.t_base_sites tbs
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
  LEFT JOIN gn_monitoring.cor_site_module csm USING (id_base_site)
	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	JOIN gn_commons.t_modules m ON csm.id_module = m.id_module
	JOIN source ON true
  WHERE m.module_code =  :'module_code'
	ORDER BY tsg.sites_group_code, tbs.base_site_code
	;