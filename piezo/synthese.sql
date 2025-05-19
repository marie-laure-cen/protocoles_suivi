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
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
	),
	sites AS (
		SELECT
			tbs.id_base_site,
			tsg.sites_group_name as id_site,
     		tbs.base_site_code as piezo,
      		tbs.base_site_name as protocole,
			tbs.base_site_description as comments,
			tsc.data,
			tbs.base_site_description as site_comments,
			tbs.altitude_min,
			tbs.altitude_max,
			tbs.geom AS the_geom_4326,
			ST_CENTROID(tbs.geom) AS the_geom_point,
			tbs.geom_local as geom_local
        FROM gn_monitoring.t_base_sites tbs
        LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
        LEFT JOIN gn_monitoring.cor_site_module csm USING (id_base_site)
        LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
        JOIN source source_1 ON csm.id_module = source_1.id_module
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
		source.id_source,
		v.id_base_site,
		v.id_base_visit,
		v.uuid_base_visit AS unique_id_sinp_grp,
		-- piézomètres
		s.id_site,
		s.piezo,
		s.altitude_min,
		s.altitude_max,
		(s.comments || ' protocole : ' || s.protocole) as site_comments,
		-- sondages
		(tvc.data -> 'num_sondage') as num_sondage,
		extract(year from v.visit_date_min) as annee,
		v.visit_date_min,
		v.id_digitiser,
    	v.id_dataset,
		-- données additionnelles
		jsonb_strip_nulls(COALESCE(s.data || tvc.data , tvc.data, s.data)) as additional_data,
		-- géométries
		s.the_geom_4326,
		s.the_geom_point,
		s.geom_local
	FROM gn_monitoring.t_base_visits v
	LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
    JOIN sites s USING (id_base_site)
	JOIN gn_commons.t_modules m USING (id_module)
	JOIN source ON TRUE
	JOIN observers obs USING (id_base_visit)
    WHERE m.module_code = :'module_code'
;

SELECT * FROM gn_monitoring.v_synthese_:module_code
;