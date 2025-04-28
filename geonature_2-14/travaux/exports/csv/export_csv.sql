--------------------------------------------------
-- Export des sites avec l'ensemble des travaux
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_trav;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_trav
	AS
	WITH 
	grp_sites AS (
		SELECT
			-- Fiche annuelle
			tsg.id_sites_group,
			tsg.sites_group_code,
			tsg.sites_group_name,
			tsg.data,
			-- Sites CEN
			CASE WHEN la.id_type = 12 THEN 'Catégorie 1'
			ELSE 'Catégorie 2'
			END as categorie_site,
			la.area_code,
			la.area_name,
			la.geom
		FROM gn_monitoring.t_sites_groups tsg
		LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_code = la.area_code
	),
	sites AS (
		SELECT
			-- Parcelle Travaux
			tbs.id_base_site,
			tsc.id_sites_group,
			tbs.base_site_name,
			tbs.base_site_description,
			tbs.id_inventor,
			tbs.id_digitiser,
			tbs.altitude_min,
			tbs.altitude_max,
			tsc.data,
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
			tbv.visit_date_min AS date_min,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tvc.data
			FROM gn_monitoring.t_base_visits tbv
			LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	)
	SELECT
		-- Module
		m.module_code as module_nom,
		d.dataset_name,
		-- Fiche site
		sg.area_code as site_cen_code,
		sg.area_name as site_cen_nom,
		sg.sites_group_code || '_' || (sg.data-> 'annee')::text as fiche_site_code,
		(sg.data-> 'annee')::integer as annee,
		-- Fiche travaux
		s.base_site_name as parcelle_nom,
		(s.data -> 'etat')::text as travaux_etat,
		ROUND(ST_Area(s.geom_local)) as parcelle_surf_m2,
		ROUND((ST_Area(s.geom_local)/10000)::numeric, 2) as parcelle_surf_ha,
		s.altitude_min,
		s.altitude_max,
		(s.data -> 'obj_principal')::text as parcelle_obj_previ,
		(s.data -> 'result')::text as parcelle_result_rea,
		(s.data -> 'reaj')::text as parcelle_reaj_rea,
		(s.data -> 'nb_jours')::integer as travaux_nb_jours,
		(s.data -> 'comment_bilan')::text as parcelle_bilan,
		s.base_site_description as parcelle_comments,
		-- Intervention travaux
		v.id_base_visit as travaux_id,
		v.date_min as travaux_debut,
		v.date_max as travaux_fin,
		CASE
		WHEN ((v.data -> 'intervenant')::text) = 'null'::text OR ((v.data -> 'intervenant')::text) IS NULL THEN NULL
        ELSE ref_nomenclatures.get_nomenclature_label((v.data -> 'intervenant')::integer)
        END as travaux_intervenant,
		(v.data -> 'type_travaux')::text as travaux_types,
		(v.data -> 'produits')::text as travaux_produits,
		(v.data -> 'materiel_travaux')::text as travaux_materiel,
		v.comments as travaux_comments,
		utilisateurs.get_name_by_id_role(s.id_digitiser) as numerisateur,
		-- Géométries
		sg.geom as site_cen_geom,
		s.geom_local as parcelle_geom,
		s.the_geom_point as parcelle_centroid
	FROM visits v
	LEFT JOIN sites s USING (id_base_site)
	LEFT JOIN grp_sites sg USING (id_sites_group)
	LEFT JOIN gn_commons.t_modules m USING (id_module)
	LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
	WHERE m.module_code = :'module_code'
	ORDER BY sites_group_code, (sg.data-> 'annee')::integer DESC, (v.data -> 'etat' ) DESC
;


