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
grp_site AS (
	SELECT
		-- Sites du CEN
		tsg.id_sites_group,
		tsg.sites_group_name,
		tsg.sites_group_code,
		-- Géométrie des sites CEN
		la.geom
	FROM gn_monitoring.t_sites_groups tsg
	LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_code = la.area_code
),
sites AS (
    SELECT
		-- Parcelle Travaux
        tbs.id_base_site,
		tsc.id_sites_group,
		tbs.id_inventor,
		tbs.id_digitiser,
		tsc.data,
		tbs.altitude_min,
		tbs.altitude_max,
		-- Géométrie parcelle travaux
        geom AS the_geom_4326,
	    ST_CENTROID(geom) AS the_geom_point,
	    geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
        LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
), 
visits AS (
    SELECT
		-- Intervention travaux
        tbv.id_base_visit,
        tbv.uuid_base_visit,
        tbv.id_module,
        tbv.id_base_site,
        tbv.id_dataset,
        tbv.id_digitiser,
		extract(year from tbv.visit_date_min) as annee,
        tbv.visit_date_min AS date_min,
	    COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
        tbv.comments,
		tvc.data
        FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
)
SELECT
		v.id_base_site,
		v.id_base_visit,
		v.uuid_base_visit AS unique_id_sinp_grp,
		source.id_source,
		'{' || s.id_inventor || ',' || v.id_digitiser ||'}' AS ids_observers,
		v.id_dataset,
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'NSP') AS id_nomenclature_geo_object_nature,
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'AUTR') AS id_nomenclature_grp_typ, -- 
		--id_nomen clature_obs_technique, -- METH_OBS
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '133') AS id_nomenclature_tech_collect_campanule, --
		--id_nomenclature_bio_status, -- STATUT_BIO
		--id_nomenclature_bio_condition, -- ETA_BIO
		--id_nomenclature_naturalness, -- NATURALITE
		--id_nomenclature_exist_proof, -- PREUVE_EXIST
		--id_nomenclature_valid_status,  --STATUT_VALID
		--id_nomenclature_diffusion_level, -- NIV_PRECIS
		--id_nomenclature_life_stage, -- STADE_VIE
		--id_nomenclature_sex, -- SEXE
 		-- id_nomenclature_obj_count, -- IND,
 		-- id_nomenclature_type_count, -- 'TYP_DENBR'
 		-- id_nomenclature_sensitivity, --SENSIBILITE
 		 -- id_nomenclature_observation_status, -- 'STATUT_OBS'
		-- id_nomenclature_blurring, -- DEE_FLOU
        -- id_nomenclature_behaviour, -- OCC_COMPORTEMENT
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
		s.altitude_min,
		s.altitude_max,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local as the_geom_local,
		v.date_min,
		v.date_max,
		--validator
		--validation_comment
		--determiner
		v.id_digitiser,
		--id_nomenclature_determination_method
		--meta_validation_date
		--meta_create_date,
		--meta_update_date,
		--last_action
		v.id_module,
		v.comments AS comment_context
    FROM visits v
    JOIN sites s USING (id_base_site)
	JOIN gn_commons.t_modules m USING (id_module)
	JOIN source
        ON TRUE
    WHERE m.module_code = :'module_code'
    ;

--SELECT * FROM gn_monitoring.v_synthese_:module_code