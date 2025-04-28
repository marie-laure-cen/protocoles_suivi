-- AJOUT D'UNE COLONNE OBSERVATEURS
/*
ALTER TABLE gn_imports.sh
ADD COLUMN observers text[][];
*/


-- DIFFERENCE REL PHYTO ET CARRE CONTACT

UPDATE gn_imports.sh sh
SET rel_phyto = (CASE WHEN sh.quadrat = '/' OR sh.quadrat IS NULL THEN true ELSE false END)
WHERE sh.rel_phyto IS NULL
;

-- Création des groupes de sites
WITH sh as (
	SELECT
		TRIM(UPPER(id_site)) as id_site
	FROM gn_imports.sh
	WHERE NOT id_site in ('00AAA' ,'27AN2')
	AND NOT rel_phyto IS true
	GROUP BY UPPER(id_site)
)
INSERT INTO gn_monitoring.t_sites_groups (
	id_module,
	sites_group_code,
	sites_group_name,
	data
)
SELECT
	39 as id_module,
	COALESCE(la.area_code, la2.area_code) as sites_group_code,
	COALESCE(la.area_name,la2.area_name) as sites_group_name,
	jsonb_strip_nulls(
		jsonb_build_object(
			'commune',
			COALESCE(la.additional_data->>'commune' ,la2.additional_data->>'commune' ),
			'id_site_my_sql',
			sh.id_site
		)
	) as data
FROM sh
LEFT JOIN ref_geo.l_areas la ON sh.id_site = la.area_code
LEFT JOIN ref_geo.l_areas la2 ON sh.id_site = (la2.additional_data->>'id_site_old')
WHERE NOT COALESCE(la.area_code, la2.area_code) is null
ORDER BY id_site
;

-- Visualisation du résultat
SELECT
	tsg.id_sites_group,
	tsg.data->> 'id_site_my_sql',
	sh.id_sh
FROM gn_monitoring.t_sites_groups tsg
LEFT JOIN gn_imports.sh sh ON (tsg.data->> 'id_site_my_sql') = id_site
WHERE tsg.id_module = 39
;

-- Ajout des id_sites_group dans la table d'import
UPDATE gn_imports.sh sh 
	SET id_sites_group = tsg.id_sites_group
FROM gn_monitoring.t_sites_groups tsg
WHERE (tsg.data->> 'id_site_my_sql') = sh.id_site
AND tsg.id_module = 39
AND NOT rel_phyto IS true

-- Ajout de la date de lancement
with sh as (
	SELECT
		id_sites_group,
		min(time_plot) as lcmt 
	FROM gn_imports.sh 
	GROUP BY id_sites_group
	)
UPDATE gn_monitoring.t_sites_groups tsg 
SET data = jsonb_set(
		tsg.data,
		'{annee}',
		to_jsonb(sh.lcmt)
	)
FROM sh
WHERE sh.id_sites_group = tsg.id_sites_group
AND NOT sh.lcmt IS NULL
;

-- Mise à jour des observateurs
UPDATE gn_imports.sh
    SET responsable = 'Alexandre Ferré'
WHERE responsable = 'Alexandre Ferre'

