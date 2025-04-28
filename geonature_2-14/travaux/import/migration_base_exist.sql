INSERT INTO _genie_eco.cor_action_w_com (
	id_action,
	id_area,
	id_municipality,
	insee_com,
	nom_com
)
SELECT 
		act.id_action, 
		la.id_area,
		mun.id_municipality,
		mun.insee_com::integer,
		mun.nom_com
FROM _genie_eco.sce_action_w act
INNER JOIN ref_geo.l_areas la
	ON ST_Intersects(la.geom,act.geom_p)
INNER JOIN ref_geo.li_municipalities mun
	ON la.id_area = mun.id_area
ON CONFLICT DO NOTHING
;

SELECT 
	STRING_AGG(DISTINCT insee_com::text, ' / '),
	STRING_AGG(DISTINCT nom_com, '/ ')
FROM _genie_eco.cor_action_w_com ac
LEFT JOIN _genie_eco.sce_action_w act
	ON ac.id_action = act.id_action
GROUP BY id_site
;

ALTER TABLE _genie_eco.sce_action_w
ADD CONSTRAINT fk_sce_action_w_etat
FOREIGN KEY (etat) 
REFERENCES _genie_eco.sce_etat_fiche (id_etatfiche);


ALTER TABLE _genie_eco.sce_l_materiel_action

ALTER TABLE _genie_eco.sce_etat_fiche 
RENAME id_etatfiche TO id_etat_fiche;

ALTER TABLE _genie_eco.sce_action_w
add constraint ch_sce_action_w_date check (date_debut_r <= date_fin_r);

CREATE SEQUENCE _genie_eco.sce_action_w_id_action_seq ;

SELECT setval('_genie_eco.sce_action_w_id_action_seq', (SELECT max(id_action) FROM _genie_eco.sce_action_w));

ALTER TABLE _genie_eco.sce_action_w 
ALTER COLUMN id_action SET default nextval('_genie_eco.sce_action_w_id_action_seq');

ALTER SEQUENCE IF EXISTS _genie_eco.sce_fiche_w_id_fiche
RENAME TO sce_fiche_w_id_fiche_seq;

DELETE FROM _genie_eco.sce_intervention inter
WHERE NOT EXISTS (
	SELECT 1
	FROM _genie_eco.sce_action_w  act
	WHERE act.id_action = inter.id_action
);

ALTER TABLE _genie_eco.sce_intervention 
ALTER COLUMN id_etat 
TYPE integer USING id_etat::integer;

ALTER TABLE table_name 
DROP COLUMN column_name;

INSERT INTO _genie_eco.cor_trav_class(
	id_genie_eco ,
	id_class 
	)
SELECT
	id_genie_eco,
	classif::integer
	FROM _genie_eco.sce_type_genie_eco
	WHERE NOT classif is NULL
	;
	
COMMENT ON TABLE _genie_eco.t_action IS 'Actions de travaux prévisionnelles et réalisées';

