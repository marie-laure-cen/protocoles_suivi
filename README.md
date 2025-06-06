# Modules de suivi pour le GeoNature du CENN Normandie

## Présentation des modules

Les modules suivants sont implémentés dans GeoNature:
- [ila](ila),
- [steli](steli),
- [sterf](sterf),
- [syrhet flore](syrhetflore),
- [syrhet hétérocères](syrhetheteroceres),
- [syrhet syrphes](syrhetsyrphes),
- [piezo](piezo)

Les modules suivants sont en cours de développement:
- [carré contact](carrecontact),
- [relevé phyto](phyto),
- [pop reptile](popreptile),
- [travaux](travaux),
- [paturage](paturage)

Des développements peuvent être envisagés pour les relevés du PRELE et du PRAM. Des exemples de modules de suivis sont disponibles dans la dossier [exemples](exemples).

## Script d'installation des modules

Dans le dossier geoa, lancer les commandes suivantes avec l'utilisateur administrateur de GeoNature (et non root)

```bash
source ~/geonature/backend/venv/bin/activate

mkdir geonature/backend/media/monitorings

ln -s /home/geoa/suivis/carrecontact ~/geonature/backend/media/monitorings/carrecontact
ln -s /home/geoa/suivis/ila ~/geonature/backend/media/monitorings/ila
ln -s /home/geoa/suivis/phyto ~/geonature/backend/media/monitorings/phyto
ln -s /home/geoa/suivis/prat ~/geonature/backend/media/monitorings/prat
ln -s /home/geoa/suivis/piezo ~/geonature/backend/media/monitorings/piezo
ln -s /home/geoa/suivis/popreptile ~/geonature/backend/media/monitorings/popreptile
ln -s /home/geoa/suivis/steli ~/geonature/backend/media/monitorings/steli
ln -s /home/geoa/suivis/sterf ~/geonature/backend/media/monitorings/sterf
ln -s /home/geoa/suivis/syrhetflore ~/geonature/backend/media/monitorings/syrhetflore
ln -s /home/geoa/suivis/syrhetheteroceres ~/geonature/backend/media/monitorings/syrhetheteroceres
ln -s /home/geoa/suivis/syrhetsyrphes ~/geonature/backend/media/monitorings/syrhetsyrphes

geonature monitorings install carrecontact
geonature monitorings install ila
geonature monitorings install phyto
geonature monitorings install piezo
geonature monitorings install popreptile
geonature monitorings install steli
geonature monitorings install sterf
geonature monitorings install syrhetflore
geonature monitorings install syrhetheteroceres
geonature monitorings install syrhetsyrphes

geonature permissions supergrant --group --nom "Administrateurs_CEN"
```

## Intégration des données pré-existantes

La démarche suivante se base sur le protocole ILA, anciennement hébergé sur une base MySql.

### Récupération des données dans la base MySql

La première étape consiste à créer une vue qui permet de récupérer l'ensemble des données du protocole sur la base MySql.