-- Création des placettes
WITH plot as (
	SELECT
		id_sites_group::text || transect::text || plot::text || MIN(time_plot) as id_unique_plot,
		id_sites_group,
		transect,
		plot,
		MIN(time_plot) as time_plot,
		MAX(CASE WHEN coord_x = 0 OR coord_x IS NULL THEN 0 ELSE coord_x END) as coord_x,
		MAX(CASE WHEN coord_y = 0 OR coord_y IS NULL THEN 0 ELSE coord_y END) as coord_y
	FROM gn_imports.sh sh 
	WHERE NOT sh.id_sites_group IS NULL
	AND NOT rel_phyto IS true
	AND id_base_site IS NULL
	GROUP BY
		id_sites_group,
		transect,
		plot
),
reg as (
	SELECT
		area_code,
		geom_4326
	FROM ref_geo.l_areas WHERE id_type = 33
),
plot_geom as (
	SELECT
		id_unique_plot,
		id_sites_group, 
		transect,
		plot,
		time_plot,
		ST_Transform(ST_SetSRID(ST_MakePoint(coord_x,coord_y),2154),4326) as geom
	FROM plot
	INNER JOIN reg ON ST_Intersects(ST_Transform(ST_SetSRID(ST_MakePoint(coord_x,coord_y),2154),4326),reg.geom_4326)
),
resp as (
	SELECT
		id_sites_group::text || transect::text || plot::text || time_plot as id_unique_plot,
		id_sites_group,
		transect,
		plot,
		responsable as observers,
		SPLIT_PART(responsable,' -',1) as responsable,
		tr.id_role,
		tr.nom_role,
		tr.prenom_role
	FROM gn_imports.sh 
	WHERE NOT rel_phyto IS true
	LEFT JOIN utilisateurs.t_roles tr ON LOWER(responsable) = LOWER( tr.prenom_role || ' ' || tr.nom_role )
	WHERE time_plot = annee and not responsable = 'Non renseigné'
	GROUP BY 
		id_sites_group,
		transect,
		plot,
		time_plot,
		responsable,
		tr.id_role,
		tr.nom_role,
		tr.prenom_role
)
INSERT INTO gn_monitoring.t_base_sites (
	id_inventor,
	id_digitiser,
	id_nomenclature_type_site,
	base_site_name,
	first_use_date,
	base_site_description,
	geom
)
SELECT
	resp.id_role as id_inventor,
	8 as id_digitiser,
	1070 as id_nomenclature_type_site,
	'T' || plot_geom.transect || '_' ||  plot_geom.plot as base_site_name,
	(time_plot|| '-01-01')::date as first_use_date,
	plot_geom.id_sites_group as base_sites_description,
	plot_geom.geom
FROM plot_geom
LEFT JOIN resp USING(id_unique_plot)
ORDER BY
	plot_geom.id_sites_group, 
	plot_geom.transect,
	plot_geom.plot
;

-- Ajout des id_base_site
UPDATE gn_imports.sh sh 
	SET id_base_site = tbs.id_base_site
FROM gn_monitoring.t_base_sites tbs
WHERE tbs.base_site_name = 'T' || sh.transect || sh.plot 
AND tbs.base_site_description = sh.id_sites_group::text
AND tbs.id_nomenclature_type_site = 1070
AND sh.id_base_site IS NULL
AND NOT rel_phyto IS true
;

-- Insertion dans la table des complements
WITH plot as (
	SELECT
		id_base_site,
		id_sites_group
	FROM gn_imports.sh
	WHERE NOT id_base_site IS NULL and NOT id_sites_group IS NULL
	GROUP BY 
		id_base_site,
		id_sites_group
)
INSERT INTO gn_monitoring.t_site_complements (
	id_base_site,
	id_module,
	id_sites_group
)
SELECT
	plot.id_base_site,
	39,
	plot.id_sites_group
FROM plot
LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
WHERE tsc.id_base_site IS NULL
;

-- Ajout des codes pour ordre des placettes dans le module
WITH code as (
	SELECT
		id_base_site,
		CASE 
			WHEN NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',1), '\D','','g'), '')::integer<10 
			THEN 'T0' || NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',1), '\D','','g'), '')::text 
			ELSE 'T' || NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',1), '\D','','g'), '')::text 
		END AS transect,
		CASE 
			WHEN NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',2), '\D','','g'), '')::integer<10 
			AND base_site_name LIKE '%_R%'
			THEN 'R0' || NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',2), '\D','','g'), '')::text 
			WHEN NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',2), '\D','','g'), '')::integer>9
			AND base_site_name LIKE '%_R%'
			THEN'R' || NULLIF(regexp_replace(SPLIT_PART( base_site_name,'_',2), '\D','','g'), '')::text 
			ELSE SPLIT_PART( base_site_name,'_',2)
		END AS plot,
		base_site_name
	FROM gn_monitoring.t_base_sites tbs
	WHERE tbs.id_nomenclature_type_site = 1070
)
UPDATE gn_monitoring.t_base_sites tbs2
SET base_site_code = transect || '_' || plot 
FROM code
WHERE tbs2.id_nomenclature_type_site = 1070
AND tbs2.id_base_site = code.id_base_site
AND tbs2.base_site_code IS NULL
-- Attention quelques erreurs pour les placettes mal formatées => vérifier et corriger le résultat (exemple T11_R1-BER ou T11_6R)
;

