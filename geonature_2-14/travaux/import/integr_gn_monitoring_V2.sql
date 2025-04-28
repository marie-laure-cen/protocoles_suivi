-- Sites Travaux Rouen
WITH site as 
(SELECT * FROM ref_geo.l_areas WHERE id_type in (12,34,37))
SELECT
	area_code || '_' || annee,
	area_name,
	ARRAY_AGG(id_fiche)
FROM _genie_eco.t_fiche
LEFT JOIN _genie_eco.cor_t_fiche_site USING (id_fiche)
LEFT JOIN site USING (area_code)
WHERE NOT annee IS NULL
GROUP BY area_code, area_name, annee
ORDER BY area_code, annee
;

-- Fiche travaux

-- Fiche action