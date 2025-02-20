-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;


DROP VIEW  IF EXISTS  gn_monitoring.v_export_syrhetsyrphes;

CREATE OR REPLACE VIEW gn_monitoring.v_export_syrhetsyrphes AS

WITH  
 	sites AS (
         SELECT 
	 		tbs.id_base_site,
	 		tsg.id_sites_group,
            tsg.sites_group_name::text as site,
			tbs.base_site_code::text AS piege,
            tbs.altitude_min,
            tbs.altitude_max,
            tsc.data AS site_data,
            tbs.geom AS the_geom_4326,
            st_centroid(tbs.geom) AS the_geom_point,
            tbs.geom_local
	 	FROM gn_monitoring.t_base_sites tbs
	 	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	 	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	 	LEFT JOIN gn_commons.t_modules tm ON tm.id_module = tsc.id_module
	 	WHERE LOWER(tm.module_code) = 'syrhetsyrphes'
 	), 
	visits AS (
		SELECT 
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			tbv.id_base_site,
			tbv.id_dataset,
			tbv.id_digitiser,
			tr.nom_role || ' ' || tr.prenom_role AS numerisateur,
 			tbv.visit_date_min AS date_min,
			COALESCE(tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tvc.data AS visit_data,
			ds.unique_dataset_id AS uuid_jdd,
			ds.dataset_name AS jdd,
			af.unique_acquisition_framework_id as uuid_ca,
			af.acquisition_framework_name AS ca,
			tbv.id_nomenclature_tech_collect_campanule,
			tbv.id_nomenclature_grp_typ
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		LEFT JOIN gn_commons.t_modules tm ON tm.id_module = tbv.id_module
		LEFT JOIN utilisateurs.t_roles tr ON tbv.id_digitiser = tr.id_role
		LEFT JOIN gn_meta.t_datasets ds USING (id_dataset)
		LEFT JOIN gn_meta.t_acquisition_frameworks af USING (id_acquisition_framework)
		WHERE LOWER(tm.module_code) = 'syrhetsyrphes'
	), 
	observers AS (
		SELECT 
			array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
		FROM gn_monitoring.cor_visit_observer cvo
		JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
		GROUP BY cvo.id_base_visit
	)
 SELECT 
 	det.uuid_observation_detail AS unique_id_sinp,
    v.uuid_base_visit AS unique_id_sinp_grp,
	v.uuid_jdd,
	v.uuid_ca,
	v.ca,
	v.jdd,
	s.site,
	s.site_data ->> 'habitat' AS habitat,
	s.piege,
    s.altitude_min,
    s.altitude_max,
    v.date_min,
    v.date_max,
	obs.observers,
    v.numerisateur,
    det.data ->> 'determiner'::text AS determiner,
    o.cd_nom,
    t.nom_complet ,
	(det.data ->> 'count_min'::text)::integer AS count_min,
    (det.data ->> 'count_max'::text)::integer AS count_max,
    ref_nomenclatures.get_nomenclature_label((det.data ->> 'id_nomenclature_life_stage'::text)::integer) AS stade_vie,
    ref_nomenclatures.get_nomenclature_label((det.data ->> 'id_nomenclature_sex'::text)::integer) AS sexe,
    ref_nomenclatures.get_nomenclature_label((v.id_nomenclature_tech_collect_campanule)::integer) AS technique_collecte,
    ref_nomenclatures.get_nomenclature_label((v.id_nomenclature_grp_typ)::integer) AS type_regroupement,
    ref_nomenclatures.get_nomenclature_label((o_compl.data ->> 'id_nomenclature_obs_technique'::text)::integer) AS technique_observation,
    ref_nomenclatures.get_nomenclature_label((o_compl.data ->> 'id_nomenclature_determination_method')::integer) AS methode_determination,
	ST_AsText(s.geom_local) AS geom_wkt_2154,
    s.geom_local::GEOMETRY(POINT, 2154) AS geom_2154
FROM gn_monitoring.t_observation_details det
LEFT JOIN gn_monitoring.t_observations o USING (id_observation)
LEFT JOIN gn_monitoring.t_observation_complements o_compl USING (id_observation)
JOIN visits v ON v.id_base_visit = o.id_base_visit
JOIN sites s ON s.id_base_site = v.id_base_site
LEFT JOIN gn_monitoring.t_site_complements v_compl ON v_compl.id_base_site = v.id_base_site
JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
JOIN observers obs ON obs.id_base_visit = v.id_base_visit
ORDER BY 
	site,
	piege,
	date_min,
	nom_complet,
	stade_vie,
	sexe
;