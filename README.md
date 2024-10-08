# Modules de suivi pour le GeoNature du CENN Normandie

## Intégration des données pré-existantes

La démarche suivante se base sur le protocole ILA, anciennement hébergé sur une base MySql.

```sql
DROP VIEW steli_sterf.ila_pr_gn ;
CREATE VIEW steli_sterf.ila_pr_gn AS
SELECT
-- TRANSECT
	o.ID_Transect AS id_transect_ila,
	t.Nom_Transect AS transect,
-- VISITES
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
-- OBSERVATIONS
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