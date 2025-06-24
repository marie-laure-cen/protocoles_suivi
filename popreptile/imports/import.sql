-- Plaques
INSERT INTO gn_monitoring.t_base_sites(
	id_inventor,
	id_digitiser,
	base_site_name,
	base_site_code,
	base_site_description,
	first_use_date,
	geom,
	geom_local,
	altitude_min,
	altitude_max
)
SELECT
	id_role as id_inventor,
	8 as id_digitiser,
	num_plaque as base_site_name,
	transect || '_' || num_plaque as base_site_code,
	id_pr2_plaques as base_site_description,
	date_pose as first_use_date,
	ST_Transform(geom_local, 4326),
	geom_local,
	(to_jsonb(ref_geo.fct_get_altitude_intersection(geom_local))->> 'altitude_min')::integer as alti_min,
	(to_jsonb(ref_geo.fct_get_altitude_intersection(geom_local))->> 'altitude_max')::integer as alti_max
FROM gn_imports.popreptile_plaques
LEFT JOIN utilisateurs.t_roles r ON lower(inventor) = lower(nom_role || ' ' || prenom_role)
WHERE NOT id_sites_group IS NULL
;
WITH tbs as (
	SELECT
		*
	FROM gn_monitoring.t_base_sites s
	LEFT JOIN gn_monitoring.t_site_complements c USING (id_base_site)
	WHERE c.id_base_site IS NULL
)
UPDATE gn_imports.popreptile_plaques p
	SET id_base_site = tbs.id_base_site
FROM tbs
WHERE base_site_description::integer = id_pr2_plaques
and p.id_base_site IS NULL
;
INSERT INTO gn_monitoring.t_site_complements (
	id_base_site,
	id_sites_group,
	data
)
SELECT
	id_base_site,
	id_sites_group,
	jsonb_build_object(
		'transect', transect
	)
FROM gn_imports.popreptile_plaques p
WHERE NOT id_base_site is NULL
;
INSERT INTO gn_monitoring.cor_site_module (
	id_base_site,
	id_module
)
SELECT
	id_base_site,
	40
FROM gn_imports.popreptile_plaques p
WHERE NOT id_base_site is NULL
;
INSERT INTO gn_monitoring.cor_site_type (
	id_base_site,
	id_type_site
)
SELECT
	id_base_site,
	1071
FROM gn_imports.popreptile_plaques p
WHERE NOT id_base_site is NULL
;
UPDATE gn_imports.popreptile_2 pr2
SET id_base_site = p.id_base_site
FROM gn_imports.popreptile_plaques p 
WHERE pr2.code_plaque = p.transect || '_' || p.num_plaque
AND p.id_sites_group = pr2.id_sites_group
;
-- Passages
INSERT INTO gn_monitoring.t_base_visits(
	id_dataset,
	id_module,
	id_digitiser,
	id_base_site,
	visit_date_min,
	visit_date_max,
	id_nomenclature_tech_collect_campanule,
	id_nomenclature_grp_typ,
	comments,
	observers_txt
)
SELECT
	1400 as id_dataset,
	40 as id_module,
	id_role as id_digitiser,
	id_base_site,
	visit_date_min,
	visit_date_min as visit_date_max,
	240 as id_nomenclature_tech_collect_campanule,
	132 as id_nomenclature_grp_typ,
	json_agg(json_build_object('id_pr_2', id_pr_2))::text as comments,
	observateur as observers_txt
FROM gn_imports.popreptile_2
LEFT JOIN utilisateurs.t_roles r ON lower(observateur) = lower(nom_role || ' ' || prenom_role)
WHERE NOT id_base_site IS NULL
GROUP BY 
	id_base_site,
	site,
	visit_date_min,
	observateur,
	id_role
ORDER BY
	visit_date_min,
	site
;
UPDATE gn_imports.popreptile_2 pr
	SET id_base_visit = v.id_base_visit