GRANT SELECT ON TABLE gn_monitoring.v_qgis_syrhetheteroceres TO geonat_visu;
--------------------------------------------------
-- Export des sites avec les travaux de l'année n-1
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_trav_n1;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_trav_n1
	AS
	WITH 
	grp_sites AS (
		SELECT
			-- Fiche annuelle
			tsg.id_sites_group,
			tsg.sites_group_code,
			tsg.sites_group_name,
			tsg.data,
			-- Sites CEN
			CASE WHEN la.id_type = 12 THEN 'Catégorie 1'
			ELSE 'Catégorie 2'
			END as categorie_site,
			la.area_code,
			la.area_name,
			la.geom
		FROM gn_monitoring.t_sites_groups tsg
		LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_code = la.area_code
	),
	sites AS (
		SELECT
			-- Parcelle Travaux
			tbs.id_base_site,
			tsc.id_sites_group,
			tbs.base_site_name,
			tbs.base_site_description,
			tbs.id_inventor,
			tbs.id_digitiser,
			tbs.altitude_min,
			tbs.altitude_max,
			tsc.data,
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
			tbv.visit_date_min AS date_min,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
			tbv.comments,
			tvc.data
			FROM gn_monitoring.t_base_visits tbv
			LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	)
	SELECT
		-- Module
		m.module_code as module_nom,
		d.dataset_name,
		-- Fiche site
		sg.area_code as site_cen_code,
		sg.area_name as site_cen_nom,
		sg.sites_group_code || '_' || (sg.data-> 'annee')::text as fiche_site_code,
		(sg.data-> 'annee')::integer as annee,
		-- Fiche travaux
		s.base_site_name as parcelle_nom,
		(s.data -> 'etat')::text as travaux_etat,
		ROUND(ST_Area(s.geom_local)) as parcelle_surf_m2,
		ROUND((ST_Area(s.geom_local)/10000)::numeric, 2) as parcelle_surf_ha,
		s.altitude_min,
		s.altitude_max,
		(s.data -> 'obj_principal')::text as parcelle_obj_previ,
		(s.data -> 'result')::text as parcelle_result_rea,
		(s.data -> 'reaj')::text as parcelle_reaj_rea,
		(s.data -> 'nb_jours')::integer as travaux_nb_jours,
		(s.data -> 'comment_bilan')::text as parcelle_bilan,
		s.base_site_description as parcelle_comments,
		-- Intervention travaux
		v.id_base_visit as travaux_id,
		v.date_min as travaux_debut,
		v.date_max as travaux_fin,
		CASE
		WHEN ((v.data -> 'intervenant')::text) = 'null'::text OR ((v.data -> 'intervenant')::text) IS NULL THEN NULL
        ELSE ref_nomenclatures.get_nomenclature_label((v.data -> 'intervenant')::integer)
        END as travaux_intervenant,
		(v.data -> 'type_travaux')::text as travaux_types,
		(v.data -> 'produits')::text as travaux_produits,
		(v.data -> 'materiel_travaux')::text as travaux_materiel,
		v.comments as travaux_comments,
		utilisateurs.get_name_by_id_role(s.id_digitiser) as numerisateur,
		-- Géométries
		sg.geom as site_cen_geom,
		s.geom_local as parcelle_geom,
		s.the_geom_point as parcelle_centroid
	FROM visits v
	LEFT JOIN sites s USING (id_base_site)
	LEFT JOIN grp_sites sg USING (id_sites_group)
	LEFT JOIN gn_commons.t_modules m USING (id_module)
	LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
	WHERE m.module_code = :'module_code'
	AND v.annee = extract( year from now() ) - 1
	AND (sg.data-> 'annee')::integer = extract( year from now() ) - 1
	ORDER BY sites_group_code, (sg.data-> 'annee')::integer DESC, (v.data -> 'etat' ) DESC
;

