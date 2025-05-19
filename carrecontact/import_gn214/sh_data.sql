 DROP VIEW IF EXISTS steli_sterf.sh_pr_gn;
 CREATE VIEW steli_sterf.sh_pr_gn AS
 SELECT
	-- groupe de site
	sh.ID_Site AS id_site,
	i.Nom_Inventeur AS observateur,
	-- site
	-- CONCAT(sh.ID_Site,sh.Plot,  sh.Transect ) AS id_unique_plot
	sh.Transect AS transect,
	sh.Plot AS plot,
	c.Date as time_plot,
	c.Piquet AS piquet,
	c.Coord_X AS coord_x,
	c.Coord_Y AS coord_y,
	c.Longitude AS longitude,
	c.Latitude AS latitude,
	c.Observation AS site_comment,
	-- visite
	sh.Annee AS annee,
	sh.Date AS time_suivi,
	sh.Quadrat AS quadrat,
	sh.ID_Suivi_Habitat AS id_suivi_habitat,
	sh.inventeurmysql AS inventeur_mysql,
	sh.Taux_Recouvrement AS taux_recouvrement,
	sh.Hauteur_Vegetation AS hauteur_vegetation,
	-- observations
	sh.Taxon AS nom_cite,
	sh.ID_Taxon AS id_taxon,
	sh.Coefficient AS coefficient,
	sh.strate_bryolichenique,
	-- Analyse
	cb.type_biologique,
	cd.type_dynamique,
	cl.H2O_AP AS h2O_ap,
	cl.PH_AP AS ph_ap,
	cl.TROPHIE_AP AS trophie_ap,
	cl.HUMUS_AP AS humus_ap,
	cl.GRANULOMETRIE_AP AS granulometrie_ap,
	cl.LUMINOSITE_AP AS luminosite_ap,
	cl.SALINITE_AP AS salinite_ap,
	sy.Appartenance_Phyto AS appartenance_phyto,
	sy.Code_Appartenance AS code_appartenance,
	sy.classe_ETEA AS classe_etea,
	sy.Code_Etea AS code_etea,
	sy.`ordre ETALIA` AS ordre_etalia,
	sy.Code_Etalia AS code_etalia,
	sy.`sous-ordre ENALIA` AS sous_ordre_enalia,
	sy.Code_Enalia AS code_enalia,
	sy.`Alliance ION` AS alliance_ion,
	sy.Code_ION AS code_ion,
	sy.`sous-alliance ENION` AS sous_alliance_enion,
	sy.Code_ENION AS code_enion,
	sy.Association_ETUM AS association_etum,
	sy.color_etea,
	-- Autres
	sh.idtaxonodk
FROM steli_sterf.sh_suivi_habitat sh
LEFT JOIN steli_sterf.sh_coord_carre c ON c.Site = sh.ID_Site
LEFT JOIN steli_sterf.sh_inventeur i USING (ID_Inventeur)
LEFT JOIN steli_sterf.sh_ecolo_biologique eb ON sh.ID_Taxon = eb.id_taxon
LEFT JOIN steli_sterf.sh_code_biologique cb USING (code_biologique)
LEFT JOIN steli_sterf.sh_ecolo_dynamique ed ON sh.ID_Taxon = ed.id_taxon
LEFT JOIN steli_sterf.sh_code_dynamique cd USING (code_dynamique)
LEFT JOIN steli_sterf.sh_coef_landolt cl ON cl.Taxon = sh.Taxon
LEFT JOIN steli_sterf.sh_appartenance a ON sh.ID_Taxon = a.ID_Taxon
LEFT JOIN steli_sterf.sh_synsystematique sy ON a.ID_Synsystematique = sy.ID_Synsystematique
WHERE sh.Transect = c.Transect
AND sh.Plot = c.Plot
ORDER BY sh.Date DESC
	