FROM  gn_monitoring.t_base_visits v 
WHERE id_module = 40
AND NOT v.id_base_visit IS NULL
AND v.visit_date_min = pr.visit_date_min
AND v.id_base_site = pr.id_base_site
;
INSERT INTO gn_monitoring.t_visit_complements(
	id_base_visit,
	data
)
SELECT
	id_base_visit,
	jsonb_strip_nulls(jsonb_build_object(
		'num_passage', num_passage,
		'heure_debut', min(hour_min::time),
		'heure_fin', max (hour_min::time),
		'methode_prospection', 'Par plaques',
		'hab_eunis_a', hab_eunis_a,
		'hab_eunis_b', hab_eunis_b,
		'milieu_a', milieu_a,
		'milieu_b', milieu_b,
		'abris', regexp_replace(regexp_replace(abris_visibles, 'Non', 'Pas d''abris'),'Oui', 'Indéterminé'),
		'faisan', CASE WHEN presence_predateurs = 'Non' THEN 'Non' ELSE 'Oui' END,
		'ht_vegetation', hauteur_veg,
		'gestion', gestion_globale,
		'impact_gestion', impact_gestion,
		'gestion_en_cours', gestion_en_cours,
		'frequentation_humaine', frequentation_humaine,
		'meteo', ref_nomenclatures.get_id_nomenclature_by_mnemonique('SUIVI_METEO', meteo),
		'id_nomenclature_cn', ref_nomenclatures.get_id_nomenclature_by_mnemonique('SUIVI_CN', cn),
		'id_nomenclature_vt', ref_nomenclatures.get_id_nomenclature_by_mnemonique('SUIVI_VT', vt),
		'id_nomenclature_tp', ref_nomenclatures.get_id_nomenclature_by_mnemonique('SUIVI_TP', tp)
	)) as data
FROM gn_imports.popreptile_2
WHERE id_base_visit IS NOT NULL
GROUP BY
	id_base_visit,
	num_passage,
	hab_eunis_a,
	hab_eunis_b,
	milieu_a,
	milieu_b,
	abris_visibles,
	presence_predateurs,
	hauteur_veg,
	gestion_globale,
	impact_gestion,
	gestion_en_cours,
	frequentation_humaine,
	meteo,
	cn,
	vt,
	tp
;
INSERT INTO gn_monitoring.cor_visit_observer (
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	id_role
FROM gn_imports.popreptile_2 pr
LEFT JOIN utilisateurs.t_roles r ON lower(r.nom_role || ' ' || r.prenom_role) = lower(pr.observateur)
WHERE NOT id_base_visit is NULL
GROUP BY
	id_base_visit,
	id_role
ORDER BY 
	id_base_visit,
	id_role
;
/*
WITH
	t as (
		SELECT
			*
		FROM ref_nomenclatures.v_0_nomen_active
		WHERE mnemo_type = 'SUIVI_TP'
	),
	v as (
		SELECT
			*
		FROM ref_nomenclatures.v_0_nomen_active
		WHERE mnemo_type = 'SUIVI_VT'
	),
	m as (
		SELECT
			*
		FROM ref_nomenclatures.v_0_nomen_active
		WHERE mnemo_type = 'SUIVI_METEO'
	),
	nomen as (
		SELECT
			id_base_visit,
			vt,
			v.id_nomenclature as id_nomenclature_vt,
			tp,
			t.id_nomenclature as id_nomenclature_tp,
			meteo,
			m.id_nomenclature as id_nomenclature_meteo
		FROM gn_imports.popreptile_2
		LEFT JOIN t ON t.mnemonique = tp
		LEFT JOIN v ON v.mnemonique = vt
		LEFT JOIN m ON m.mnemonique = meteo
		WHERE NOT id_base_visit IS NULL
		GROUP BY
			id_base_visit,
			vt,
			v.id_nomenclature ,
			tp,
			t.id_nomenclature ,
			meteo,
			m.id_nomenclature
		)
UPDATE gn_monitoring.t_visit_complements tvc
SET data = jsonb_set (data, '{id_nomenclature_tp}', to_jsonb(nomen.id_nomenclature_tp))
FROM nomen
WHERE nomen.id_base_visit = tvc.id_base_visit
AND (data ->> id_nomenclature_tp ) IS NULL
;
*/
-- Observations
INSERT INTO gn_monitoring.t_observations(
	id_base_visit,
	cd_nom,
	id_digitiser,
	comments
)
SELECT
	id_base_visit,
	cd_nom,
	id_role,
	taxon as comments
FROM gn_imports.popreptile_2 pr
LEFT JOIN utilisateurs.t_roles r ON lower(r.nom_role || ' ' || r.prenom_role) = lower(pr.observateur)
WHERE NOT id_base_visit IS NULL
;
INSERT INTO gn_monitoring.t_observation_complements(
	id_observation,
	data
)
SELECT
	id_observation,
	jsonb_build_object(
		'count_min', effectif,
		'count_max', effectif,
		'id_nomenclature_type_count', ref_nomenclatures.get_id_nomenclature('TYP_DENBR'::character varying, 'Co'::character varying)
	)
FROM gn_imports.popreptile_2 pr 
WHERE NOT id_observation IS NULL
;
