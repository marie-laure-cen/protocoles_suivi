-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --rhomeoodonate standard------------------------------------------
-- View: gn_monitoring.v_export_rhomeoodonate_standard

DROP VIEW  IF EXISTS  gn_monitoring.v_export_steli_standard;

CREATE OR REPLACE VIEW gn_monitoring.v_export_steli_standard AS

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
			taf.dataset_name,
			la.id_area as id_area_attachment,
			cafs.area_code,
			la.area_name,
			(tbs.base_site_code || ' / ' || tbs.base_site_name ) as transect,
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
		o.uuid_observation AS unique_id_sinp, 
		v.uuid_base_visit AS unique_id_sinp_grp,
		-- site informations
		s.area_code as id_site,
		s.area_name as nom_site,
		s.id_dataset,
		s.dataset_name,
		m.module_code as suivi,
		s.responsable,
		-- transect information
		s.transect,
		s.altitude_min,
		s.altitude_max,
		s.milieu_terrestre,
		s.milieu_aquatique,
		s.activite_humaine,
		s.type_rive,
		s.niveau_eau,
		s.eutrophisation,
		s.courant,
		s.vegetation,
		-- visit informations
		extract(year from v.date_min) as annee,
		v.num_passage,
		v.date_min,
		v.date_max, 
		v.id_digitiser,
		v.temperature,
		v.couv_nuageuse,
		v.vent,
		-- observation informations
		o.cd_nom,
		t.cd_ref,
		t.nom_complet,
		t.regne,
		t.phylum,
		t.classe,
		t.ordre,
		t.famille,
		(oc.data->'effectif')::integer as effectif,
		(oc.data->'nb_male')::integer as nb_male,
		(oc.data->'nb_femelle')::integer as nb_femelle,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ab')::integer)  as abondance,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_ir')::integer)  as indice_repro,
		obs.observers,
		oc.data->'determiner' as determiner,
		-- nomenclature
		'Stationnel' as geo_object_nature,
		ref_nomenclatures.get_nomenclature_label(v.id_nomenclature_grp_typ) as grp_typ,
		ref_nomenclatures.get_nomenclature_label(v.id_nomenclature_tech_collect_campanule) as tech_collect_campanule,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_determination_method')::integer ) as determination_method,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_obs_technique')::integer ) as obs_technique,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_obj_count')::integer) as obj_count,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_type_count')::integer) as _type_count,
 		'Présent' AS observation_status, 
		'Terrain' AS source_status,
		'Géoréférencement' AS info_geo_type,
		--comments
		(s.site_comments || ' / ' || v.comments) AS comment_context,
		o.comments AS comment_description,
		v.srce,
		-- geometry
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local
	FROM gn_monitoring.t_observations o
	LEFT JOIN gn_monitoring.t_observation_complements oc using (id_observation)
    JOIN visits v USING (id_base_visit)
    JOIN sites s USING (id_base_site)
	JOIN gn_commons.t_modules m USING (id_module)
	JOIN taxonomie.taxref t USING (cd_nom)
	JOIN source ON TRUE
	JOIN observers obs USING (id_base_visit)
    WHERE m.module_code = :'module_code'
	ORDER BY s.area_code, s.transect , extract(year from v.date_min), v.num_passage, o.cd_nom
    ;