```sql
DROP VIEW steli_sterf.ila_pr_gn ;
CREATE VIEW steli_sterf.ila_pr_gn AS
SELECT
-- SITE CEN
	t.ID_Site AS code_site,
	s.Nom_Site AS nom_site,
-- TRANSECT
	o.ID_Transect AS id_transect_ila,
	t.Nom_Transect AS transect,
-- PASSAGE
	hm.ID_Horaire_Meteo AS id_visit_ila,
	hab.ID_Habitat AS id_visit_ila2,
	hm.ID_Passage AS num_passage,
	o.Annee AS annee,
	hm.Date AS visit_date_min,
	hm.Heure AS heure_min,
	tp.Graduation_Temp AS tp,
	cn.Graduation_Couver AS cn,
	vt.Graduation_Vent AS vt,
	lh.habitat,
	lg.gestion,
	li.impact,
	hab.Remarque AS visit_comment,
-- OBSERVATION
	o.ID_Observation AS id_obs_ila,
	resp.Observateur AS determiner,
	o.ID_Taxon AS cd_nom,
	tx.Taxon AS nom_complet,
	o.Effectif_Total AS effectif,
	o.Effectif_Femelle AS nb_femelle,
	o.Effectif_Male AS nb_male,
	o.Date_Saisie AS date_saisie,
	o.Remarque AS obs_comment
FROM ila_observation o
LEFT JOIN ila_taxref tx ON o.ID_Taxon = tx.ID_Taxref
LEFT JOIN ila_transect t ON o.ID_Transect = t.ID_Transect
LEFT JOIN ila_responsable resp ON CONCAT(o.ID_Transect, o.Annee) = CONCAT(resp.ID_Transect, resp.Annee) 
LEFT JOIN ila_horaire_meteo hm ON CONCAT(hm.ID_Passage, hm.ID_Transect, extract(year from hm.Date)) = CONCAT(o.ID_Passage, o.ID_Transect, o.Annee) 
LEFT JOIN obhn_temperature tp  ON hm.Temperature = tp.ID_Temperature
LEFT JOIN obhn_couverture_nuage cn ON hm.Couverture_Nuage = cn.ID_Couverture
LEFT JOIN obhn_vent vt  ON hm.Vent = vt.ID_Vent
LEFT JOIN ila_habitat hab ON CONCAT(o.ID_Passage, o.ID_Transect, o.Annee) = CONCAT(hab.ID_Passage, hab.ID_Transect, hab.Annee) 
LEFT JOIN ila_list_habitat lh ON lh.id_habitat = hab.habitat
LEFT JOIN ila_list_gestion lg ON lg.id_gestion = hab.gestion
LEFT JOIN ila_list_impact li ON li.id_impact = hab.impact
ORDER BY hm.Date DESC
;
```

### Formatage des données pour GeoNature

Les données sont ensuite importées dans une table de GeoNature, dans le schéma import: `gn_imports.ila_import`. Un lien avec les utilisateurs de GeoNature peuvent être créés :

Dans Qgis :

```sql
title(
    regexp_replace( 
        regexp_replace( 
            regexp_replace( 
                title("determiner"),    
                'Fiot Benoît'  ,   
                'Fiot Benoit' 
            ),   
            'Lefrancois Wilfried' ,   
            'Lefrançois Wilfried'  
        ),  
        'Mace Emmanuel' ,  
        'Macé Emmanuel' 
    )
)
```

Dans postgresql

```sql
UPDATE gn_imports.ila_import i SET id_digitiser = r.id_role
FROM utilisateurs.t_roles r WHERE lower(i.determiner) = lower(r.nom_role || ' ' || r.prenom_role)
;
```

La **liste des sites** du protocole peut être créée en partie automatiquement dans la table `gn_monitoring.t_sites_groups` :

```sql
WITH ila_site as (
    SELECT
        code_site,
        nom_site
    FROM ila_pr_gn
    GROUP BY
        code_site,
        nom_site
),
gn_site as (
    SELECT
        area_code,
        area_name
    FROM ref_geo.l_areas
    WHERE id_type in (12,34,37)
)
INSERT INTO gn_monitoring.t_sites_groups (
    id_module,
    sites_group_name,
    sites_group_code,
    sites_group_description
)
SELECT
    33, -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
    gn_site.area_name,
    gn_site.area_code,
    ila_site.nom_site
FROM gn_site
INNER JOIN ila_site ON ila_site.code_site = gn_site.area_code
```

Il faut ensuite corriger la table là où les codes sites ne sont pas identiques entre la base de données source et GeoNature. Une fois les sites créés, il est possible d'ajouter des champs additionnels, comme par exemple la.es commune.s :

```sql
WITH
    site as ( SELECT * FROM ref_geo.l_areas WHERE id_type in (12,34,37) ),
    com as ( SELECT * FROM ref_geo.l_areas WHERE id_type = 25 ),
    sc as (
        SELECT
            site.area_code as id_site,
            site.area_name as nom_site,
            STRING_AGG(com.area_name, ',' ORDER BY com.area_name) as communes
        FROM site
        LEFT JOIN com ON ST_Intersects( com.geom, site.geom)
        GROUP BY site.area_code, site.area_name
        ORDER BY site.area_name
    )
UPDATE gn_monitoring.t_sites_groups tsg
	SET data = jsonb_set(	
		tsg.data::jsonb, 
		'{commune}', 
		to_jsonb(sc.communes)
    )
FROM sc 
WHERE id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
AND sc.id_site = tsg.sites_group_code
;
```