-- Vérification unicité des placettes
SELECT
	tsg.sites_group_code as id_site,
	tsg.sites_group_name,
	tbs.base_site_code,
	COUNT(DISTINCT tbs.base_site_name) as nb_dupl
FROM gn_monitoring.t_base_sites tbs
LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
WHERE tbs.id_nomenclature_type_site = 1070
GROUP BY
	tsg.sites_group_code,
	tsg.sites_group_name,
	tbs.base_site_code
ORDER BY nb_dupl DESC
;

-- Eventuelles corrections
/*

WITH sh2 as (
SELECT 
	id_sites_group,
	id_site,
	id_base_site
FROM gn_imports.sh sh
LEFT JOIN gn_monitoring.t_sites_groups tsg using (id_sites_group)
WHERE not sh.id_base_site is null
group by 
	id_site, 
	id_sites_group, 
	id_base_site
)
SELECT
	tsc.id_sites_group,
	sh2.id_site,
	tbs.id_base_site,
	tbs.base_site_name
FROM gn_monitoring.t_base_sites tbs
LEFT JOIN gn_monitoring.t_site_complements tsc using (id_base_site)
LEFT JOIN gn_monitoring.t_sites_groups tsg using (id_sites_group)
LEFT JOIN sh2 USING (id_base_site)
WHERE id_nomenclature_type_site = 1070 and tsg.id_sites_group is null
;

SELECT 
	id_sites_group,
	id_site
FROM gn_imports.sh sh
LEFT JOIN gn_monitoring.t_sites_groups tsg using (id_sites_group)
WHERE tsg.id_sites_group is null
and not sh.id_base_site is null
group by id_site, is_sites_group

UPDATE gn_imports.sh sh
SET id_sites_group = 255
WHERE id_site = '76BEL'
;

WITH sh as (
SELECT 
	id_sites_group,
	id_site,
	id_base_site
FROM gn_imports.sh sh
LEFT JOIN gn_monitoring.t_sites_groups tsg using (id_sites_group)
WHERE not sh.id_base_site is null
group by 
	id_site, 
	id_sites_group, 
	id_base_site
)
SELECT
	*
FROM gn_monitoring.t_site_complements tsc
LEFT JOIN sh USING (id_base_site)
WHERE sh.id_site = '76BEL'
;

WITH sh2 as (
SELECT 
	id_sites_group,
	id_site,
	id_base_site
FROM gn_imports.sh sh
LEFT JOIN gn_monitoring.t_sites_groups tsg using (id_sites_group)
WHERE not sh.id_base_site is null
group by 
	id_site, 
	id_sites_group, 
	id_base_site
)
UPDATE gn_monitoring.t_site_complements tsc
SET id_sites_group = sh2.id_sites_group
FROM sh2
WHERE sh2.id_site = '76BEL' and tsc.id_base_site = sh2.id_base_site
;
*/

