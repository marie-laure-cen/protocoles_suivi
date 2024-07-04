DROP VIEW  IF EXISTS  gn_monitoring.v_export_piezo_visit;

CREATE OR REPLACE VIEW gn_monitoring.v_export_piezo_visit AS

WITH source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1
	),
  sites AS (
    SELECT 
      tbs.id_base_site,
      tsg.sites_group_code::integer AS id_site,
      tbs.base_site_code as piezo,
      tbs.base_site_name as protocole,
      (tsc.data -> 'modele')::text as modele,
      tbs.base_site_description AS site_comments,
      tbs.altitude_min,
      tbs.altitude_max,
      tbs.geom AS the_geom_4326,
      st_centroid(tbs.geom) AS the_geom_point,
      tbs.geom_local
      FROM gn_monitoring.t_base_sites tbs
        LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
        LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
  ),
  observers AS (
    SELECT array_agg(r.id_role) AS ids_observers,
      string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
      cvo.id_base_visit
    FROM gn_monitoring.cor_visit_observer cvo
      JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
    GROUP BY cvo.id_base_visit
  )
 SELECT 
    -- piézomètre
    s.id_site,
    s.piezo,
    s.protocole,
    s.modele,
    s.altitude_min,
    s.altitude_max,
    -- sondages
    date_part('year'::text, v.visit_date_min) AS annee,
    (tvc.data -> 'num_sondage') as num_sondage,
    v.visit_date_min as date_sondage,
    (digit.nom_role || ' ' || digit.prenom_role) as numerisateur_sondage,
    utils.observers as observateurs_sondage,
    'Terrain'::text AS source_status,
    'Géoréférencement'::text AS info_geo_type,
    s.site_comments || ' / ' || v.comments AS comment_context,
    -- Infos générales
    m.module_code AS suivi,
    v.uuid_base_visit AS unique_id_sinp_grp,
    v.id_dataset,
    -- géométrie
    s.the_geom_4326,
    s.the_geom_point,
    s.geom_local
    FROM gn_monitoring.t_base_visits v
      LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
      JOIN sites s USING (id_base_site)
      JOIN gn_commons.t_modules m USING (id_module)
      JOIN source ON true
      JOIN observers utils USING (id_base_visit)
      LEFT JOIN utilisateurs.t_roles digit ON id_digitiser = id_role
    WHERE m.module_code =  :'module_code'
  ORDER BY s.id_site, s.piezo, (date_part('year'::text, v.visit_date_min)), (tvc.data -> 'num_sondage') 
  ;
  
  -- View: gn_monitoring.v_export_piezo_site

DROP VIEW  IF EXISTS  gn_monitoring.v_export_piezo_site;

CREATE OR REPLACE VIEW gn_monitoring.v_export_piezo_site AS

WITH source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1
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
	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	JOIN gn_commons.t_modules m ON tsg.id_module = m.id_module
	JOIN source ON true
    WHERE m.module_code =  :'module_code'
	ORDER BY tsg.sites_group_code, tbs.base_site_code
	;