GRANT SELECT ON TABLE gn_monitoring.v_export_travaux_trav_n1 TO geonat_visu;
;
--------------------------------------------------
-- Export des sites avec l'ensemble des travaux année n
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_trav_n;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_trav_n
	AS
	WITH 
	grp_sites AS (
		SELECT
			-- Fiche annuelle
			tsg.id_sites_group,
			tsg.sites_group_code,
			tsg.sites_group_name,
			tsg.data,
			-- Sites CEN
			CASE WHEN la.id_type = 12 THEN 'Catégorie 1'
			ELSE 'Catégorie 2'
			END as categorie_site,
			la.area_code,
			la.area_name,
			la.geom
		FROM gn_monitoring.t_sites_groups tsg
		LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_code = la.area_code
	),
	sites AS (
		SELECT
			-- Parcelle Travaux
			tbs.id_base_site,
			tsc.id_sites_group,
			tbs.base_site_name,
			tbs.base_site_description,
			tbs.id_inventor,
			tbs.id_digitiser,
			tbs.altitude_min,
			tbs.altitude_max,
			tsc.data,
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
			35 as id_module,
			tbv.id_base_site,
			min(tbv.id_dataset) as id_dataset,
			min(tbv.visit_date_min) AS date_min,
			max(COALESCE (tbv.visit_date_max, tbv.visit_date_min)) AS date_max,
			STRING_AGG(DISTINCT tbv.comments, ' / ') as comments,
			STRING_AGG( DISTINCT 
				('id_intervention: ' ||tbv.id_base_visit ||
					'/ date_debut: ' || tbv.visit_date_min::text ||
				'/ date_fin: ' || COALESCE (tbv.visit_date_max, tbv.visit_date_min)::text ||
				'/ intervenant: '|| (CASE 
									 WHEN ((tvc.data -> 'intervenant')::text) = 'null'::text 
									 OR ((tvc.data -> 'intervenant')::text) IS NULL 
									 THEN NULL
									 ELSE ref_nomenclatures.get_nomenclature_label((tvc.data -> 'intervenant')::integer)
									 END) ||
				' / type: '|| (tvc.data -> 'type_travaux')::text ||
				'/ produits: ' ||  (tvc.data -> 'produits')::text ||
				'/ matériel: ' || (tvc.data -> 'materiel_travaux')::text )::text , ', ') as intervention
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		GROUP BY tbv.id_base_site
	)
	SELECT
		-- Module
		m.module_code as module_nom,
		d.dataset_name,
		-- Fiche site
		sg.area_code as site_cen_code,
		sg.area_name as site_cen_nom,
		-- Fiche travaux
		sg.sites_group_code || '_' || (sg.data-> 'annee')::text as fiche_site_code,
		(sg.data-> 'annee')::integer as fiche_annee,
		(s.data -> 'etat')::text as fiche_etat,
		(s.data -> 'obj_principal')::text as fiche_obj_previ,
		(s.data -> 'result')::text as fiche_result_rea,
		(s.data -> 'reaj')::text as fiche_reaj_rea,
		(s.data -> 'nb_jours')::integer as fiche_nb_jours,
		(s.data -> 'comment_bilan')::text as fiche_bilan,
		s.base_site_description as fiche_comments,
		-- Parcelle travayx
		s.base_site_name as parcelle_nom,
		ROUND(ST_Area(s.geom_local)) as parcelle_surf_m2,
		ROUND((ST_Area(s.geom_local)/10000)::numeric, 2) as parcelle_surf_ha,
		s.altitude_min,
		s.altitude_max,
		-- Intervention travaux
		v.date_min as travaux_debut,
		v.date_max as travaux_fin,
		v.intervention,
		v.comments as travaux_comments,
		utilisateurs.get_name_by_id_role(s.id_digitiser) as numerisateur,
		-- Géométries
		sg.geom as site_cen_geom,
		s.geom_local as parcelle_geom,
		s.the_geom_point as parcelle_centroid
	FROM visits v
	LEFT JOIN sites s USING (id_base_site)
	LEFT JOIN grp_sites sg USING (id_sites_group)
	LEFT JOIN gn_commons.t_modules m USING (id_module)
	LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
	WHERE m.module_code = :'module_code'
	AND (sg.data-> 'annee')::integer = extract( year from now() )
	ORDER BY sites_group_code, (sg.data-> 'annee')::integer DESC, v.date_max DESC, (s.data -> 'etat' ) DESC
;

GRANT SELECT ON TABLE gn_monitoring.v_export_travaux_trav_n TO geonat_visu;

--------------------------------------------------
-- Export des interventions
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_interv;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_interv
	AS
	WITH
	sites AS (
		SELECT
			-- Parcelle Travaux
			tbs.id_base_site,
			tsc.id_sites_group,
			tbs.base_site_code,
			tbs.base_site_name,
			tbs.base_site_description,
			tbs.id_inventor,
			tbs.id_digitiser,
			tbs.altitude_min,
			tbs.altitude_max,
			tsc.data,
			tbs.geom,
			tbs.geom_local
			FROM gn_monitoring.t_base_sites tbs
			LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	), 
	visits AS (
		SELECT
			-- Intervention travaux
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_dataset as id_dataset,
			tbv.comments,
			tbv.id_base_visit as id_intervention,
			tbv.visit_date_min as date_debut,
			COALESCE (tbv.visit_date_max, tbv.visit_date_min)as date_fin,
			CASE 
				WHEN ((tvc.data -> 'intervenant')::text) = 'null'::text 
				OR ((tvc.data -> 'intervenant')::text) IS NULL 
				THEN NULL
				ELSE ref_nomenclatures.get_nomenclature_label((tvc.data -> 'intervenant')::integer)
			END as intervenant,
			(tvc.data -> 'type_travaux')::text as type_travaux,
			(tvc.data -> 'produits')::text as produits,
			(tvc.data -> 'materiel_travaux')::text  as materiel_travaux
		FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	)
	SELECT
		-- Module
		m.module_code as module_nom,
		d.dataset_name,
		-- Parcelle travaux
		s.id_base_site as parcelle_id,
		s.base_site_code as parcelle_code,
		s.base_site_name as parcelle_nom,
		(s.data -> 'etat'::text)::text AS etat_travaux,
		-- Intervention travaux
		v.date_debut as travaux_debut,
		v.date_fin as travaux_fin,
		v.type_travaux,
		v.produits,
		v.materiel_travaux,
		v.comments as travaux_comments,
		utilisateurs.get_name_by_id_role(s.id_digitiser) as numerisateur
	FROM visits v
	LEFT JOIN sites s USING (id_base_site)
	LEFT JOIN gn_commons.t_modules m USING (id_module)
	LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
	WHERE m.module_code = :'module_code'
	ORDER BY v.date_fin DESC, (s.data -> 'etat' ) DESC