-- Correction des placettes avec mauvaises géométries
WITH plot as (
	SELECT
		id_sites_group,
		id_site,
		transect,
		plot,
		time_plot,
		(CASE WHEN coord_x = 0 THEN NULL ELSE coord_x END ) as coord_x,
		CASE WHEN coord_y = 0 THEN NULL ELSE coord_y END as coord_y,
		(CASE WHEN longitude = 0 THEN NULL ELSE longitude END ) as longitude,
		CASE WHEN latitude = 0 THEN NULL ELSE latitude END as latitude
	FROM gn_imports.sh sh 
	WHERE NOT sh.id_sites_group IS NULL and sh.id_base_site IS NULL
	GROUP BY
		id_sites_group,
		id_site,
		transect,
		plot,
		time_plot,
		coord_x,
		coord_y,
		longitude,
		latitude
),
reg as (
	SELECT
		area_code,
		geom_4326
	FROM ref_geo.l_areas WHERE id_type = 33
),
plot_geom as (
	SELECT
		id_sites_group, 
		id_site,
		transect,
		plot,
		time_plot,
		COALESCE(
			ST_Transform(ST_SetSRID(ST_MakePoint(coord_x,coord_y),2154),4326),
			ST_SetSRID(ST_MakePoint(longitude,latitude),4326)
		) as geom
	FROM plot
),
resp as (
	SELECT
		id_sites_group,
		id_site,
		transect,
		plot,
		responsable as observers,
		SPLIT_PART(responsable,' -',1) as responsable
	FROM gn_imports.sh 
	WHERE time_plot = annee and not responsable = 'Non renseigné'
	GROUP BY 
		id_sites_group,
		id_site,
		transect,
		plot,
		responsable
),
r2 as (
	SELECT
		resp.*,
		tr.id_role,
		tr.nom_role,
		tr.prenom_role
	FROM resp
	LEFT JOIN utilisateurs.t_roles tr ON LOWER(responsable) = LOWER( tr.prenom_role || ' ' || tr.nom_role )
),
sites as (
	SELECT
		area_code as id_site,
		area_name,
		additional_data ->> 'id_site_old' as id_site_old
	FROM ref_geo.l_areas 
	WHERE id_type in (12,34,37,46)
)
SELECT
	coalesce(s1.area_name, s2.area_name) as nom_site,
	plot_geom.*,
	r2.*
FROM plot_geom
LEFT JOIN r2 ON r2.id_sites_group::text || r2.transect::text || r2.plot::text = plot_geom.id_sites_group::text || plot_geom.transect::text || plot_geom.plot::text
LEFT JOIN sites S1 ON plot_geom.id_site = s1.id_site
LEFT JOIN sites s2 ON plot_geom.id_site = s2.id_site_old
ORDER BY
	plot_geom.id_sites_group, 
	plot_geom.transect,
	plot_geom.plot
;

-- Mise à jour des commentaires sur les placettes
WITH sites as (
	SELECT
		id_base_site,
		STRING_AGG(DISTINCT site_comment, ', ') as commentaire
	FROM gn_imports.sh
	WHERE NOT id_base_site IS NULL
	GROUP BY id_base_site
)
UPDATE gn_monitoring.t_base_sites tbs
SET base_site_description = commentaire
FROM sites
WHERE sites.id_base_site = tbs.id_base_site
;

-- CREATION DES RELEVES

-- Date du relevé
UPDATE gn_imports.sh
	SET date_suivi = to_timestamp(time_suivi::double precision)::date
WHERE date_suivi IS NULL
;

-- Observateurs du relevé
UPDATE gn_imports.sh sh
	SET observers = ARRAY(SELECT DISTINCT UNNEST(string_to_array(sh.responsable,' - ')))
WHERE not sh.responsable = 'Non renseigné'

-- Ajout des relevés
WITH rel as (
SELECT
	id_base_site,
	date_suivi as visit_date_min,
	1396 as id_dataset,  
	39 as id_module,
    8 as id_digitiser,
	240 as id_nomenclature_tech_collect_campanule,
    134 as id_nomenclature_grp_typ,
	observers,
	quadrat,
	taux_recouvrement,
	hauteur_vegetation,
	strate_bryolichenique,
	STRING_AGGREGATE( DISTINCT sh.id_suivi_habitat, ',')::text as comments
FROM gn_imports.sh sh
WHERE NOT id_base_site IS NULL 
AND NOT id_sites_group IS NULL
AND NOT rel_phyto IS true
GROUP BY
	id_base_site,
	date_suivi,
	observers,
	quadrat,
	taux_recouvrement,
	hauteur_vegetation,
	strate_bryolichenique
)
INSERT INTO gn_monitoring.t_base_visits (
	id_base_site,
	id_dataset,
	id_module,
	id_digitiser,
	visit_date_min,
	visit_date_max,
	id_nomenclature_tech_collect_campanule,
	id_nomenclature_grp_typ,
	comments
)
SELECT
	id_base_site,
	id_dataset,
	id_module,
	id_digitiser,
	visit_date_min,
	visit_date_min as visit_date_max,
	id_nomenclature_tech_collect_campanule,
	id_nomenclature_grp_typ,
	comments
