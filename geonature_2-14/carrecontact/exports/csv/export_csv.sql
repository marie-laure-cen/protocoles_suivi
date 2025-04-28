------------------------------------------------- EXPORT DES OBSERVATIONS AVEC VALEURS ENVIRONNEMENTALES ------------------------------------------
--View: gn_monitoring.v_export_carrecontact_obs

DROP VIEW  IF EXISTS  gn_monitoring.v_export_carrecontact_obs ;

CREATE OR REPLACE VIEW gn_monitoring.v_export_carrecontact_obs AS 
	WITH 
	srce AS (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = 'MONITORING_CARRECONTACT'
	),
	dpt as (
		SELECT
			area_code::integer as dep,
			geom
		FROM ref_geo.l_areas WHERE id_type = 26
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
			dpt.dep,
			tsc.data,
			ST_CENTROID(tbs.geom) AS geom
        FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		LEFT JOIN dpt ON ST_INTERSECTS(tbs.geom_local, dpt.geom)
		INNER JOIN srce s ON tsc.id_module = s.id_module
	), 
	visits AS (
		SELECT
			tbv.id_base_visit,
			tbv.uuid_base_visit,
			tbv.id_module,
			tbv.id_base_site,
			tbv.id_digitiser,
			CONCAT(tr.nom_role, ' ', tr.prenom_role) AS numerisateur,
			tbv.visit_date_min,
			tbv.comments,
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
	),
	ta as (
		SELECT
			cd_ref,
			STRING_AGG(CASE WHEN id_attribut = 37 THEN valeur_attribut ELSE NULL END, ', ') as classe_etea,
			STRING_AGG(CASE WHEN id_attribut = 61 THEN valeur_attribut ELSE NULL END, ', ') as dynamique,
			STRING_AGG(CASE WHEN id_attribut = 62 THEN valeur_attribut ELSE NULL END, ', ') as ecologie,
			STRING_AGG(CASE WHEN id_attribut = 60 THEN valeur_attribut ELSE NULL END, ', ') as humidite,
			STRING_AGG(CASE WHEN id_attribut = 63 THEN valeur_attribut ELSE NULL END, ', ') as granulometrie,
			STRING_AGG(CASE WHEN id_attribut = 64 THEN valeur_attribut ELSE NULL END, ', ') as nutriment,
			STRING_AGG(CASE WHEN id_attribut = 65 THEN valeur_attribut ELSE NULL END, ', ') as reaction,
			STRING_AGG(CASE WHEN id_attribut = 66 THEN valeur_attribut ELSE NULL END, ', ') as salinite,
			STRING_AGG(CASE WHEN id_attribut = 67 THEN valeur_attribut ELSE NULL END, ', ') as luminosite
		FROM taxonomie.cor_taxon_attribut
		WHERE id_attribut in (37, 60,61,62,63,64,65,66,67,68)
		GROUP BY 
			cd_ref
	),
	tx as (
		SELECT
			*
		FROM taxonomie.taxref
		LEFT JOIN ta USING (cd_ref)
		WHERE regne = 'Plantae'
	)
	SELECT
		-- ID UNIQUE
		o.id_observation,
		-- SITE ET PLACETTE
		s.dep,
		s.sites_group_code as id_site,
		s.sites_group_name as nom_site,
		s.base_site_code as placette,
		s.altitude_min as altitude,
		-- RELEVES
		v.visit_date_min as date_obs,
		obs.observers as observateurs,
		v.data ->> 'taux_recouvrement' as taux_recouvrement,
		v.data ->> 'hauteur_vegetation' as hauteur_vegetation,
		v.data ->> 'strate_bryo' as strate_bryolichenique,
		v.comments AS commentaire_releve,
		-- OBSERVATIONS
		o.cd_nom as cd_nom,
		tx.lb_nom as nom_taxon,
		tx.id_rang as rang_taxon,
		o.comments as commentaire_observation,
		tx.classe_etea,
		tx.dynamique,
		tx.ecologie,
		tx.humidite,
		tx.granulometrie,
		tx.nutriment,
		tx.reaction,
		tx.salinite,
		tx.luminosite,
 		-- CHAMPS ADDITIONNELS
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		v.numerisateur,
		oc.data ->> 'id_sh_mysql' as id_sh_mysql,
		o.uuid_observation ,
		s.geom
    FROM gn_monitoring.t_observations o 
	LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
	LEFT JOIN tx USING(cd_nom)
    JOIN visits v ON v.id_base_visit = o.id_base_visit
    JOIN sites s ON s.id_base_site = v.id_base_site
	INNER JOIN srce ON v.id_module = srce.id_module
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	ORDER BY visit_date_min DESC
;

GRANT SELECT ON TABLE gn_monitoring.v_export_carrecontact_obs TO geonat_visu;