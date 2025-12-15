-------------------------------------------------
-- Export des tourbières ------------------------
-------------------------------------------------

DROP VIEW  IF EXISTS  gn_monitoring.v_export_prat_sondage_tourbieres;

CREATE OR REPLACE VIEW gn_monitoring.v_export_prat_sondage_tourbieres AS
	SELECT
		tbs.id_base_site,
		taf.id_dataset,
		tsg.sites_group_name as area_code,
		(r.nom_role || ' ' || r.prenom_role) as responsable,
		tbs.base_site_code as transect_code,
		tbs.base_site_name  as transect_name,
		tbs.altitude_min,
		tbs.altitude_max,
		tbs.geom_local as geom,
		ST_CENTROID(tbs.geom) AS centroid,
		St_AsText(tbs.geom) AS geom_wkt
	FROM gn_monitoring.t_base_sites tbs
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	LEFT JOIN gn_monitoring.cor_site_module csm USING(id_base_site)
	LEFT JOIN gn_commons.t_modules mo ON mo.id_module = csm.id_module
	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	LEFT JOIN utilisateurs.t_roles r ON (tsg.data->'id_resp' )::integer = id_role
	LEFT JOIN gn_meta.t_datasets taf ON taf.id_dataset = (tsg.data ->> 'id_dataset')::integer
	LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name = la.area_code
	WHERE lower(mo.module_code) = 'sterf'
	ORDER BY area_code, transect_name
;

-------------------------------------------------
-- Export de l'ensemble des sondages ------------
-------------------------------------------------

DROP VIEW IF EXISTS gn_monitoring.v_export_prat_sondage_releves;