FROM rel
ORDER BY 
	visit_date_min,
	quadrat
;

-- Intégration des id_base_visit
WITH rel_obs as (
SELECT
	UNNEST(string_to_array(comments) ',') as id_suivi_habitat, -- A vérifier
	id_base_visit
FROM gn_monitoring.t_base_visits
WHERE id_module = 39
)
UPDATE gn_imports.sh sh
SET id_base_visit = rel_obs.id_base_visit
FROM rel_obs
WHERE sh.id_suivi_habitat::text = rel_obs.id_suivi_habitat
AND sh.id_base_visit IS NULL
AND NOT rel_phyto IS true
;

-- Ajout des compléments à la visite
INSERT INTO gn_monitoring.t_visit_complements(
	id_base_visit,
	data
)
SELECT
	id_base_visit,
	jsonb_build_object(
		'quadrat',  STRING_AGG( DISTINCT sh.quadrat, ','),
		'hauteur_vegetation',  MAX( sh.hauteur_vegetation),
		'taux_recouvrement',  MAX( sh.taux_recouvrement),
		'strate_bryo', MAX(sh.strate_bryolichenique::text)
	) as additional_data
	--observers,
FROM gn_imports.sh sh
WHERE NOT id_base_visit IS NULL 
AND NOT rel_phyto IS true
GROUP BY
	id_base_site,
	id_base_visit
ORDER BY id_base_visit
;

