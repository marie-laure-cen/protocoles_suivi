-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --rhomeoodonate standard------------------------------------------
-- View: gn_monitoring.v_export_phyto

DROP VIEW  IF EXISTS  gn_monitoring.v_export_phyto

CREATE OR REPLACE VIEW gn_monitoring.v_export_phyto AS
WITH 
	srce AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_PHYTO' = sc.name_source
		WHERE sc.name_source = CONCAT('MONITORING_PHYTO')
	), 
	sites AS (
		SELECT
			tbs.id_base_site,
			(tsg.data ->> 'id_dataset')::integer AS id_dataset,
			tbs.base_site_code,
			tbs.base_site_name,
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
		INNER JOIN srce s ON tsc.id_module = s.id_module
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_dataset,
			tbv.id_digitiser,
			CONCAT(tr.nom_role, ' ', tr.prenom_role) AS rel_numerisateur,
			tbv.visit_date_min AS rel_date_min,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS rel_date_max,
			tbv.comments,
			tbv.id_nomenclature_tech_collect_campanule,
			tbv.id_nomenclature_grp_typ,
			tvc.data
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		LEFT JOIN utilisateurs.t_roles tr ON tbv.id_digitiser = tr.id_role
		INNER JOIN srce s ON tbv.id_module = s.id_module
	), 
	observers AS (
		SELECT
			array_agg(r.id_role) AS ids_observers,
			STRING_AGG(CONCAT(r.nom_role, ' ', r.prenom_role), ' ; ') AS observers,
			id_base_visit
		FROM gn_monitoring.cor_visit_observer cvo
		JOIN utilisateurs.t_roles r
		ON r.id_role = cvo.id_role
		GROUP BY id_base_visit
	)
	SELECT
		-- ID UNIQUE
		o.id_observation,
		-- RELEVES
		COALESCE(s.id_dataset, v.id_dataset) as jdd_id,
		td.dataset_name as jdd_nom,
		s.sites_group_name as site_nom,
		s.base_site_code as placette_code,
		s.base_site_name as placette_nom,
		v.rel_date_min,
		v.rel_date_max,
		v.rel_numerisateur,
		obs.observers as rel_observateurs,
		ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'REL') AS id_nomenclature_grp_typ, -- Relevé phytosociologique
		s.altitude_min,
		s.altitude_max,
		ref_nomenclatures.get_nomenclature_label((oc.data->'id_nomenclature_obs_technique')::integer) as rel_techn_collecte,
		v.data ->> 'surface',
		v.data ->> 'forme_releve',
		v.data ->> 'ecologie',
		v.data ->> 'synsysteme',
		v.data->>'gestion',
		v.data ->> 'recouv_tot',
		v.data ->> 'recouv_arbor_1',
		v.data ->> 'h_arbo_1',
		v.data ->> 'recouv_arbor_2',
		v.data ->> 'h_arbo_2',
		v.data ->> 'recouv_arbust_1',
		v.data ->> 'h_arbust_1',
		v.data ->> 'recouv_arbust_2',
		v.data ->> 'h_arbust_2',
		v.data ->> 'recouv_herb',
		v.data ->> 'h_herb',
		v.data ->> 'nb_st_herb',
		v.data ->> 'recouv_bryo',
		v.data ->> 'recouv_lich',
		v.data ->> 'recouv_alg',
		v.data ->> 'recouv_lit',
		v.data ->> 'h_crypto',
		v.comments AS rel_comment,
		-- OBSERVATIONS
		o.cd_nom as obs_cd_nom,
		tx.lb_nom as obs_nom,
		(oc.data->'determiner')::integer as obs_determinateur,
 		CASE 
			WHEN (oc.data ->> 'recouvrement')::integer = 0 OR (oc.data ->> 'recouvrement')::integer IS NULL 
			THEN 'Non observé'
			ELSE 'Présent'
		END AS obs_status, 
		-- DENOMBREMENTS
		oc.data ->> 'strate' as obs_strate,
		(oc.data ->> 'recouvrement')::integer as obs_recouvrement,
		oc.data ->> 'abondance' as obs_abondance,
		oc.data ->> 'sociabilite' as obs_sociabilite,
		oc.data ->> 'vitalite' as obs_vitalite,
		-- CHAMPS ADDITIONNELS
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		obs.ids_observers,
		srce.id_source,
		v.id_module,
		v.id_base_site,
		v.uuid_base_visit,
		v.id_base_visit,
		o.uuid_observation ,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local as the_geom_local
    FROM gn_monitoring.t_observations o 
	LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
    JOIN visits v ON v.id_base_visit = o.id_base_visit
    JOIN sites s ON s.id_base_site = v.id_base_site
	LEFT JOIN gn_commons.t_modules m ON m.id_module = v.id_module
	JOIN taxonomie.taxref tx ON tx.cd_nom = o.cd_nom
	INNER JOIN srce ON v.id_module = srce.id_module
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	LEFT JOIN gn_meta.t_datasets td ON COALESCE(s.id_dataset, v.id_dataset) = td.id_dataset
;