COMMENT ON COLUMN _genie_eco.t_action.id_action IS 'Identifiant unique de l''action';
COMMENT ON COLUMN _genie_eco.t_action.id_fiche IS 'Identifiant faisant le lien avec la fiche travaux';
COMMENT ON COLUMN _genie_eco.t_action.id_etat IS 'Etat de l''action - prévisionnelle ou réalisée, en lien avec la table de nomenclature bib_etat';
COMMENT ON COLUMN _genie_eco.t_action.id_genie_eco_p IS 'Type de travaux prévisionnels (bib_genie_eco)';
COMMENT ON COLUMN _genie_eco.t_action.id_genie_eco_r IS 'Type de travaux réalisés (bib_genie_eco)';
COMMENT ON COLUMN _genie_eco.t_action.id_produit_p IS 'Type de traitement des produits issus des travaux prévisionnel (bib_produit)';
COMMENT ON COLUMN _genie_eco.t_action.id_produit_r IS 'Type de traitement des produits issus des travaux réalisé (bib_produit)';
COMMENT ON COLUMN _genie_eco.t_action.nb_j_p IS 'Nombre de jours prévisionnels';
COMMENT ON COLUMN _genie_eco.t_action.nb_j_r IS 'Nombre de jours réalisés - se calcule automatiquement à partir des champs dates';
COMMENT ON COLUMN _genie_eco.t_action.date_debut_r IS 'Date de début des travaux';
COMMENT ON COLUMN _genie_eco.t_action.date_fin_r IS 'Date de fin des travaux';
COMMENT ON COLUMN _genie_eco.t_action.nom_parcelle IS 'Nom de la parcelle de travaux';
COMMENT ON COLUMN _genie_eco.t_action.geom_p IS 'Localisation et géométrie prévisionnelles des travaux';
COMMENT ON COLUMN _genie_eco.t_action.geom_r IS 'Localisation et géométrie réalisées des travaux';
COMMENT ON COLUMN _genie_eco.t_action.comments_p IS 'Commentaires sur les travaux - état prévisionnel';
COMMENT ON COLUMN _genie_eco.t_action.comments_r IS 'Commentaires sur les travaux - état réalisé';
COMMENT ON COLUMN _genie_eco.t_action.objectif IS 'Objectif de l''action de travaux';
COMMENT ON COLUMN _genie_eco.t_action.bilan IS 'Bilan de l''action de travaux';
COMMENT ON COLUMN _genie_eco.t_action.out_borders_p IS 'Colonne permettant de vérifier que la géométrie prévisionnelle de l''action est incluse dans le site lié';
COMMENT ON COLUMN _genie_eco.t_action.out_borders_r IS 'Colonne permettant de vérifier que la géométrie réalisée de l''action est incluse dans le site lié';

COMMENT ON TABLE _genie_eco.t_fiche IS 'Fiche regroupant les travaux prévisionnels et réalisés pour une année et un site CEN';

COMMENT ON COLUMN _genie_eco.t_fiche.id_fiche IS 'Identifiant unique la fiche travaux';
COMMENT ON COLUMN _genie_eco.t_fiche.annee IS 'Année des travaux';
COMMENT ON COLUMN _genie_eco.t_fiche.id_w_tab IS 'Identifiant utilisé par l''application BD TRAVAUX de SER';
COMMENT ON COLUMN _genie_eco.t_fiche.code_analytique_p IS 'Code analytique utilisé par l''application BD TRAVAUX de SER - état prévisionnel';
COMMENT ON COLUMN _genie_eco.t_fiche.code_analytique_r IS 'Code analytique utilisé par l''application BD TRAVAUX de SER - état réalisé';
COMMENT ON COLUMN _genie_eco.t_fiche.nb_j_global_p IS 'Nombre de jours de l''ensemble des actions rattachées à la riche - état prévisionnel';
COMMENT ON COLUMN _genie_eco.t_fiche.nb_j_global_r IS 'Nombre de jours de l''ensemble des actions rattachées à la riche - état réalisé';
COMMENT ON COLUMN _genie_eco.t_fiche.comments IS 'Commentaires sur la fiche travaux, notamment pour détailler les objectifs';
COMMENT ON COLUMN _genie_eco.t_fiche.bilan IS 'Réajustements pour l''année prochaine découlant du bilan';
COMMENT ON COLUMN _genie_eco.t_fiche.sur_tot_p IS 'Surface totale des géométries prévisionnelles des actions rattachées à la fiche travaux';
COMMENT ON COLUMN _genie_eco.t_fiche.sur_tot_r IS 'Surface totale des géométries réalisées des actions rattachées à la fiche travaux';
COMMENT ON COLUMN _genie_eco.t_fiche.id_etat IS 'Etat de la fiche (en lien avec bib_etat)';
COMMENT ON COLUMN _genie_eco.t_fiche.old_id_site IS 'Identifiant du site CEN dans la base de SER';
COMMENT ON COLUMN _genie_eco.t_fiche.id_objectif IS 'Grand type d''objectif - rattaché à bib_objectif';