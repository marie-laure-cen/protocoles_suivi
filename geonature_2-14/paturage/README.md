# PATURAGE

## Résumé / Summary

Ce module assure le suivi du pâturage sur les sites du CEN Normandie.

- Le niveau **site_group** correspond à une fiche pâturage annuelle du site.
- Le niveau **site** s'intéresse à chaque aire de pâturage et ses caractéristiques (état prévisionnel et réalisé),
- Le niveau **visit** correspond au cheptel.

This plugin follows grazing in CEN Normandie's sites.

- The **site_group** level is a summary of grazing actions on a site during one year.
- The **site** level is composed of grazing areas, their features and traits (forecast and achieved status).
- The **visit** level concern livestock.

**This plugin is in French.**

Documentation : [gn_monitoring/sub_module](https://github.com/PnX-SI/gn_module_monitoring/blob/main/docs/sous_module.md)

## Evolution du module / Plugin development

Evolutions à effectuer :

- Ajouter des outils de duplication des fiches (d'une année sur l'autre) et des parcelles (état prévisionnel -> état réalisé)
- Ajouter un lien avec les données ref_geo et avec occ_hab (type_util).

Developments:

- Add duplicating tools (site_group => one year to another / site => forecast to achieved)
- Add links to ref_geo and occ_hab data (type_util).


## Structure du module

### Niveau sites_group

La fiche pâturage est composée des éléments suivants :
- "site_cen" : Site du CEN rattaché à la fiche pâturage [champ ajouté]
- "sites_group_code" : code de la fiche pâturage  [champ par défaut]
- "etat" : état prévisionnel ou réalisé de la fiche pâturage  [champ ajouté - nomenclature ajoutée]
- "annee" : année du pâturage  [champ ajouté],
- "admin" : composante administrative dans laquelle est comprise le site CEN  [champ ajouté] => se calcul automatiquement en base *A développer*
- "id_numerisateur" : numérisateur de la fiche pâturage [champ ajouté - lien avec utilisateurs] / normalement CM en charge du site
- "code_analytique" : lien avec progecen? [champ ajouté]
- "milieux" : liste des milieux du site CEN [champ ajouté] => se remplit automatiquement à partir des données OccHab *A développer*
- "surface_totale" : somme de la surface de pâturage des parcelles [champ ajouté] => se calcule automatiquement à partir des parcelles *A développer*
- "nb_jours_total" : somme des jours pâturés [champ ajouté] => se calcule automatiquement à partir des parcelles *A développer*
- "objectif" : grands objectifs de gestion [champ ajouté] => est rappatrié depuis le site CEN *A développer*
- "comments" : zone de texte libre [champ par défaut]
- "nb_sites" : nombre de parcelles liées à la fiche [champ par défaut]

Lors de plusieurs saisies à la suite, les valeurs des champs suivants sont conservés : "id_numerisateur", "annee". 
Les fiches pâturage sont triées par année décroissante puis par nom de site du CEN *à ajouter*.

### Niveau site

La fiche parcelle (ou parc) est composée des éléments suivants :
- "id_sites_group" : reprend l'identifiant de la fiche pâturage [champ par défaut] *à masquer ?*
- "base_site_name" : nom de la parcelle de pâturage [champ par défaut]
- "etat" : état prévisionnel ou réalisé de la fiche parcelle [champ ajouté - nomenclature ajoutée]
- "surface_m2" : surface en mètres carrés de la parcelle pâturée [champ ajouté] => se calcule automatiquement en base à partir de la géométrie *A développer*
- "surface_ha" : traduction de la surface en hectares [champ ajouté] => se calcule automatiquement à partir de la valeur ci-dessus *A développer*
- "intervenant" : liste des intervenants (choix multiples) [champ ajouté - nomenclature ajoutée]
-"ugb_parc" : UGB totale de la parcelle [champ ajouté] => se calcule automatiquement en base (?) à partir des éléments de cheptel *A développer*
- "duree" : durée totale du pâturage sur la parcelle [champ ajouté] => se calcule automatiquement en base (?) à partir des éléments de cheptel *A développer*
- "objectif" : grands objectifs de gestion du pâturage sur la parcelle [champ ajouté - nomenclature ajoutée] (choix multiples)
- "resultat" : résultat du pâturage [champ ajouté - nomenclature ajoutée] => est masqué à l'état prévisionnel *A faire*
- "reajust":  réajustements à effectuer [champ ajouté - nomenclature ajoutée] => est masqué à l'état prévisionnel + si le résultat est satisfaisant *A faire*
- "comment" : texte libre [champ par défaut]

Lors de plusieurs saisies à la suite, la valeur du champ "etat" est conservée. Les fiches parcelles sont triées dans l'ordre de leur numérisation.

### Niveau visit

La fiche cheptel est composée des éléments suivants :

- "type_cheptel" : correspond au type d'animaux du cheptel [champ ajouté - nomenclature ajoutée]
- "nb_animaux" : correspond au nombre d'animaux du cheptel [champ ajouté]
- "nb_j_pat" : correspond au nombre de jour de pâturage avec ce cheptel [champ ajouté] => se calcul automatiquement avec les dates *développement effectué => commande change*
- "visit_date_min" : correspond à la date de début du pâturage par le cheptel [champ par défaut]
- "visit_date_max" : correspond à la date de fin du pâturage par le cheptel [champ par défaut]
- "etat_sanit_min" : correspond à l'état sanitaire d'arrivée du cheptel [champ ajouté - nomenclature ajoutée]
- "etat_sanit_max" : correspond à l'état sanitaire d'arrivée du cheptel [champ ajouté - nomenclature ajoutée] => valeur par défaut = etat_sanit_min jusqu'à modification *A faire*
- "ugb" : correspond à la valeur d'Unité Gros Bétail du cheptel [champ ajouté] => se calcul automatiquement en base *Développement à faire*
- "comments" : zone de texte libre [champ par défaut]

Les fiches cheptel sont organisées par date de début de pâturage.
