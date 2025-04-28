WITH
mat_p as (
	SELECT
		id_action,
		array_agg( type_materiel) FILTER (WHERE NOT type_materiel is null) as materiel_p,
		array_agg( autre_materiel) FILTER (WHERE NOT autre_materiel is null) as autre_materiel_p
	FROM bd_travaux.l_materiel_action
	LEFT JOIN bd_travaux.materiel USING (id_materiel)
	WHERE etat_action = '2' 
	GROUP BY id_action
),
mat_r as (
	SELECT
		id_action,
		array_agg( type_materiel ) FILTER (WHERE NOT type_materiel is null) as materiel_r,
		array_agg( autre_materiel ) FILTER (WHERE NOT autre_materiel is null) as autre_materiel_r
	FROM bd_travaux.l_materiel_action
	LEFT JOIN bd_travaux.materiel USING (id_materiel)
	WHERE etat_action = '3' 
	GROUP BY id_action
),
act as (
	SELECT
		act.id_action,	
		it.id_intervention,
		act.id_site,
		act.nom_parcelle,
		ea.etat_fiche as etat, 
		act.nb_j_p, 
		act.nb_j_r, 
		i.type_intervenant,
		it.autre_intervenant,
		wp.type_w as type_w_p, 
		wr.type_w as type_w_r,
		cp.classe as classe_w_p,
		cr.classe as classe_w_r,
		mat_p.materiel_p,
		mat_p.autre_materiel_p,
		mat_r.materiel_r,
		mat_r.autre_materiel_r,
		pp.type_produit as type_pdt_p, 
		pr.type_produit as type_pdt_r,
		act.date_debut_r, 
		act.date_fin_r,  
		act.remarque_p, 
		act.remarque_r, 
		act.bilan_p, 
		act.bilan_r, 
		act.out_borders_p, 
		act.out_borders_r,
		act.geom_p, 
		act.geom_r
	FROM bd_travaux.intervention it
	LEFT JOIN bd_travaux.intervenant i ON it.id_intervenant = i.id_intervenant
	LEFT JOIN bd_travaux.action_w act USING (id_action)
	LEFT JOIN bd_travaux.etat_fiche ea ON act.etat = ea.id_etatfiche
	LEFT JOIN bd_travaux.type_w wp ON act.type_w_p = wp.id_type_w
	LEFT JOIN bd_travaux.classif_type_w cp ON wp.classif::integer = cp.id_classfication
	LEFT JOIN bd_travaux.type_w wr ON act.type_w_r = wr.id_type_w
	LEFT JOIN bd_travaux.classif_type_w cr ON wr.classif::integer = cr.id_classfication
	LEFT JOIN bd_travaux.type_produit pp ON act.type_pdt_p = pp.id_type_produit
	LEFT JOIN bd_travaux.type_produit pr ON act.type_pdt_r = pr.id_type_produit
	LEFT JOIN mat_p USING (id_action)
	LEFT JOIN mat_r USING (id_action)
	--LEFT JOIN md.site_cenhn sa ON sa."ID"::integer = act.id_site
	WHERE NOT act.etat IS NULL
	)
SELECT
	f.id_fiche_w,  
	f.id_w_tab, 
	f.id_site, 
	f.num_insee, 
	f.nom_site, 
	f.annee,
	f.code_analytique_p, 
	f.code_analytique_r, 
	f.nb_j_global_p, 
	f.nb_j_global_r, 
	f.objectifs, 
	f.bilan, 
	f.reajustements, 
	f.sur_tot_p, 
	f.sur_tot_r, 
	f.etat_fiche,
	act.*
FROM bd_travaux.fiche_w f
LEFT JOIN act ON f.id_fiche_w = act.id_site
WHERE not f.id_fiche_w IS NULL  and not f.id_w_tab IS NULL and not f.nom_site ='NEW'
ORDER BY id_fiche_w DESC--, id_action DESC, id_intervention DESC

--Qgis création sites
to_json( 
    map(
        'id_action',  "id_action" 
	)
)

INSERT INTO gn_monitoring.t_site_complements (
	id_base_site,
	id_module,
	id_sites_group
)
SELECT
	id_base_site,
	35,
	(base_site_description::jsonb -> 'id_sites_group')::integer
FROM gn_monitoring.t_base_sites
WHERE id_nomenclature_type_site = 790 and not lower(base_site_name) = 'test'
;

INSERT INTO gn_monitoring.cor_site_module (
	id_base_site,
	id_module
)
SELECT
	id_base_site,
	35
FROM gn_monitoring.t_base_sites
WHERE id_nomenclature_type_site = 790 and not lower(base_site_name) = 'test'
;

-- Qgis

to_json( 
map(
	'id_action',  "id_action" ,
	'id_sites_group', "id_sites_group" ,
	'etat', 
	If( "etat_action" = 'Previsionnelle' , 'Prévisionnel', 'Réalisé'),
	'annee', If(  "an_fiche" IS NULL, '', "an_fiche" ),
	'objectif_sicen', If(   "obj_fiche" IS NULL, '', "obj_fiche"),
	'result_sicen', If(   "bilan_fiche" IS NULL, '', "bilan_fiche"),
	'reajust_sicen', If(   "reaj_fiche" IS NULL, '', "reaj_fiche"), 
	'classe_travaux', if("class_w" IS NULL, '' ,  "class_w" ),
	'nb_jours',  "nb_j_fiche" ,
	'surface_m2', if("surface_m2" IS NULL, '',  "surface_m2" )
)
)