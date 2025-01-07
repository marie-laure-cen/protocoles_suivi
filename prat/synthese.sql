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
	WITH source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1
	), 
	sites AS (
		SELECT
			id_base_site,
			altitude_min,
			altitude_max,
			geom AS the_geom_4326,
			ST_CENTROID(geom) AS the_geom_point,
			geom_local as geom_local
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
			id_nomenclature_grp_typ,
			data
		FROM gn_monitoring.t_base_visits
		LEFT JOIN gn_monitoring.t_visit_complements USING (id_base_visit)
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
		o.uuid_observation AS unique_id_sinp,
		v.uuid_base_visit AS unique_id_sinp_grp,
		source.id_source,
		o.id_observation AS entity_source_pk_value,
		v.id_dataset,
		ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'In') AS id_nomenclature_geo_object_nature, -- Inventoriel
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'OBS') AS id_nomenclature_grp_typ, -- Observation
		ref_nomenclatures.get_id_nomenclature('METH_OBS', '21') AS id_nomenclature_obs_technique, -- Inconnu
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '133') AS id_nomenclature_tech_collect_campanule, --Non renseigné
		ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '0') AS id_nomenclature_bio_status, -- Inconnu
		ref_nomenclatures.get_id_nomenclature('ETA_BIO', '0') AS id_nomenclature_bio_condition, -- NSP
		ref_nomenclatures.get_id_nomenclature('NATURALITE', '0') AS id_nomenclature_naturalness, -- Inconnu
		ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '2') AS id_nomenclature_exist_proof, -- Non
		ref_nomenclatures.get_id_nomenclature('NATURALITE', '0') AS id_nomenclature_valid_status,  -- En attente de validation
		-- id_nomenclature_diffusion_level, -- NIV_PRECIS
		ref_nomenclatures.get_id_nomenclature('STADE_VIE', '0') AS id_nomenclature_life_stage, -- Inconnu
		ref_nomenclatures.get_id_nomenclature('SEXE', '6') AS id_nomenclature_sex, -- Non renseigné
		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'NSP') AS id_nomenclature_obj_count, -- Ne sait pas
		ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Es') AS id_nomenclature_type_count, -- Estimé
		-- id_nomenclature_sensitivity, --SENSIBILITE
		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, -- Présent
		-- id_nomenclature_blurring, -- DEE_FLOU
		ref_nomenclatures.get_id_nomenclature('OCC_COMPORTEMENT', '0') AS id_nomenclature_behaviour, -- Inconnu
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Li') AS id_nomenclature_source_status, -- Littérature
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '2') AS id_nomenclature_info_geo_type, -- Rattachement
		1 AS count_min,
		1 AS count_max,
		o.id_observation,
		o.cd_nom,
		t.nom_complet AS nom_cite,
		--meta_v_taxref
		--sample_number_proof
		--digital_proofvue
		s.altitude_min,
		s.altitude_max,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local as the_geom_local,
		v.date_min,
		v.date_max,
		--validator
		--validation_comment
		COALESCE (obs.observers, v.data ->>'observers_txt') as observers,
		--determiner
		v.id_digitiser,
		ref_nomenclatures.get_id_nomenclature('METH_DETERMIN', '1') AS id_nomenclature_determination_method, -- Non renseigné
		--meta_validation_date
		--meta_create_date,
		--meta_update_date,
		--last_action
		v.id_module,
		v.comments AS comment_context,
		o.comments AS comment_description,
		obs.ids_observers,
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		v.id_base_site,
		v.id_base_visit
	FROM gn_monitoring.t_observations o
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
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	WHERE m.module_code = :'module_code'
;


--SELECT * FROM gn_monitoring.v_synthese_:module_code