-- Ajout des observateurs
WITH obs as (
	SELECT
		id_base_visit,
		UNNEST (observers) as observateur
	FROM gn_imports.sh sh
	WHERE NOT id_base_visit IS NULL 
	AND NOT rel_phyto IS true
	ORDER BY id_base_visit
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	id_role
FROM obs
LEFT JOIN utilisateurs.t_roles r ON LOWER(observateur) = LOWER (prenom_role || ' ' || nom_role)
WHERE NOT id_role IS NULL
GROUP BY
	id_base_visit,
	observateur,
	id_role
ORDER BY
	id_base_visit,
	id_role
ON CONFLICT DO NOTHING
;

-- Ajout des noms mal formatés
WITH obs as (
SELECT
	id_base_visit,
	UNNEST (observers) as observateur
FROM gn_imports.sh sh
WHERE NOT id_base_visit IS NULL 
ORDER BY id_base_visit
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	13
FROM obs
WHERE observateur = 'Emmanuelle Bernet'
GROUP BY
	id_base_visit,
	observateur
ORDER BY
	id_base_visit
ON CONFLICT DO NOTHING
;
WITH obs as (
SELECT
	id_base_visit,
	UNNEST (observers) as observateur
FROM gn_imports.sh sh
WHERE NOT id_base_visit IS NULL 
ORDER BY id_base_visit
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	170
FROM obs
WHERE observateur = 'Arnaud Masset (stagiaire 2009)'
GROUP BY
	id_base_visit,
	observateur
ORDER BY
	id_base_visit
ON CONFLICT DO NOTHING
;
WITH obs as (
SELECT
	id_base_visit,
	UNNEST (observers) as observateur
FROM gn_imports.sh sh
WHERE NOT id_base_visit IS NULL 
ORDER BY id_base_visit
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	171
FROM obs
WHERE observateur = 'François Martinet (stagiaire 2008)'
GROUP BY
	id_base_visit,
	observateur
ORDER BY
	id_base_visit
ON CONFLICT DO NOTHING
;
WITH obs as (
SELECT
	id_base_visit,
	UNNEST (observers) as observateur
FROM gn_imports.sh sh
WHERE NOT id_base_visit IS NULL 
ORDER BY id_base_visit
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	475
FROM obs
WHERE observateur LIKE 'Vatsana Souannavong%'
GROUP BY
	id_base_visit,
	observateur
ORDER BY
	id_base_visit
ON CONFLICT DO NOTHING
;
UPDATE gn_imports.sh 
	SET observers = ARRAY['Aurélie Dardillac','Lydie Doisy', 'Emmanuel Vochelet', 'Clément-Blaise Duhaut', 'Thomas Cheyrezy']
WHERE responsable = 'Aurélie DARDILLAC, Lydie DOISY, Emmanuel VOCHELET, Clément-Blaise DUHAUT, Thomas CHEYREZY'
;
WITH o as (
	SELECT
		id_base_visit,
		UNNEST(observers) as observer
	FROM gn_imports.sh sh
	WHERE responsable = 'Aurélie DARDILLAC, Lydie DOISY, Emmanuel VOCHELET, Clément-Blaise DUHAUT, Thomas CHEYREZY'
)
INSERT INTO gn_monitoring.cor_visit_observer(
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	id_role
FROM o
LEFT JOIN utilisateurs.t_roles r ON r.prenom_role || ' ' || r.nom_role = o.observer
GROUP BY 
	id_base_visit,
	id_role
;

-- Mise à jour des commentaires des relevés
UPDATE gn_monitoring.t_base_visits tbv
SET comments = NULL
WHERE tbv.id_module = 39
;

-- Changement de module des relevés phytos

WITH type_rel as (
	SELECT
		id_base_site,
		id_base_visit,
		bool_or(rel_phyto) as is_cc_rp,
		bool_and(rel_phyto) as is_only_rp
	FROM gn_imports.sh
	GROUP BY
		id_base_site,
		id_base_visit,
		rel_phyto
	ORDER BY
		id_base_site,
		id_base_visit,
		rel_phyto
)
SELECT
	*
FROM type_rel
WHERE is_cc_rp =true
ORDER BY 
	id_base_site, 
	id_base_visit
;

with 
rp as (
	SELECT
		id_base_site,
		--id_base_visit,
		BOOL_AND(rel_phyto) as u_rp
	FROM gn_imports.sh sh 
	WHERE NOT id_base_site IS NULL AND NOT id_base_visit IS NULL
	GROUP BY 		
		id_base_site--,id_base_visit
),
site as (
	SELECT 
		*
	FROM gn_monitoring.t_base_sites tbs 
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	WHERE tsc.id_module = 39
),
rel as (
	SELECT
		id_base_visit,
		id_base_site,
		(tvc.data ->>'quadrat') as quadrat
	FROM gn_monitoring.t_base_visits tbv
	LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	LEFT JOIN site USING (id_base_site)
	WHERE tbv.id_module = 39
	AND (tvc.data ->>'quadrat') = '/' OR (tvc.data ->>'quadrat') IS NULL
)
SELECT
	*
FROM site
INNER JOIN rp USING (id_base_site)
WHERE u_rp = true
ORDER BY 1
;

with 
rp as (
	SELECT
		id_base_site,
		--id_base_visit,
		BOOL_AND(rel_phyto) as u_rp
	FROM gn_imports.sh sh 
	WHERE NOT id_base_site IS NULL AND NOT id_base_visit IS NULL
	GROUP BY 		
		id_base_site--,id_base_visit
),
site as (
	SELECT 
		*
	FROM gn_monitoring.t_base_sites tbs 
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	INNER JOIN rp USING (id_base_site)
	WHERE tsc.id_module = 39 AND u_rp = true
),
rel as (
	SELECT
		id_base_visit,
		id_base_site,
		(tvc.data ->>'quadrat') as quadrat
	FROM gn_monitoring.t_base_visits tbv
	LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	LEFT JOIN site USING (id_base_site)
	WHERE tbv.id_module = 39
	AND (tvc.data ->>'quadrat') = '/' OR (tvc.data ->>'quadrat') IS NULL
)
UPDATE gn_monitoring.t_site_complements s 
SET id_module = 38
FROM site
WHERE site.id_base_site = s.id_base_site
/*
SELECT *
FROM  gn_monitoring.t_site_complements s 
INNER JOIN site USING (id_base_site)
ORDER BY 1*/
;
UPDATE gn_monitoring.t_base_visits tbv
	SET id_module = 38 
FROM gn_monitoring.t_site_complements tsc 
WHERE tsc.id_base_site = tbv.id_base_site
AND tsc.id_module = 38 
AND tbv.id_module = 39
;

With 
rp as (
	SELECT
		id_sites_group,
		--id_base_visit,
		BOOL_AND(rel_phyto) as u_rp
	FROM gn_imports.sh sh 
	WHERE NOT id_sites_group IS NULL AND NOT id_base_site IS NULL AND NOT id_base_visit IS NULL
	GROUP BY 		
		id_sites_group--,id_base_visit
)
UPDATE gn_monitoring.t_sites_groups tsg
	SET id_module = 38
FROM rp WHERE tsg.id_sites_group = rp.id_sites_group
AND tsg.id_module = 39 
AND u_rp = true
;
WITH sm as (
	SELECT
		id_sites_group,
		id_module
	FROM gn_monitoring.t_site_complements tsc
	WHERE tsc.id_module = 38 
	GROUP BY 	
		id_sites_group,
		id_module
)
INSERT INTO gn_monitoring.t_sites_groups (
	sites_group_name,
	sites_group_code,
	id_module,
	comments,
	data
)
SELECT
	tsg.sites_group_name,
	tsg.sites_group_code,
	38 as id_module,
	id_sites_group as comments,
	tsg.data
FROM gn_monitoring.t_sites_groups tsg 
INNER JOIN sm USING (id_sites_group)
WHERE tsg.id_module= 39
;
WITH sm as (
	SELECT
		id_sites_group,
		id_base_site
	FROM gn_monitoring.t_site_complements tsc
	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	WHERE tsc.id_module = 38 AND tsg.id_module = 39
),
gp as (
	SELECT
		*
	FROM gn_monitoring.t_sites_groups tsg 
	WHERE id_module = 38
	AND NOT comments IS NULL
)
UPDATE gn_monitoring.t_site_complements s
SET id_sites_group = gp.id_sites_group
FROM sm
LEFT JOIN gp ON gp.comments = sm.id_sites_group::text
WHERE sm.id_base_site = s.id_base_site
AND s.id_module = 38
;

-- OBSERVATIONS

-- Ajout des espèces
WITH obs as (
	SELECT
		sh.id_base_visit,
		sh.cd_nom,
		jsonb_build_object(
			'id_sh_mysql' , sh.id_suivi_habitat,
			'nom_cite', sh.nom_cite
		)::text as comments
	FROM gn_imports.sh sh
	WHERE NOT rel_phyto IS TRUE
	AND id_observation IS NULL
	AND NOT id_base_visit IS NULL
	GROUP BY 	
		sh.id_base_visit,
		sh.cd_nom,
		sh.nom_cite,
		sh.id_suivi_habitat
)
INSERT INTO gn_monitoring.t_observations (
	id_base_visit,
	cd_nom,
	comments
)
SELECT
	*
FROM obs
ORDER BY id_base_visit, cd_nom
;

-- Ajout des id_observation dans la base d'import
WITH obs_gn as (
	SELECT
		id_observation,
		(o.comments::jsonb ->>'id_sh_mysql')::integer as id_suivi_habitat
	FROM gn_monitoring.t_observations o
	LEFT JOIN gn_monitoring.t_base_visits USING (id_base_visit)
	WHERE id_module = 39
)
UPDATE gn_imports.sh sh
SET id_observation = obs_gn.id_observation
FROM obs_gn
WHERE obs_gn.id_suivi_habitat = sh.id_suivi_habitat
;

-- Ajout des compléments et mise à jour des commentaires
WITH obs as (
	SELECT
		sh.id_observation,
		jsonb_build_object(
			'id_sh_mysql' , sh.id_suivi_habitat
		) as data
	FROM gn_imports.sh sh
	WHERE NOT id_observation IS NULL
	GROUP BY 	
		sh.id_observation,
		sh.id_suivi_habitat
)
INSERT INTO gn_monitoring.t_observation_complements (
	id_observation,
	data
)
SELECT
	*
FROM obs
ORDER BY id_observation
;
UPDATE gn_monitoring.t_observations o
SET comments = sh.nom_cite
FROM gn_imports.sh sh
WHERE sh.id_observation = o.id_observation
AND NOT nom_cite IS NULL
;