-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --rhomeoodonate standard------------------------------------------
-- View: gn_monitoring.v_export_rhomeoodonate_standard

DROP VIEW  IF EXISTS  gn_monitoring.v_export_syrhetflore_standard;

CREATE OR REPLACE VIEW gn_monitoring.v_export_syrhetflore_standard AS

WITH 
	srce AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1

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
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		LEFT JOIN gn_commons.t_modules m ON tsg.id_module = m.id_module
		WHERE m.module_code = :'module_code'
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
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
		o.id_observation as obs_id,
		v.id_base_site as releve_id,
		-- Piège
		s.sites_group_code as piege_code,
		s.sites_group_name as piege_nom,
		s.altitude_min as piege_altitude,
		-- Relevé
		ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('TYP_GRP', 'REL') AS releve_type, -- Relevé phytosociologique
        --ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('NAT_OBJ_GEO', 'In') AS geo_object_nature, -- Inventoriel
		ref_nomenclatures.get_nomenclature_label((s.data -> 'id_nomenclature_tech_collect_campanule')::integer) AS releve_tech_collect, 
		ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('STATUT_SOURCE', 'Te') AS releve_source, -- la source est le terrain
		v.date_min as releve_date,
		utilisateurs.get_name_by_id_role(v.id_digitiser) as releve_numerisateur,
		v.data -> 'aire' as releve_aire,
		v.data -> 'compl_aire' as releve_aire_compl,
		v.comments AS releve_commentaire,
		-- Observation
		oc.data -> 'strate' as obs_strate,
		o.cd_nom as obs_cd_nom,
		t.nom_complet AS obs_nom_cite,
		obs.observers as obs.observateurs,
		utilisateurs.get_name_by_id_role((oc.data->'determiner')::integer) as obs.determinateur,
		-- Dénombrement
 		ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('STATUT_OBS', 'Pr') AS obs_statut, -- le taxon est présent
		(CASE WHEN 
			(oc.data->'recouvrement')::integer = 0 THEN (oc.data->'recouvrement')::integer + (oc.data->'recouv_2')::integer
			ELSE (oc.data->'recouvrement')::integer
		END ) as obs_recouvrement,	
 		ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('OBJ_DENBR', 'SURF' ) AS obs_obj_denomb, -- l'objet du dénombrement est une surface
 		ref_nomenclatures.get_nomenclature_label_by_cdnom_mnemonique('TYP_DENBR', 'Es') AS obs_type_denomb, -- estimés
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_obs_technique')::integer) as obs_technique, -- METH_OBS
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_determination_method')::integer) AS obs_method_determ,
		o.comments AS obs_commentaire,
		-- Identifiants supplémentaires
		obs.ids_observers,
		srce.id_source,
		v.id_module,
		v.id_dataset,
		v.uuid_base_visit AS unique_id_sinp_grp,
		v.id_base_visit,
		o.uuid_observation AS unique_id_sinp,
		o.id_observation AS entity_source_pk_value,
		s.the_geom_4326,
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
	LEFT JOIN srce
        ON TRUE
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	WHERE m.module_code = :'module_code'
;