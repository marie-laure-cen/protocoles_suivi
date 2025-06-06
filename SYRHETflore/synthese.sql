
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

DROP VIEW IF EXISTS gn_monitoring.v_synthese_syrhetflore;

CREATE VIEW gn_monitoring.v_synthese_syrhetflore AS
	WITH 
	srce AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE name_source = 'MONITORING_SYRHETFLORE'

	), 
	sites AS (
		SELECT
			tbs.id_base_site,
			tbs.altitude_min,
			tbs.altitude_max,
			tsg.sites_group_name,
			tsg.sites_group_code,
			tsc.data,
			tbs.geom AS the_geom_4326,
			ST_CENTROID(tbs.geom) AS the_geom_point,
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.cor_site_module csm USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             JOIN srce ON csm.id_module = srce.id_module
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			srce.id_source,
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_dataset,
			tbv.id_digitiser,
			tbv.visit_date_min AS date_min,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tbv.id_nomenclature_tech_collect_campanule,
			tbv.id_nomenclature_grp_typ,
			tvc.data
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		INNER JOIN srce USING (id_module)
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
		o.id_observation,
		v.id_dataset,o.cd_nom,
		t.nom_complet AS nom_cite,
		v.date_min,
		v.date_max,
		v.comments AS comment_context,
		o.comments AS comment_description,
		obs.observers,
		(oc.data->'determiner')::integer as determiner,
		(oc.data->'determiner')::integer as validator,
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'In') AS id_nomenclature_geo_object_nature, -- Stationnel
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'REL') AS id_nomenclature_grp_typ, -- Relevé phytosociologique
		(oc.data->'id_nomenclature_obs_technique')::integer as id_nomenclature_obs_technique, -- METH_OBS
		(s.data -> 'id_nomenclature_tech_collect_campanule')::integer AS id_nomenclature_tech_collect_campanule, -- Piégeage lumineux automatique à fluorescence
		ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '1') AS id_nomenclature_bio_status, -- Non renseigné
		(oc.data->'id_nomenclature_determination_method')::integer AS id_nomenclature_determination_method,
		ref_nomenclatures.get_id_nomenclature('ETA_BIO', '1') AS id_nomenclature_bio_condition, -- Non renseigné
		ref_nomenclatures.get_id_nomenclature('NATURALITE', '1' ) AS id_nomenclature_naturalness, -- Sauvage
		ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '2' ) AS id_nomenclature_exist_proof, --  non
		ref_nomenclatures.get_id_nomenclature('STATUT_VALID', '1' ) AS id_nomenclature_valid_status, -- certain / très probable
		ref_nomenclatures.get_id_nomenclature('SEXE', '6' ) AS id_nomenclature_sex, --non renseigné
 		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'SURF' ) AS id_nomenclature_obj_count, -- l'objet du dénombrement est le nombre d'individus
 		ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Es') AS id_nomenclature_type_count, -- les individuas sont comptés
 		-- id_nomenclature_sensitivity, --SENSIBILITE
 		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, -- le taxon est présent
		-- id_nomenclature_blurring, -- DEE_FLOU
        ref_nomenclatures.get_id_nomenclature('OCC_COMPORTEMENT', '1') AS id_nomenclature_behaviour, -- non renseigné
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status, -- la source est le terrain
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type, -- la localisation est réalisée par Géoréférencement
		1 AS count_min,			
		1 AS count_max,
		--meta_v_taxref
		--sample_number_proof
		--digital_proofvue
		--validation_comment
		v.id_digitiser,
		--meta_validation_date
		--v.meta_create_date,
		--v.meta_update_date,
		--last_action,
		s.altitude_min,
		s.altitude_max,
		s.sites_group_name as place_name,
		jsonb_build_object(
			'strate', oc.data -> 'strate',
			'recouvrement', oc.data -> 'recouvrement',
			'aire', v.data -> 'aire',
			'aire_compl', v.data -> 'compl_aire'
		) as additionnal_data,
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		obs.ids_observers,
		v.id_source,
		v.id_module,
		v.id_base_site,
		v.uuid_base_visit AS unique_id_sinp_grp,
		v.id_base_visit,
		o.uuid_observation AS unique_id_sinp,
		o.id_observation AS entity_source_pk_value,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local as the_geom_local
    FROM gn_monitoring.t_observations o 
	LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
    JOIN visits v
        ON v.id_base_visit = o.id_base_visit
    JOIN sites s
        ON s.id_base_site = v.id_base_site
	LEFT JOIN gn_commons.t_modules m
        ON m.id_module = v.id_module
	JOIN taxonomie.taxref t
        ON t.cd_nom = o.cd_nom
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
;
