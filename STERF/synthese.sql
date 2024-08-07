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
			tbs.id_base_site,
			tsg.sites_group_code::integer as id_dataset,
			la.id_area as id_area_attachment,
			tsg.sites_group_name as area_code,
			(tbs.base_site_code || ' / ' || tbs.base_site_name ) as place_name,
			(r.nom_role || ' ' || r.prenom_role) as responsable,
			tsc.data,
			(tsc.data->'lisiere')::text as lisiere,
			(tsc.data->'hab_1'::text) as hab_1,
			(tsc.data->'hab_2')::text as hab_2,
			tbs.base_site_description as site_comments,
			tbs.altitude_min,
			tbs.altitude_max,
			tbs.geom AS the_geom_4326,
			ST_CENTROID(tbs.geom) AS the_geom_point,
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		LEFT JOIN utilisateurs.t_roles r ON (tsg.data->'id_resp' )::integer = id_role
		LEFT JOIN gn_meta.t_datasets taf ON taf.id_dataset = tsg.sites_group_code::integer
		--LEFT JOIN gn_meta.cor_acquisition_framework_site cafs USING (id_acquisition_framework)
		LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name = la.area_code
	),
	visits AS (
		SELECT    
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_digitiser,
			(tbv.visit_date_min::text || (tvc.data->'heure_debut')::text )::timestamp AS date_min,
			COALESCE (
				(tbv.visit_date_max::text || (tvc.data->'heure_fin')::text )::timestamp, 
				(tbv.visit_date_min::text || (tvc.data->'heure_fin')::text )::timestamp
			)::timestamp AS date_max,
			tbv.comments,
			tbv.id_nomenclature_tech_collect_campanule,
			tbv.id_nomenclature_grp_typ,
			tvc.data,
			(tvc.data->'num_passage')::integer as num_passage,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_tp')::integer) as temperature,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_cn')::integer) as couv_nuageuse,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_vt')::integer) as vent,
			(tvc.data->'source')::text as srce
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
		-- source ids
		v.id_module,
		o.uuid_observation AS unique_id_sinp, 
		v.uuid_base_visit AS unique_id_sinp_grp,
		source.id_source,
		o.id_observation AS entity_source_pk_value,
		v.id_base_site,
		v.id_base_visit,
		s.id_area_attachment,
		-- site and transect informations
		s.id_dataset,
		s.area_code as site_cen,
		s.place_name,
		s.responsable,
		s.altitude_min,
		s.altitude_max,
		-- visit informations
		v.num_passage,
		extract(year from v.date_min) as annee,
		v.date_min,
		v.date_max, 
		v.id_digitiser,
        ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature,
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'PASS') AS id_nomenclature_grp_typ,
		ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '59') AS id_nomenclature_tech_collect_campanule,
		-- observation informations
		(oc.data->'effectif')::integer as count_min,
		(oc.data->'effectif')::integer as count_max,
		o.cd_nom,
		t.nom_complet AS nom_cite,
		obs.observers,
		oc.data->'determiner' as determiner,
		(oc.data->'id_nomenclature_determination_method')::integer  as id_nomenclature_determination_method,
		(oc.data->'id_nomenclature_obs_technique')::integer  as id_nomenclature_obs_technique,
		(oc.data->'id_nomenclature_obj_count')::integer as id_nomenclature_obj_count,
		(oc.data->'id_nomenclature_type_count')::integer as id_nomenclature_type_count,
 		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, 
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
		--comments
		(s.site_comments || ' / ' || v.comments) AS comment_context,
		o.comments AS comment_description,
		-- additional data
		(CASE WHEN s.lisiere = 'Oui' THEN TRUE ELSE FALSE END) as lisiere,
		s.hab_1,
		s.hab_2,
		v.temperature,
		v.couv_nuageuse,
		v.vent,
		(oc.data->'nb_male') as nb_male,
		(oc.data->'nb_femelle') as nb_femelle,
		-- geometry
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local,
		jsonb_strip_nulls(COALESCE(s.data || v.data || oc.data , oc.data, v.data, s.data)) as additional_data
	FROM gn_monitoring.t_observations o
	LEFT JOIN gn_monitoring.t_observation_complements oc using (id_observation)
    JOIN visits v USING (id_base_visit)
    JOIN sites s USING (id_base_site)
	JOIN gn_commons.t_modules m USING (id_module)
	JOIN taxonomie.taxref t USING (cd_nom)
	JOIN source ON TRUE
	JOIN observers obs USING (id_base_visit)
    WHERE m.module_code = :'module_code' and not v.srce = 'Intranet SER'
;

SELECT * FROM gn_monitoring.v_synthese_:module_code