
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
			id_base_site,
			geom AS the_geom_4326,
			ST_CENTROID(geom) AS the_geom_point,
			geom_local as the_geom_local 
		FROM gn_monitoring.t_base_sites
	), 
	visits AS (
		SELECT
			id_base_visit,
			uuid_base_visit,
			id_module,
			id_base_site,
			id_dataset,
			id_digitiser,
			visit_date_min AS date_min,
			COALESCE (visit_date_max, visit_date_min) AS date_max,
			comments,
			id_nomenclature_tech_collect_campanule,
			id_nomenclature_grp_typ
		FROM gn_monitoring.t_base_visits

	), observers AS (
		SELECT
			array_agg(r.id_role) AS ids_observers,
			STRING_AGG(CONCAT(r.nom_role, ' ', prenom_role), ' ; ') AS observers,
			id_base_visit
		FROM gn_monitoring.cor_visit_observer cvo
		JOIN utilisateurs.t_roles r
		ON r.id_role = cvo.id_role
		GROUP BY id_base_visit
	), 
	obsc AS (
		SELECT 
			oc.id_observation,
			(oc."data"->'id_nomenclature_loca_obs')::integer AS id_nomenclature_loca_obs,
			(oc."data"->'id_nomenclature_sex')::integer AS id_nomenclature_sex,
			(oc."data"->'id_nomenclature_life_stage')::integer AS id_nomenclature_life_stage,
			(oc."data"->'id_nomenclature_obs_technique')::integer AS id_nomenclature_obs_technique,
			(oc."data"->'id_nomenclature_determination_method')::integer AS id_nomenclature_determination_method,
			oc.data->>'count_min'AS count_min,
			oc.data->>'count_max'AS count_max,
			CASE WHEN (oc."data"->>'tranche_horaire') is true THEN 'Dans les 2h après le couché du soleil'
				ELSE 'Plus de 2h après le couché du soleil' END AS tranche
		FROM gn_monitoring.t_observation_complements oc
	), 
	obsc_2 AS (
		SELECT
			(SELECT count(*) FROM obsc oc WHERE oc.id_observation = o.id_observation) AS n_ids,
			obsc.*
		FROM gn_monitoring.t_observations o
		JOIN obsc USING (id_observation)
	)
	SELECT
		o.uuid_observation AS unique_id_sinp, 
		v.uuid_base_visit AS unique_id_sinp_grp,
		source.id_source,
		o.id_observation AS entity_source_pk_value,
		-- site
		s.id_nomenclature_type_site,
		alt.altitude_min,
		alt.altitude_max,
		-- visit
		v.id_dataset,
		v.id_base_site,
		ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'In') AS id_nomenclature_geo_object_nature,
		v.id_nomenclature_tech_collect_campanule , 
		v.id_nomenclature_grp_typ, 
		v.id_base_visit,
		v.id_digitiser,
		v.date_min,
		v.date_max,
		v.comments AS comment_context,
		-- obs
		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR','NSP') AS id_nomenclature_obj_count,
		ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'NSP') AS id_nomenclature_type_count , --Ne sait pas
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status , -- Terrain
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type , -- géoréférencement
		ref_nomenclatures.get_id_nomenclature('NIV_PRECIS', '2') as id_nomenclature_diffusion_level, -- diffusion à la maille
		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status , -- présence
		id_observation,
		oc.id_nomenclature_obs_technique,
		oc.id_nomenclature_determination_method,
		oc.id_nomenclature_life_stage,
		oc.id_nomenclature_sex,
		oc.ids_observers,
		oc.observers,
		t.cd_nom,
		t.nom_complet AS nom_cite,
		jsonb_build_object(
			'tranche_horaire', oc2.tranche_horaire, 'loca_obs', oc2.id_nomenclature_loca_obs,
		) as additional_data,
		o.comments AS comment_description,
		-- géométries
		s.the_geom_4326,
		s.the_geom_point,
		s.the_geom_local,
		-- autres informations
		v.id_module,
	FROM gn_monitoring.t_observations o 
	JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
	JOIN obsc_2 oc2 USING (id_observation)
	--JOIN ref_nomenclatures.t_nomenclatures n_stade ON n_stade.id_nomenclature = (oc.data->>'id_nomenclature_stade')::int 
	JOIN visits v
		ON v.id_base_visit = o.id_base_visit
	JOIN sites s 
		ON s.id_base_site = v.id_base_site
	JOIN gn_commons.t_modules m 
		ON m.id_module = v.id_module
	JOIN taxonomie.taxref t 
		ON t.cd_nom = o.cd_nom
	JOIN source 
		ON TRUE
	JOIN observers obs 
		ON obs.id_base_visit = v.id_base_visit
	LEFT JOIN LATERAL ref_geo.fct_get_altitude_intersection(s.the_geom_local) alt (altitude_min, altitude_max)
		ON TRUE
	WHERE m.module_code = :'module_code'
;