;

GRANT SELECT ON TABLE gn_monitoring.v_export_travaux_interv TO geonat_visu;
;

--------------------------------------------------
-- Export des sites avec travaux
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_sites;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_sites
	AS
	WITH 
	grp_sites AS (
		SELECT
			-- Fiche annuelle
			tsg.sites_group_code,
			max((tsg.data-> 'annee')::integer) as fiche_date_max,
			min((tsg.data-> 'annee')::integer) as fiche_date_min
			-- Sites CEN
		FROM gn_monitoring.t_sites_groups tsg
		WHERE id_module = 35
		GROUP BY tsg.sites_group_code
	)
	SELECT
		-- Module
		'travaux' as module,
		-- Fiche site
		la.area_code as site_cen_code,
		la.area_name as site_cen_nom,
		CASE WHEN la.id_type = 12 THEN 'Catégorie 1'
		ELSE 'Catégorie 2'
		END as categorie_site,
		grp_sites.fiche_date_max,
		grp_sites.fiche_date_min,
		-- Géométries
		la.geom as site_cen_geom
	FROM grp_sites
	LEFT JOIN ref_geo.l_areas la ON grp_sites.sites_group_code = la.area_code
	WHERE not grp_sites.fiche_date_max IS NULL
	ORDER BY grp_sites.fiche_date_max, la.area_code
;
GRANT SELECT ON TABLE gn_monitoring.v_export_travaux_sites TO geonat_visu;

--------------------------------------------------
-- Export des parcelles de travaux
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_travaux_parc;
CREATE OR REPLACE VIEW gn_monitoring.v_export_travaux_parc
 AS
 WITH grp_sites AS (
         SELECT tsg.id_sites_group,
            tsg.sites_group_code,
            tsg.sites_group_name,
	 		tsg.id_module,
            tsg.data,
                CASE
                    WHEN la.id_type = 12 THEN 'Catégorie 1'::text
                    ELSE 'Catégorie 2'::text
                END AS categorie_site,
            la.area_code,
            la.area_name,
            la.geom
           FROM gn_monitoring.t_sites_groups tsg
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_code::text = la.area_code::text
        ), sites AS (
         SELECT
			tbs.id_base_site,
            tsc.id_sites_group,
			tbs.base_site_code,
            tbs.base_site_name,
            tbs.base_site_description,
            tbs.id_inventor,
            tbs.id_digitiser,
            tbs.altitude_min,
            tbs.altitude_max,
            tsc.data,
            tbs.geom AS the_geom_4326,
            st_centroid(tbs.geom) AS the_geom_point,
            tbs.geom_local
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
        )
 SELECT 
 	s.id_base_site as parcelle_id,
	m.module_code AS module_nom,
    sg.area_code AS site_cen_code,
    sg.area_name AS site_cen_nom,
    (sg.sites_group_code::text || '_'::text) || ((sg.data -> 'annee'::text)::text) AS fiche_site_code,
    (sg.data -> 'annee'::text)::integer AS fiche_annee,
    (s.data -> 'etat'::text)::text AS fiche_etat,
    (s.data -> 'obj_principal'::text)::text AS fiche_objectif,
    (s.data -> 'result'::text)::text AS fiche_result,
    (s.data -> 'reaj'::text)::text AS fiche_reajust,
    (s.data -> 'nb_jours'::text)::integer AS fiche_nb_jours,
    (s.data -> 'comment_bilan'::text)::text AS fiche_bilan,
    s.base_site_description AS fiche_comments,
	s.base_site_code AS parcelle_code,
    s.base_site_name AS parcelle_nom,
    round(st_area(s.geom_local)) AS parcelle_surf_m2,
    round((st_area(s.geom_local) / 10000::double precision)::numeric, 2) AS parcelle_surf_ha,
    s.altitude_min,
    s.altitude_max,
    utilisateurs.get_name_by_id_role(s.id_digitiser) AS numerisateur,
    sg.geom AS site_cen_geom,
    s.geom_local AS parcelle_geom,
    s.the_geom_point AS parcelle_centroid
   FROM sites s
     LEFT JOIN grp_sites sg USING (id_sites_group)
     LEFT JOIN gn_commons.t_modules m USING (id_module)
  WHERE m.module_code = :'module_code'
  ORDER BY sg.sites_group_code, ((sg.data -> 'annee'::text)::integer) DESC, (s.data -> 'etat'::text) DESC
;

GRANT SELECT ON TABLE gn_monitoring.v_export_travaux_parc TO geonat_visu;