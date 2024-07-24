-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --rhomeoodonate standard------------------------------------------
-- View: gn_monitoring.v_export_rhomeoodonate_standard

DROP VIEW  IF EXISTS  gn_monitoring.v_export_syrhetflore_standard;

CREATE OR REPLACE VIEW gn_monitoring.v_export_syrhetflore_standard AS

WITH 
	com as(
		SELECT
			id_base_site,
			area_code,
			area_name
		FROM gn_monitoring.cor_site_area
		LEFT JOIN ref_geo.l_areas USING (id_area)
		WHERE id_type = 25
	),
	site as (
		SELECT
			*
		FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEfT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
		LEFT JOIN gn_commons.t_modules tm ON tsc.id_module = tm.id_module
		WHERE tm.module_code = 'syrhetflore'
),
visit as (
	SELECT
		*
	FROM gn_monitoring.t_base_visits tbv
	LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
),
obs as (
	SELECT
		*
	FROM gn_monitoring.t_observations o
	LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
	LEFT JOIN taxonomie.taxref tx USING (cd_nom)
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
	obs.id_observation,
	obs.id_base_visit,
	-- Site
	LEFT(com.area_code, 2)::integer as dep,
	com.area_name as commune,
	site.sites_group_name as lieu_dit,
	-- Relevé
	site.base_site_name as nom_releve,
	ref_nomenclatures.get_id_nomenclature('TYP_GRP', 'REL') AS id_nomenclature_grp_typ, -- Relevé phytosociologique
	visit_date_min as date,
	observers.observers,
	(visit.data -> 'aire')::integer as surface_m2,
	(CASE
		WHEN (visit.data -> 'forme_areale')::text = 'null' OR (visit.data -> 'forme_areale')::text IS NULL THEN NULL
	 	ELSE (visit.data -> 'forme_areale')::text
	END )as forme_areale,
	(CASE
		WHEN (visit.data -> 'habitat_associe')::text = 'null' OR (visit.data -> 'habitat_associe')::text IS NULL THEN NULL
	 	ELSE (visit.data -> 'habitat_associe')::integer
	END ) as habitat,
	-- Observation
	obs.cd_nom,
	obs.nom_complet,
	obs.nom_vern,
	ref_nomenclatures.get_nomenclature_label((obs.data -> 'strate')::integer) as strate,
	(CASE
		WHEN (obs.data -> 'determiner')::text = 'null' OR (obs.data -> 'determiner')::text IS NULL THEN observers.observers
	 	ELSE utilisateurs.get_name_by_id_role((obs.data -> 'determiner')::integer)
	END ) as determinateur,
	(CASE WHEN obs.data -> 'recouvrement' IS NULL THEN 0
	 	WHEN (obs.data -> 'recouvrement')::text = '0' THEN (obs.data -> 'recouvrement'):: integer + (obs.data -> 'recouv_2') ::integer
		ELSE (obs.data -> 'recouvrement'):: integer
	END ) as pourcent_recouvrement,
	ref_nomenclatures.get_nomenclature_label((obs.data -> 'id_nomenclature_determination_method')::integer) as methode_determination,
	visit.comments || obs.comments as commentaire, 
	-- Géométrie relevé
	site.geom_local
FROM obs
INNER JOIN visit USING (id_base_visit)
LEFT JOIN observers USING (id_base_visit)
INNER JOIN site USING (id_base_site)
LEFT JOIN com USING (id_base_site)
;

GRANT SELECT ON TABLE gn_monitoring.v_export_syrhetflore_standard TO geonat_visu;