CREATE OR REPLACE VIEW gn_monitoring.v_export_prat_sondage_releves
 AS
 	WITH 
 		patri_hn AS (
			SELECT 
				cor_taxon_attribut.valeur_attribut,
            	cor_taxon_attribut.cd_ref
			FROM taxonomie.cor_taxon_attribut
			WHERE cor_taxon_attribut.id_attribut = 7
        ),
		milieux AS (
			SELECT 
				cor_taxon_attribut.cd_ref,
				cor_taxon_attribut.valeur_attribut AS id_milieu_det,
				CASE
                    WHEN cor_taxon_attribut.valeur_attribut IN ('II.a', 'II.b') THEN 'II'
                    WHEN cor_taxon_attribut.valeur_attribut IN ('V.a', 'V.b', 'V.c') THEN 'V'
                    ELSE cor_taxon_attribut.valeur_attribut
                END AS id_milieu,
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I' THEN 'ubiquistes'
                    WHEN cor_taxon_attribut.valeur_attribut = 'II.a' THEN 'boisements hygrophiles'
                    WHEN cor_taxon_attribut.valeur_attribut = 'II.b' THEN 'boisements mésophiles'
                    WHEN cor_taxon_attribut.valeur_attribut = 'III' THEN 'zones humides'
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV' THEN 'prairies mésophiles'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.a' THEN 'ourlets thermophiles'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.b' THEN 'pelouses rases'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.c' THEN 'prairies sèches'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI' THEN 'migratrices'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VII' THEN 'landes'
                    ELSE NULL
                END AS milieu_det, 
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I' THEN '#d9d9d9'
                    WHEN cor_taxon_attribut.valeur_attribut = 'II.a' THEN '#548235'
                    WHEN cor_taxon_attribut.valeur_attribut = 'II.b' THEN '#8eb55e'
                    WHEN cor_taxon_attribut.valeur_attribut = 'III' THEN '#9bc2e6'
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV' THEN '#e2efda'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.a' THEN '#e5ff52'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.b' THEN '#b9ff0b'
                    WHEN cor_taxon_attribut.valeur_attribut = 'V.c' THEN '#ffff00'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI' THEN '#ccccff'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VII' THEN '#d100ff'
                    ELSE NULL
                END AS couleur_det,
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I' THEN 'ubiquistes'
                    WHEN cor_taxon_attribut.valeur_attribut IN ('II.a', 'II.b') THEN 'boisements'
                    WHEN cor_taxon_attribut.valeur_attribut = 'III' THEN 'zones humides'
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV' THEN 'prairies mésophiles'
                    WHEN cor_taxon_attribut.valeur_attribut IN ('V.a', 'V.b', 'V.c') THEN 'milieux secs'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI' THEN 'migratrices'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VII' THEN 'landes'
                    ELSE NULL
                END AS milieu,
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I' THEN '#d9d9d9'
                    WHEN cor_taxon_attribut.valeur_attribut IN ('II.a', 'II.b') THEN '#548235'
                    WHEN cor_taxon_attribut.valeur_attribut = 'III' THEN '#9bc2e6'
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV' THEN '#e2efda'
                    WHEN cor_taxon_attribut.valeur_attribut IN ('V.a', 'V.b', 'V.c') THEN '#ffc000'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI' THEN '#ccccff'
                    WHEN cor_taxon_attribut.valeur_attribut = 'VII' THEN '#d100ff'
                    ELSE NULL
                END AS couleur
          FROM taxonomie.cor_taxon_attribut
          WHERE cor_taxon_attribut.id_attribut = 43
        ), 
		tr AS (
			SELECT 
				tbs.id_base_site,
            	tsg.sites_group_name AS site_code,
            	tsg.sites_group_description AS site_name,
				tsg.data ->> 'commune'::text AS site_com,
				la.area_name,
				tbs.base_site_name AS transect_name,
				tbs.altitude_min,
				tbs.altitude_max,
				tbs.geom_local AS geom,
				st_centroid(tbs.geom) AS centroid,
				st_astext(tbs.geom) AS geom_wkt
			FROM gn_monitoring.t_base_sites tbs
			LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
			LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
			LEFT JOIN gn_monitoring.cor_site_module csm USING(id_base_site)
			LEFT JOIN gn_commons.t_modules mo ON mo.id_module = csm.id_module
			LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
			WHERE mo.module_code::text = 'sterf'::text
			ORDER BY tsg.sites_group_name, tbs.base_site_name
		), 
		pass AS (
			SELECT 
				tbv.id_base_visit,
				tbv.id_base_site,
				tbv.visit_date_min AS pass_date,
				tvc.data
			FROM gn_monitoring.t_base_visits tbv
			LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
			LEFT JOIN gn_commons.t_modules tm ON tm.id_module = tbv.id_module
          WHERE tm.module_code::text = 'sterf'::text
        ), 
		obs AS (
			SELECT 
				o.id_observation,
				o.id_base_visit,
				o.cd_nom,
				tx.nom_valide,
				tx.nom_vern,
				tx.id_rang,
				o.comments,
				toc.data,
				mil.cd_ref,
				mil.id_milieu_det,
				mil.milieu_det,
				mil.couleur_det,
				mil.id_milieu,
				mil.milieu,
				mil.couleur,
				patri.valeur_attribut AS patrimonialite
			FROM gn_monitoring.t_observations o
			LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
			LEFT JOIN taxonomie.taxref tx USING (cd_nom)
			LEFT JOIN milieux mil USING (cd_ref)
			LEFT JOIN patri_hn patri USING (cd_ref)
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
		obs.id_observation,
		tr.site_code,
		tr.site_name,
		tr.site_com,
		tr.transect_name,
		(pass.data ->> 'annee')::integer AS pass_annee,
		(pass.data ->> 'num_passage')::integer AS pass_num,
		pass.pass_date,
		pass.data ->> 'heure_debut' AS pass_heure,
		observers.observers AS observateurs,
		(pass.data ->> 'occ_sol') AS pass_os1,
		(pass.data ->> 'occ_sol_detail') AS pass_os2,
		(pass.data ->> 'hab_1') AS pass_hab1,
		(pass.data ->> 'hab_2') AS pass_hab2,
		ref_nomenclatures.get_nomenclature_label((pass.data ->> 'id_nomenclature_tp')::integer, 'fr'::character varying) AS temperature,
		ref_nomenclatures.get_nomenclature_label((pass.data ->> 'id_nomenclature_cn')::integer, 'fr'::character varying) AS couv_nuageuse,
		ref_nomenclatures.get_nomenclature_label((pass.data ->> 'id_nomenclature_vt')::integer, 'fr'::character varying) AS vent,
		obs.cd_nom,
		obs.nom_valide,
		obs.nom_vern,
		obs.id_rang,
		obs.id_milieu,
		obs.milieu,
		obs.id_milieu_det,
		obs.milieu_det,
		obs.patrimonialite,
		(obs.data ->> 'effectif')::integer AS effectif_total,
		CASE
			WHEN (obs.data ->> 'nb_male') IS NULL THEN NULL::integer
			ELSE (obs.data ->> 'nb_male')::integer
		END AS nb_male,
		CASE
			WHEN (obs.data ->> 'nb_femelle') IS NULL THEN NULL::integer
			ELSE (obs.data ->> 'nb_femelle')::integer
		END AS nb_femelle,
		obs.comments AS commentaire,
		obs.couleur,
		obs.couleur_det,
		tr.id_base_site,
		pass.id_base_visit,
		pass.data ->> 'source' AS source_donnee,
		obs.data ->> 'id_obs_mysql' AS id_obs_mysql,
		tr.altitude_min,
		tr.altitude_max,
		tr.geom,
		tr.centroid,
		tr.geom_wkt
	FROM obs
	LEFT JOIN observers USING (id_base_visit)
	JOIN pass USING (id_base_visit)
	LEFT JOIN tr USING (id_base_site)
	ORDER BY 
		tr.site_code, 
		tr.transect_name, 
		((pass.data ->> 'annee')::integer) DESC, 
		((pass.data ->> 'num_passage')::integer) DESC, 
		obs.nom_valide
;