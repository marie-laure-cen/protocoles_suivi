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
			cafs.area_code,
			(tbs.base_site_code || ' / ' || tbs.base_site_name ) as place_name,
			(r.nom_role || ' ' || r.prenom_role) as responsable,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_mt')::integer) as milieu_terrestre,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_ma')::integer) as milieu_aquatique,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_ah')::integer) as activite_humaine,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_mt')::integer) as type_rive,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_ne')::integer) as niveau_eau,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_eu')::integer) as eutrophisation,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_co')::integer) as courant,
			ref_nomenclatures.get_nomenclature_label((tsc.data->'id_nomenclature_va')::integer) as vegetation,
			tbs.base_site_description as site_comments,
			tbs.altitude_min,
			tbs.altitude_max,
			tbs.geom AS the_geom_4326,
			ST_CENTROID(tbs.geom) AS the_geom_point,
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		LEFT JOIN utilisateurs.t_roles r ON (tsc.data->'id_resp' )::integer = id_role
		LEFT JOIN gn_meta.t_datasets taf ON taf.id_dataset = tsg.sites_group_code::integer
		LEFT JOIN gn_meta.cor_acquisition_framework_site cafs USING (id_acquisition_framework)
		LEFT JOIN ref_geo.l_areas la USING (area_code)
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
			(tvc.data->'num_passage') as num_passage,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_tp')::integer) as temperature,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_cn')::integer) as couv_nuageuse,
			ref_nomenclatures.get_nomenclature_label((tvc.data->'id_nomenclature_vt')::integer) as vent
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
		v.id_nomenclature_grp_typ, -- TYP_GRP
		v.id_nomenclature_tech_collect_campanule, --TECHNIQUE_OBS
		-- observation informations
		(oc.data->'effectif') as count_min,
		(oc.data->'effectif') as count_max,
		o.cd_nom,
		t.nom_complet AS nom_cite,
		obs.observers,
		oc.data->'determiner' as determiner,
		(oc.data->'id_nomenclature_determination_method')  as id_nomenclature_determination_method,
		(oc.data->'id_nomenclature_obs_technique')  as id_nomenclature_obs_technique,
		(oc.data->'id_nomenclature_obj_count') as id_nomenclature_obj_count,
		(oc.data->'id_nomenclature_type_count') as id_nomenclature_type_count,
 		ref_nomenclatures.get_id_nomenclature('STATUT_OBS', 'Pr') AS id_nomenclature_observation_status, 
		ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
		ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
		--comments
		(s.site_comments || ' / ' || v.comments) AS comment_context,
		o.comments AS comment_description,
		-- additional data
		s.milieu_terrestre,
		s.milieu_aquatique,
		s.activite_humaine,
		s.type_rive,
		s.niveau_eau,
		s.eutrophisation,
		s.courant,
		s.vegetation,
		v.temperature,
		v.couv_nuageuse,
		v.vent,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ab')::integer)  as abondance,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ir')::integer)  as indice_repro,
		(oc.data->'nb_male') as nb_male,
		(oc.data->'nb_femelle') as nb_femelle,
		
		-- geometry
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local,
		jsonb_build_object(
			'milieu_terrestre', s.milieu_terrestre,
			'milieu_aquatique', s.milieu_aquatique,
			'activite_humaine', s.activite_humaine,
			'type_rive', s.type_rive,
			'niveau_eau', s.niveau_eau,
			'eutrophisation', s.eutrophisation,
			'courant', s.courant,
			'vegetation', s.vegetation,
			'num_passage', v.num_passage,
			'temperature', v.temperature,
			'couv_nuageuse', v.couv_nuageuse,
			'vent', v.vent,
			'abondance', ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ab')::integer),
			'indice_repro', ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ir')::integer),
			'nb_male', (oc.data->'nb_male'),
			'nb_femelle', (oc.data->'nb_femelle')
		) as additional_data
	FROM gn_monitoring.t_observations o
	LEFT JOIN gn_monitoring.t_observation_complements oc using (id_observation)
    JOIN visits v USING (id_base_visit)
    JOIN sites s USING (id_base_site)
	JOIN gn_commons.t_modules m USING (id_module)
	JOIN taxonomie.taxref t USING (cd_nom)
	JOIN source ON TRUE
	JOIN observers obs USING (id_base_visit)
    WHERE m.module_code = :'module_code'
;

SELECT * FROM gn_monitoring.v_synthese_:module_code