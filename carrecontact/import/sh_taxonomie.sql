SELECT
	f.id_taxon,
	f.nom_complet AS nom_cbnb,
	f.taxon_taxref AS nom_taxref,
	f.code_taxref,
	b.type_biologique,
	d.type_dynamique,
	s.Appartenance_Phyto,
	s.Code_Appartenance,
	s.classe_ETEA,
	s.Code_Etea,
	s.`ordre ETALIA`,
	s.Code_Etalia,
	s.`sous-ordre ENALIA`,
	s.Code_Enalia,
	s.`Alliance ION`,
	s.Code_ION,
	s.`sous-alliance ENION`,
	s.Code_ENION,
	s.Association_ETUM,
	s.color_etea,
	c.H2O_AP,
	c.PH_AP,
	c.TROPHIE_AP,
	c.HUMUS_AP,
	c.HUMUS_AP,
	c.GRANULOMETRIE_AP,
	c.LUMINOSITE_AP,
	c.SALINITE_AP
FROM steli_sterf.sh_referentiel_flore f
LEFT JOIN steli_sterf.sh_ecolo_biologique eb USING (id_taxon)
LEFT JOIN steli_sterf.sh_code_biologique b USING (code_biologique)
LEFT JOIN steli_sterf.sh_ecolo_dynamique ed USING (id_taxon)
LEFT JOIN steli_sterf.sh_code_dynamique d USING (code_dynamique)
LEFT JOIN steli_sterf.sh_appartenance a USING (id_taxon)
LEFT JOIN steli_sterf.sh_synsystematique s USING (ID_Synsystematique)
LEFT JOIN steli_sterf.sh_coef_landolt c ON c.Taxon = f.nom_complet
ORDER BY id_taxon