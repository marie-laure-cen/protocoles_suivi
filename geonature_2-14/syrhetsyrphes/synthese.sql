
-- Vue générique pour alimenter la synthèse dans le cadre d'un protocole site-visite-observation
-- 
-- Ce fichier peut être copié dans le dossier du sous-module et renommé en synthese.sql (et au besoin personnalisé)
-- le fichier sera joué à l'installation avec la valeur de module_code qui sera attribué automatiquement
--
--
-- Personalisations possibles
--
--  - ajouter des champs specifiques qui peuvent alimenter la synthese
--      jointure avec les table de complement
--
--  - choisir les valeurs de champs de nomenclatures qui seront propres au modules


-- ce fichier contient une variable :module_code (ou :'module_code')
-- utiliser psql avec l'option -v module_code=<module_code

-- ne pas remplacer cette variable, elle est indispensable pour les scripts d'installations
-- le module pouvant être installé avec un code différent de l'original

DROP VIEW IF EXISTS gn_monitoring.v_synthese_:module_code;

CREATE VIEW gn_monitoring.v_synthese_:module_code AS
	WITH 
	source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1

	), 
	sites AS (
		SELECT
			tbs.id_base_site,
			(tsg.sites_group_name || ' / ' || tbs.base_site_code) as place_name,
			tbs.altitude_min,
			tbs.altitude_max,
			tsc.data as site_data,
			tbs.geom AS the_geom_4326,
			ST_CENTROID(tbs.geom) AS the_geom_point,
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
      		tbv.id_module,
			tbv.id_base_site,
       	 	tbv.id_dataset,
        	tbv.id_digitiser,
        	tbv.visit_date_min AS date_min,
	    	COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tvc.data as visit_data
        FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	), 
	observers AS (
		SELECT
			array_agg(r.id_role) AS ids_observers,
			STRING_AGG(CONCAT(r.nom_role, ' ', prenom_role), ' ; ') AS observers,
			id_base_visit
		FROM gn_monitoring.cor_visit_observer cvo
		JOIN utilisateurs.t_roles r
		ON r.id_role = cvo.id_role
		GROUP BY id_base_visit
	)
	SELECT
       det.uuid_observation_detail AS unique_id_sinp,
		v.uuid_base_visit AS unique_id_sinp_grp,
		srce.id_source,
		det.id_observation_detail AS entity_source_pk_value,
		v.id_dataset,
		ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO'::character varying, 'St'::character varying) AS id_nomenclature_geo_object_nature,
		ref_nomenclatures.get_id_nomenclature('TYP_GRP'::character varying, 'CAMP'::character varying) AS id_nomenclature_grp_typ,
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS'::character varying, '100'::character varying) AS id_nomenclature_tech_collect_campanule,
		(o_compl.data ->> 'id_nomenclature_obs_technique'::text)::integer AS id_nomenclature_obs_technique,
		ref_nomenclatures.get_id_nomenclature('NATURALITE'::character varying, '1'::character varying) AS id_nomenclature_naturalness,
		(det.data ->> 'id_nomenclature_life_stage'::text)::integer AS id_nomenclature_life_stage,
		(det.data ->> 'id_nomenclature_sex'::text)::integer AS id_nomenclature_sex,
		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR'::character varying, 'IND'::character varying) AS id_nomenclature_obj_count,
		ref_nomenclatures.get_id_nomenclature('TYP_DENBR'::character varying, 'Co'::character varying) AS id_nomenclature_type_count,
		ref_nomenclatures.get_id_nomenclature('STATUT_OBS'::character varying, 'Pr'::character varying) AS id_nomenclature_observation_status,
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE'::character varying, 'Te'::character varying) AS id_nomenclature_source_status,
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO'::character varying, '1'::character varying) AS id_nomenclature_info_geo_type,
		(det.data ->> 'count_min'::text)::integer AS count_min,
		(det.data ->> 'count_max'::text)::integer AS count_max,
		o.cd_nom,
		t.nom_complet AS nom_cite,
		s.altitude_min,
		s.altitude_max,
		s.place_name,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local AS the_geom_local,
		v.date_min,
		v.date_max,
		obs.observers,
		(det.data ->> 'determiner'::text) AS determiner,
		v.id_digitiser,
		(o_compl.data ->> 'id_nomenclature_determination_method'::text)::integer AS id_nomenclature_determination_method,
		v.id_module,
		(s.site_data ->> 'habitat')::text AS comment_context,
		o.comments AS comment_description,
		obs.ids_observers,
		v.id_base_site,
		v.id_base_visit
    FROM gn_monitoring.t_observation_details det
	LEFT JOIN gn_monitoring.t_observations o USING (id_observation)
	LEFT JOIN gn_monitoring.t_observation_complements o_compl USING (id_observation)
    JOIN visits v
        ON v.id_base_visit = o.id_base_visit
    JOIN sites s
        ON s.id_base_site = v.id_base_site
	LEFT JOIN gn_monitoring.t_site_complements v_compl ON v_compl.id_base_site = v.id_base_site
	LEFT JOIN gn_commons.t_modules m
        ON m.id_module = v.id_module
	JOIN taxonomie.taxref t
        ON t.cd_nom = o.cd_nom
	LEFT JOIN srce
        ON TRUE
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	WHERE m.module_code = :'module_code'
;