La **création des transects** doit être réalisée entre Qgis et Postgresql puisqu'il faut rassembler la géométrie des tables enregistrées sur le réseau avec les informations de la base MySql. Les tables à remplir sont `gn_monitoring.t_base_sites` et `gn_monitoring.t_site_complements`

La **création des passages** demande 4 étapes : 
- Création des passages avec les champs génériques de GN `gn_monitoring.t_base_visits`,
- Mise à jour de la table d'import avec les identifiants GN,
- Ajout des données supplémentaires dans la table de compléments `gn_monitoring.t_visit_complements`,
- Ajout des observateurs dans la table de lien observateurs - passage `gn_monitoring.cor_visit_observer`.

Il est ensuite possible de mettre à jour la table des transects avec les données intéressantes du dernier passage (habitat, gestion...) ou d'identifier la date du premier passage pour remplir un champ de début du suivi, etc.

La création des passages se fait comme suit :

```sql
-- Remplissage de la table t_base_visits
WITH ila_transect as (
	SELECT
		*
	FROM gn_monitoring.t_base_sites tbs
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	WHERE id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
),visits as (
SELECT
	s.transect,
	s.id_visit_ila,
	s.id_digitiser,
	s.visit_date_min
FROM gn_imports.ila_import s
GROUP BY 	 
	s.transect,
	s.id_digitiser,
	s.id_visit_ila,
	s.visit_date_min
)
INSERT INTO  gn_monitoring.t_base_visits 
(
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
	ila_transect.id_base_site,
	1343, -- id_dataset commun à toutes les données : à modifier en fonction du module / voir les métadonnées
	33 , -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
	visits.id_digitiser,
	visits.visit_date_min,
	visits.visit_date_min,
    -- Il faut potentiellement modifier les valeurs des nomenclatures en fonction du suivi
	240 ,
	132 ,
	visits.id_visit_ila 
FROM visits
LEFT JOIN ila_transect on ila_transect.base_site_name = visits.transect
;
-- Récupération de l'id_base_visit
UPDATE gn_imports.ila_import s
SET id_base_visit = tbv.id_base_visit
FROM  gn_monitoring.t_base_visits tbv
WHERE tbv.comments = s.id_visit_ila::text
AND tbv.id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
;
SELECT id_base_visit FROM gn_imports.ila_import s
GROUP BY s.id_base_visit
;
-- Remplissage des données supplémentaires au format jsonb
WITH nomen_cn as (
	SELECT
		id_nomenclature as id_nomenclature_cn,
		mnemonique as cn
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 173
),
nomen_tp as (
	SELECT
		id_nomenclature as id_nomenclature_tp,
		mnemonique as tp
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 172
),
nomen_vt as (
	SELECT
		id_nomenclature as id_nomenclature_vt,
		mnemonique as vt
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 183
)
INSERT INTO gn_monitoring.t_visit_complements (
	id_base_visit,
	data
)
SELECT 
	id_base_visit,
	jsonb_strip_nulls(
		jsonb_build_object(
			'annee', s.annee,
			'id_horaire_meteo', s.id_visit_ila,
			'num_passage', s.num_passage,
			'id_nomenclature_cn', nomen_cn.id_nomenclature_cn,
			'id_nomenclature_tp', nomen_tp.id_nomenclature_tp,
			'id_nomenclature_vt', nomen_vt.id_nomenclature_vt,
			'source', 'Intranet SER',
			'heure_debut', STRING_AGG(DISTINCT s.heure_min, ', '),
			'habitat', STRING_AGG(DISTINCT s.habitat, ', '),
			'gestion',  STRING_AGG(DISTINCT s.gestion, ', '),
			'impact', STRING_AGG(DISTINCT s.impact, ', ')
		)
	) as data
FROM gn_imports.ila_import s
LEFT JOIN nomen_cn USING (cn)
LEFT JOIN nomen_tp USING (tp)
LEFT JOIN nomen_vt USING (vt)
GROUP BY 
	s.id_base_visit,
	s.id_visit_ila,
	s.annee,
	s.num_passage,
	nomen_cn.id_nomenclature_cn,
	nomen_tp.id_nomenclature_tp,
	nomen_vt.id_nomenclature_vt
;
-- Ajout des observateurs rattachés aux passages
INSERT INTO gn_monitoring.cor_visit_observer (
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	id_digitiser
FROM gn_monitoring.t_base_visits tbv
WHERE tbv.id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
ON CONFLICT DO NOTHING
;
```

