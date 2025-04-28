 CREATE VIEW cenhn.sh_coeff_pr_gn
AS
select 
	tx.ID_Taxon AS ID_Taxon,
	tx.Nom_Complet AS Nom_Complet,
	tx.Appellation AS Appellation,
	tx.Nom_Francais AS Nom_Francais,
	tx.Determination AS Determination,
	tx.Type_Correspondance_TAXREF AS Type_Correspondance_TAXREF,
	tx.Doute_Correspondace_TAXREF AS Doute_Correspondace_TAXREF,
	tx.Code_TAXREF AS Code_TAXREF,
	tx.Taxon_TAXREF AS Taxon_TAXREF,
	tx.Cle_BIF AS Cle_BIF,
	tx.Territoire AS Territoire,
	tx.Statut_Presence AS Statut_Presence,
	tx.Statut_Indigenat_Principal AS Statut_Indigenat_Principal,
	tx.Statut_Indigenat_Secondaire AS Statut_Indigenat_Secondaire,
	tx.Rarete AS Rarete,
	tx.Menace AS Menace,
	tx.Justification_Cotation_Menace AS Justification_Cotation_Menace,
	tx.Usage_Cultural_Prinicpal AS Usage_Cultural_Prinicpal,
	tx.Usage_Cultural_Secondaire AS Usage_Cultural_Secondaire,
	tx.Frequence_Culturale AS Frequence_Culturale,
	tx.Protection_Nationale_A1 AS Protection_Nationale_A1,
	tx.Protection_Nationale_A2 AS Protection_Nationale_A2,
	tx.Protection_Regional AS Protection_Regional,
	tx.Interet_Patrimonial AS Interet_Patrimonial,
	tx.LR_Regional AS LR_Regional,
	tx.ZNIEFF AS ZNIEFF,
	tx.Indicateur_ZH AS Indicateur_ZH,
	tx.Exotique_Envahissante AS Exotique_Envahissante,
	bio.type_biologique AS type_biologique,
	dyn.type_dynamique AS type_dynamique,
	cl.H2O_AP AS landolt_humidite,
	cl.PH_AP AS landolt_reaction,
	cl.TROPHIE_AP AS landolt_subs_nutritive,
	cl.HUMUS_AP AS landolt_humus,
	cl.GRANULOMETRIE_AP AS landolt_granulometrie,
	cl.LUMINOSITE_AP AS landolt_luminosite,
	cl.SALINITE_AP AS landolt_salinite 
from sh_taxref_cbnbl tx 
left join sh_ecolo_biologique eb on(eb.id_taxon = tx.ID_Taxon)
left join sh_code_biologique bio on(eb.code_biologique = bio.code_biologique)
left join sh_ecolo_dynamique ed on(ed.id_taxon = tx.ID_Taxon)
left join sh_code_dynamique dyn on(ed.code_dynamique = dyn.code_dynamique)
left join sh_coef_landolt cl on(cl.ID_Taxon = tx.ID_Taxon)