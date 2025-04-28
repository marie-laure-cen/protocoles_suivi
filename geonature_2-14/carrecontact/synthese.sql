
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
	srce AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
	), 
	sites AS (
		SELECT
			tbs.id_base_site,
			(tsg.data ->> 'id_dataset'::text)::integer AS id_dataset,
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
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		JOIN srce s ON tsc.id_module = s.id_module
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_digitiser,
			tbv.visit_date_min AS date_min,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tbv.id_nomenclature_tech_collect_campanule,
			tbv.id_nomenclature_grp_typ,
			tvc.data,
			s.id_source
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		JOIN srce s ON tbv.id_module = s.id_module
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
		s.id_dataset,
		o.cd_nom,
		tx.nom_complet AS nom_cite,
		v.date_min,
		v.date_max,
		v.comments AS comment_context,
		(v.data->>'determiner')::integer  AS comment_description,
		obs.observers,
		'Coefficient de recouvrement : ' || (oc.data->>'coefficient') as comment_context,
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '59') AS id_nomenclature_tech_collect_campanule, -- Observation directe diurne
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature, -- Stationnel
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'REL') AS id_nomenclature_grp_typ, -- Relevé
		(oc.data->'id_nomenclature_obs_technique')::integer as id_nomenclature_obs_technique, -- METH_OBS
		(oc.data->'id_nomenclature_determination_method')::integer AS id_nomenclature_determination_method, -- METH_DETERMIN
		ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '1') AS id_nomenclature_bio_status, -- Non renseigné
		ref_nomenclatures.get_id_nomenclature('ETA_BIO', '1') AS id_nomenclature_bio_condition, -- Non renseigné
		ref_nomenclatures.get_id_nomenclature('NATURALITE', '1' ) AS id_nomenclature_naturalness, -- Sauvage
		ref_nomenclatures.get_id_nomenclature('PREUVE_EXIST', '2' ) AS id_nomenclature_exist_proof, --  non
		ref_nomenclatures.get_id_nomenclature('STATUT_VALID', '1' ) AS id_nomenclature_valid_status, -- certain / très probable
		ref_nomenclatures.get_id_nomenclature('SEXE', '6' ) AS id_nomenclature_sex, --non renseigné
 		ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'NSP' ) AS id_nomenclature_obj_count, -- ne sait pas
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
		s.sites_group_name || '('|| (s.data->>'commune')  || ') | T' || (v.data->> 'transect')  || 'Q' || (v.data->> 'quadrat') as place_name,
		jsonb_build_object(
			'rel_recouvrement', v.data ->> 'taux_recouvrement',
			'rel_ht_vegetation', v.data ->> 'hauteur_vegetation',
			'rel_strate_bryo', v.data ->> 'strate_bryo',
			'espece_recouvrement', oc.data ->> 'coefficient'
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
	JOIN taxonomie.taxref tx
        ON tx.cd_nom = o.cd_nom
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
;
