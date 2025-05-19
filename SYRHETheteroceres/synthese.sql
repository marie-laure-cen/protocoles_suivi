
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

DROP VIEW IF EXISTS gn_monitoring.v_synthese_syrhetheteroceres;

CREATE VIEW gn_monitoring.v_synthese_syrhetheteroceres AS
	WITH 
	srce AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE name_source = 'MONITORING_SYRHETSYRPHES'
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
			tbv.id_nomenclature_grp_typ
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
        o.uuid_observation AS unique_id_sinp,
		v.uuid_base_visit AS unique_id_sinp_grp,
		v.id_source,
		o.id_observation AS entity_source_pk_value,
		v.id_dataset,
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature, -- Stationnel
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'PASS') AS id_nomenclature_grp_typ, -- Passage
		(oc.data->'id_nomenclature_obs_technique')::integer as id_nomenclature_obs_technique, -- METH_OBS
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '94') AS id_nomenclature_tech_collect_campanule, -- Piégeage lumineux automatique à fluorescence
		ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '1') AS id_nomenclature_bio_status, -- Non reiseigné
		ref_nomenclatures.get_id_nomenclature('ETA_BIO', '1') AS id_nomenclature_bio_condition, -- Non renseigné
		ref_nomenclatures.get_id_nomenclature('NATURALITE', '1' ) AS id_nomenclature_naturalness, -- Sauvage
		CASE
			WHEN (oc.data->>'collection') = 'Oui' THEN ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '1' )
			ELSE ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '2' )
		END AS id_nomenclature_exist_proof, -- si collecte échantillon oui sinon non
		ref_nomenclatures.get_id_nomenclature('STATUT_VALID', '1' ) AS id_nomenclature_valid_status, -- certain / très probable
		(oc.data->>'id_nomenclature_life_stage')::integer as id_nomenclature_life_stage, -- STADE_VIE
		(oc.data->>'id_nomenclature_sex')::integer as id_nomenclature_sex, -- SEXE
 		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'IND' ) AS id_nomenclature_obj_count, -- l'objet du dénombrement est le nombre d'individus
 		ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Co') AS id_nomenclature_type_count, -- les individuas sont comptés
 		-- id_nomenclature_sensitivity, --SENSIBILITE
 		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, -- le taxon est présent
		-- id_nomenclature_blurring, -- DEE_FLOU
        ref_nomenclatures.get_id_nomenclature('OCC_COMPORTEMENT', '1') AS id_nomenclature_behaviour, -- non renseigné
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status, -- la source est le terrain
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type, -- la localisation est réalisée par Géoréférencement
		(oc.data->>'effectif')::integer AS count_min,
		(oc.data->>'effectif')::integer AS count_max,
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
		(oc.data->>'determiner')::integer as validator,
		--validation_comment
		obs.observers,
		(oc.data->>'determiner')::integer AS determiner,
		v.id_digitiser,
		(oc.data->>'id_nomenclature_determination_method')::integer AS id_nomenclature_determination_method,
		--meta_validation_date
		--v.meta_create_date,
		--v.meta_update_date,
		--last_action,
		v.id_module,
		v.comments AS comment_context,
		o.comments AS comment_description,
		obs.ids_observers,
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		v.id_base_site,
		v.id_base_visit
    FROM gn_monitoring.t_observations o 
	LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
    JOIN visits v
        ON v.id_base_visit = o.id_base_visit
    JOIN sites s
        ON s.id_base_site = v.id_base_site
	LEFT JOIN gn_monitoring.t_site_complements v_compl ON v_compl.id_base_site = v.id_base_site
	LEFT JOIN gn_commons.t_modules m
        ON m.id_module = v.id_module
	JOIN taxonomie.taxref t
        ON t.cd_nom = o.cd_nom
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
;