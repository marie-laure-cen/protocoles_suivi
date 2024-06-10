
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
	WITH 
	sites AS (
    	SELECT
			sg.id_sites_group,
			sg.sites_group_name as site_nom,
			la.area_code as site_code,
			s.id_base_site,
			s.base_site_name as fiche_nom,
			s.id_inventor as fiche_responsable,
			s.id_digitiser as fiche_numerisateur,
			s.base_site_description as fiche_comments,
			(tsg.data->'annee') as fiche_annee,
			(tsg.data->'etat') as fiche_etat,
			(tsg.data->'objectif') as fiche_obj,
			(tsg.data->'bilan') as fiche_bilan,
			(tsg.data->'reajust') as fiche_reaj,
			altitude_min,
			altitude_max,
			s.geom AS the_geom_4326,
			ST_CENTROID(s.geom) AS the_geom_point,
			s.geom_local as geom_local
        FROM gn_monitoring.t_base_sites s
		LEFT JOIN gn_monitoring.t_site_complements tsg USING (id_base_site)
		LEFT JOIN gn_monitoring.t_sites_groups sg USING (id_sites_group)
		LEFT JOIN ref_geo.l_areas la ON sg.sites_group_name = la.area_name
	), visits AS (
		SELECT
			v.id_base_visit,
			v.id_base_site,
			v.id_dataset,
			(vc.data->'nom') as action_nom,
			(vc.data->'objectif') as action_objectif,
			v.visit_date_min,
			v.visit_date_max,
			(vc.data->'nb_jours') as action_nb_jours,
			(vc.data->'objet') as action_objet,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%aquatique%' THEN (vc.data->'tvx_aqua')::text
				ELSE 'Pas de travaux'
			END as tvx_aqua,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Tourbière%' THEN (vc.data->'tvx_tourb')::text
				ELSE 'Pas de travaux'
			END as tvx_tourb,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Prairie%' 
				THEN (vc.data->'type_prairie')::text || ' / '|| (vc.data->'tvx_prairie')::text
				ELSE 'Pas de travaux'
			END as tvx_prai,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Lande%' 
				THEN (vc.data->'type_lande')::text || ' / '|| (vc.data->'tvx_lande')::text
				ELSE 'Pas de travaux'
			END as tvx_arb,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Bois%' THEN (vc.data->'tvx_bois')::text
				ELSE 'Pas de travaux'
			END as tvx_bois,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Aménagement%' 
				THEN (vc.data->'type_am')::text || ' / '|| (vc.data->'tvx_am')::text
				ELSE 'Pas de travaux'
			END as tvx_amenagemt,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%ordures%' THEN TRUE
				ELSE FALSE
			END as ram_ordure,
			CASE 
				WHEN (vc.data->'objet')::text LIKE '%Autre%' THEN  (vc.data->'tvx_autre')::text
				ELSE 'Pas de travaux'
			END as tvx_autre,
			(vc.data->'produit') as action_produit,
			(vc.data->'materiel') as action_materiel,
			v.comments,
			v.id_module,
			v.id_digitiser
		FROM gn_monitoring.t_base_visits v
		LEFT JOIN gn_monitoring.t_visit_complements vc USING (id_base_visit)
	), observers AS (
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
		v.id_dataset,
		s.site_nom,
		s.site_code,
		s.fiche_nom,
		s.fiche_responsable,
		s.fiche_numerisateur,
		s.fiche_annee,
		s.fiche_etat,
		s.fiche_obj,
		s.fiche_bilan,
		s.fiche_reaj,
		s.fiche_comments,
		v.action_nom,
		v.action_objectif,
		v.action_objet,
		v.visit_date_min AS date_min,
	    COALESCE (v.visit_date_max, v.visit_date_min) AS date_max,
		v.action_nb_jours,
		obs.observers as intervenant,
		v.comments,
		v.tvx_aqua,
		v.tvx_tourb,
		v.tvx_prai,
		v.tvx_arb,
		v.tvx_bois,
		v.tvx_autre,
		v.ram_ordure,
		v.action_produit,
		v.action_materiel,
		obs.ids_observers,
		s.altitude_min,
		s.altitude_max,
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local as the_geom_local,
		v.id_digitiser as numerisateur,
		v.id_base_site,
		v.id_base_visit,
		v.id_module
    FROM visits v
    JOIN sites s USING (id_base_site)
	LEFT JOIN gn_commons.t_modules m
        ON m.id_module = v.id_module
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	WHERE m.module_code = :'module_code'
;
