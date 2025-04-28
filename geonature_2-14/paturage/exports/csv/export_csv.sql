DROP VIEW IF EXISTS gn_monitoring.v_export_bd_travaux_sites;

--------------------------------------------------
-- Export des sites avec l'ensembles des travaux
--------------------------------------------------

CREATE OR REPLACE VIEW gn_monitoring.v_export_bd_travaux_sites 
	AS 
		-- définition du module de la BD Travaux
		WITH module AS (
			SELECT
				*
			FROM
				gn_commons.t_modules tm
			WHERE
				module_code = 'paturage'
		),
		-- définition du jeu de données de la BD travaux
		default_dt AS (
			SELECT
				id_dataset
			FROM
				gn_meta.t_datasets td
			WHERE
				lower(td.dataset_name) LIKE 'travaux' 
		)
		SELECT
			-- groupe de sites = sites CEN rattachés aux parcelles de travaux
			tsg.sites_group_name as site_name,
			tsg.sites_group_code as site_code,
			tsg.sites_group_description as site_desc,
			-- sites = parcelles de pâturage
			tbs.base_site_name as parcelle_nom,
			tbs.base_site_code as parcelle_code,
			tbs.base_site_description as parcelle_desc,
			tsc.data ->> 'annee' AS parcelle_annee,
			tsc.data ->> 'obj_principal' AS parcelle_objectif,
			tsc.data ->> 'bilan' AS parcelle_bilan,
			tsc.data ->> 'reajust' AS parcelle_reajust,
			last_visit.visit_max,
			last_visit.visit_min,
			last_visit.nb_visit,
			COALESCE(
				id_dataset,
				(
					SELECT
						id_dataset
					FROM
						default_dt
				)
			) AS id_dataset, -- patch pour exporter les sites sans visites
			ST_AsText(ST_Transform(tbs.geom, 4326)) as geom_4326,
			ST_AsText(geom) as geom_2154
		FROM
			gn_monitoring.t_base_sites tbs
			JOIN gn_monitoring.t_site_complements tsc ON tbs.id_base_site = tsc.id_base_site
			JOIN MODULE m ON m.id_module = tsc.id_module
			JOIN gn_monitoring.t_sites_groups tsg ON tsg.id_sites_group = tsc.id_sites_group
			JOIN LATERAL (
				SELECT
					id_dataset,
					max(visit_date_min) AS visit_max,
					min(visit_date_min) AS visit_min,
					count(tbv.id_base_visit) AS nb_visit,
					string_agg(
						DISTINCT concat (UPPER(tr.nom_role), ' ', tr.prenom_role),
						', '
						ORDER BY
							concat (UPPER(tr.nom_role), ' ', tr.prenom_role)
					) AS observers
				FROM
					gn_monitoring.t_base_visits tbv
					JOIN gn_monitoring.cor_visit_observer cvo ON cvo.id_base_visit = tbv.id_base_visit
					JOIN utilisateurs.t_roles tr ON tr.id_role = cvo.id_role
				WHERE
					tbv.id_base_site = tbs.id_base_site
				GROUP BY
					tbv.id_base_site,
					id_dataset
			) last_visit ON TRUE;



--------------------------------------------------
-- Fiche travaux
--------------------------------------------------
DROP VIEW IF EXISTS gn_monitoring.v_export_bd_travaux_fiche;

CREATE OR REPLACE VIEW gn_monitoring.v_export_bd_travaux_fiche 
	AS 
		-- définition du module de la BD Travaux
		WITH module AS (
			SELECT
				*
			FROM
				gn_commons.t_modules tm
			WHERE
				module_code = 'bd_travaux'
		),
		-- définition du jeu de données de la BD travaux
		default_dt AS (
			SELECT
				id_dataset
			FROM
				gn_meta.t_datasets td
			WHERE
				lower(td.dataset_name) LIKE 'travaux' 
		)
		SELECT
			-- Site du CEN
			tsg.sites_group_name as site_name,
			tsg.sites_group_code as site_code,
			tsg.sites_group_description as site_desc,
			-- Parcelle travaux
			tbs.base_site_name as parcelle_nom,
			tbs.base_site_code as parcelle_code,
			tbs.base_site_description as parcelle_desc,
			tsc.data ->> 'annee' AS parcelle_annee,
			-- Fiche travaux
			tbv.data ->> 'etat' AS fiche_etat,
			tvc.data ->> 'nb_jours' as fiche_nb_j_tot,
			tbv.visit_date_min as fiche_date_debut,
			tbv.visit_date_max as fiche_date_fin,
			obs.observers as fiche_numerisateur,
			tbv.comments as fiche_comment,
			tvc.data ->> 'intervenant' as fiche_intervenant,
			tvc.data ->> 'produits' as fiche_produits,
			tvc.data ->> 'trav_arb' as t_arb_typ,
			tvc.data ->> 'nb_j_arb' as t_arb_j,
			tvc.data ->> 'date_min_arb' as t_arb_min,
			tvc.data ->> 'date_max_arb' as t_arb_max,
			tvc.data ->> 'trav_herb' as t_herb_typ,
			tvc.data ->> 'nb_j_herb' as t_herb_j,
			tvc.data ->> 'date_min_herb' as t_herb_min,
			tvc.data ->> 'date_max_herb' as t_herb_max,
			tvc.data ->> 'trav_am' as t_am_typ,
			tvc.data ->> 'nb_j_am' as t_am_j,
			tvc.data ->> 'date_min_am' as t_am_min,
			tvc.data ->> 'date_max_am' as t_am_max,
			tvc.data ->> 'trav_eau' as t_eau_typ,
			tvc.data ->> 'nb_j_eau' as t_eau_j,
			tvc.data ->> 'date_min_eau' as t_eau_min,
			tvc.data ->> 'date_max_eau' as t_eau_max,
			tvc.data ->> 'trav_autre' as t_autre_typ,
			tvc.data ->> 'nb_j_autre' as t_autre_j,
			tvc.data ->> 'date_min_autre' as t_autre_min,
			tvc.data ->> 'date_max_autre' as t_autre_max,
			tvb.data ->> 'materiel_travaux' as t_materiel,
			-- patch pour exporter les sites sans visites
			COALESCE(
				tbv.id_dataset,
				(SELECT id_dataset FROM default_dt)
			) AS id_dataset,
			ST_AsText(tbs.geom) as geom_2154, 
			ST_AsText(ST_Transform(tbs.geom, 4326)) as geom_4326, 
		FROM gn_monitoring.t_base_visits tbv
			LEFT JOIN gn_monitoring.t_visit_complements tvs
			LEFT JOIN gn_monitoring.t_base_sites tbs ON tbs.id_base_site = tbv.id_base_site
			LEFT JOIN gn_monitoring.t_site_complements tsc ON tbs.id_base_site = tsc.id_base_site
			LEFT JOIN MODULE m ON m.id_module = tsc.id_module
			LEFT JOIN gn_monitoring.t_sites_groups tsg ON tsg.id_sites_group = tsc.id_sites_group
			LEFT JOIN ( 
				SELECT 
					cvo.id_base_visit,
					array_agg(r.id_role) AS ids_observers,
					string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers
				FROM gn_monitoring.cor_visit_observer cvo
				JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
				GROUP BY cvo.id_base_visit) obs ON obs.id_base_visit = tbv.id_base_visit
		WHERE m.module_code = 'bd_travaux'
		ORDER BY tsg.sites_group_name, tbv.base_site_name, tbv.id_base_visit
;