Le code pour la mise à jour des transects avec les informations du dernier passage est le suivant:

```sql
WITH lv AS 
(SELECT
	tbv.id_base_site,
	LAST_VALUE(tvc.data ->> 'habitat')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_habitat,
 	LAST_VALUE(tvc.data ->> 'gestion')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_gestion,
 	LAST_VALUE(tvc.data ->> 'impact')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_impact
FROM gn_monitoring.t_base_visits tbv
LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
WHERE id_module = 33
 ), sd as (
	SELECT
		lv.id_base_site,
		jsonb_build_object(
			'habitat',lv.last_habitat,
			'gestion', lv.last_gestion,
			'impact', lv.last_impact
		) as data
	FROM lv
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	WHERE tsc.id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
	GROUP BY id_base_site,last_habitat, last_gestion, last_impact, tsc.data
	ORDER BY id_base_site
)
UPDATE gn_monitoring.t_site_complements tsc
SET data = sd.data
FROM sd
WHERE sd.id_base_site = tsc.id_base_site
;
```

Les **observations** sont créées en 3 étapes :
- Création des observations avec les champs génériques de GN `gn_monitoring.t_observations`,
- Mise à jour de la couche d'import avec les identifiants GN,
- Ajout de données additionnelles `gn_monitoring.t_observation_complements`.

```sql
-- Création des observations
INSERT INTO gn_monitoring.t_observations(
	id_base_visit,
	cd_nom,
	comments
)
SELECT 
	i.id_base_visit,
	i.cd_nom,
	i.id_obs_ila
FROM gn_imports.ila_import i
GROUP BY
	i.id_base_visit,
	i.cd_nom,
	i.id_obs_ila
ORDER BY i.id_base_visit, i.id_obs_ila
;
-- Récupération des id_observation
UPDATE gn_imports.ila_import i
SET id_observation = o.id_observation
FROM gn_monitoring.t_observations o
LEFT JOIN gn_monitoring.t_base_visits v USING (id_base_visit)
WHERE v.id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
AND i.id_obs_ila::text = o.comments
;
-- Ajout des données complémentaires
-- Il faut potentiellement modifier les valeurs des nomenclatures en fonction du suivi
INSERT INTO gn_monitoring.t_observation_complements (
	id_observation,
	data
)
SELECT
	id_observation,
	jsonb_strip_nulls(
		jsonb_build_object(
			'effectif', min(i.effectif),
			'nb_male', min(i.nb_male),
			'nb_femelle', min(i.nb_femelle),
			'determiner', min(i.determiner),
			'id_obs_mysql', i.id_obs_ila,
			'id_nomenclature_obs_technique', 37,
			'id_nomenclature_determination_method', 453,
			'id_nomenclature_type_count', 89,
			'id_nomenclature_obj_count', 143
		)
	) as data
FROM gn_imports.ila_import i
GROUP BY i.id_observation, i.id_obs_ila
ORDER BY i.id_observation
;
```

Pour la plupart des protocoles du CENN, le niveau observation_details n'est pas atteint. La dernière étape consiste à nettoyer les champs commentaires utilisés pour conserver les identifiants MySql lors des intégrations :

```sql
WITH obs as (
	SELECT
		id_observation,
		STRING_AGG(DISTINCT obs_comment, ', ') as commentaire
	FROM gn_imports.ila_import
	GROUP BY id_observation
)
UPDATE gn_monitoring.t_observations o
SET comments = obs.commentaire
FROM obs
WHERE o.id_observation = obs.id_observation
;
WITH vis as (
	SELECT
		id_base_visit,
		STRING_AGG(DISTINCT visit_comment, ', ') as commentaire
	FROM gn_imports.ila_import
	GROUP BY id_base_visit
)
UPDATE gn_monitoring.t_base_visits v
SET comments = vis.commentaire
FROM vis
WHERE v.id_base_visit = vis.id_base_visit
AND v.id_module = 33 -- id_module : à modifier en fonction du module / voir table gn_commons.t_modules
; 
```
