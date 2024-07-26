-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------
-- Export des transects -------------------------
-------------------------------------------------

DROP VIEW  IF EXISTS  gn_monitoring.v_export_sterf_transect;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_transect AS
SELECT
	tbs.id_base_site,
	taf.id_dataset,
	tsg.sites_group_name as area_code,
	(r.nom_role || ' ' || r.prenom_role) as responsable,
	tbs.base_site_code as transect_code,
	tbs.base_site_name  as transect_name,
	tbs.altitude_min,
	tbs.altitude_max,
	tbs.geom_local as geom,
	ST_CENTROID(tbs.geom) AS centroid,
	St_AsText(tbs.geom) AS geom_wkt
FROM gn_monitoring.t_base_sites tbs
LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
LEFT JOIN utilisateurs.t_roles r ON (tsg.data->'id_resp' )::integer = id_role
LEFT JOIN gn_meta.cor_acquisition_framework_site caf ON tsg.sites_group_name = caf.area_code
LEFT JOIN gn_meta.t_datasets taf ON taf.id_acquisition_framework = caf.id_acquisition_framework
LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name = la.area_code
WHERE tsg.id_module = 32 AND lower(taf.dataset_name ) LIKE '%faune%'
OR tsg.id_module = 32 AND lower(taf.dataset_name) LIKE '%taxon%'
ORDER BY area_code, transect_name
;

-------------------------------------------------
-- Export de l'ensemble des observations --------
-------------------------------------------------

DROP VIEW gn_monitoring.v_export_sterf_obs;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_obs
 AS
 WITH 
 	milieux as (
		SELECT
			cd_ref,
			valeur_attribut as id_milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN 'ubiquistes'
			WHEN valeur_attribut ='II' THEN 'boisements'
			WHEN valeur_attribut ='III' THEN 'zones humides'
			WHEN valeur_attribut ='IV' THEN 'prairies mésophiles'
			WHEN valeur_attribut ='V' THEN 'milieux secs'
			WHEN valeur_attribut ='VI' THEN 'migratrices'
			ELSE NULL
			END as milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN '#d9d9d9'
			WHEN valeur_attribut ='II' THEN '#548235'
			WHEN valeur_attribut ='III' THEN '#9bc2e6'
			WHEN valeur_attribut ='IV' THEN '#e2efda'
			WHEN valeur_attribut ='V' THEN '#ffc000'
			WHEN valeur_attribut ='VI' THEN '#ccccff'
			ELSE NULL
			END as couleur
		FROM taxonomie.cor_taxon_attribut
		WHERE id_attribut = 43
	),
 	tr AS (
         SELECT tbs.id_base_site,
            taf.id_dataset,
            taf.dataset_name,
            tsg.sites_group_name AS site_code,
            la.area_name AS site_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN gn_meta.cor_acquisition_framework_site caf ON tsg.sites_group_name::text = caf.area_code
             LEFT JOIN gn_meta.t_datasets taf ON taf.id_acquisition_framework = caf.id_acquisition_framework
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%faune%'::text OR tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%taxon%'::text
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 32
        ), obs AS (
         SELECT o.id_observation,
            o.id_base_visit,
            o.cd_nom,
            tx.nom_valide,
            tx.nom_vern,
            o.comments,
            toc.data,
			mil.*
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
			LEFT JOIN milieux mil USING (cd_ref)
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT obs.id_observation,
    tr.id_dataset,
    tr.dataset_name,
    tr.site_code,
    tr.site_name,
    tr.transect_name,
    (pass.data -> 'annee'::text)::integer AS pass_annee,
    (pass.data -> 'num_passage'::text)::integer AS pass_num,
    pass.pass_date,
    (pass.data -> 'heure_debut'::text)::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data -> 'occ_sol'::text)::text AS pass_os1,
    (pass.data -> 'occ_sol_detail'::text)::text AS pass_os2,
    (pass.data -> 'hab_1'::text)::text AS pass_hab1,
    (pass.data -> 'hab_2'::text)::text AS pass_hab2,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying) AS temperature,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying) AS couv_nuageuse,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying) AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
	obs.id_milieu,
	obs.milieu,
    (obs.data -> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
    obs.comments AS commentaire,
	obs.couleur,
    tr.id_base_site,
    pass.id_base_visit,
    (pass.data -> 'source'::text)::text AS source_donnee,
    obs.data -> 'id_obs_mysql'::text AS id_obs_mysql,
    tr.altitude_min,
    tr.altitude_max,
    tr.geom,
    tr.centroid,
    tr.geom_wkt
   FROM obs
     LEFT JOIN observers USING (id_base_visit)
     LEFT JOIN pass USING (id_base_visit)
     JOIN tr USING (id_base_site)
  ORDER BY tr.site_code, tr.transect_name, ((pass.data -> 'annee'::text)::integer) DESC, ((pass.data -> 'num_passage'::text)::integer) DESC, obs.nom_valide;
;

-------------------------------------------------
-- Export des obs années n et n-1 ---------------
-------------------------------------------------

DROP VIEW  IF EXISTS  gn_monitoring.v_export_sterf_obs_n;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_obs_n AS
WITH 
	milieux as (
		SELECT
			cd_ref,
			valeur_attribut as id_milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN 'ubiquistes'
			WHEN valeur_attribut ='II' THEN 'boisements'
			WHEN valeur_attribut ='III' THEN 'zones humides'
			WHEN valeur_attribut ='IV' THEN 'prairies mésophiles'
			WHEN valeur_attribut ='V' THEN 'milieux secs'
			WHEN valeur_attribut ='VI' THEN 'migratrices'
			ELSE NULL
			END as milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN '#d9d9d9'
			WHEN valeur_attribut ='II' THEN '#548235'
			WHEN valeur_attribut ='III' THEN '#9bc2e6'
			WHEN valeur_attribut ='IV' THEN '#e2efda'
			WHEN valeur_attribut ='V' THEN '#ffc000'
			WHEN valeur_attribut ='VI' THEN '#ccccff'
			ELSE NULL
			END as couleur
		FROM taxonomie.cor_taxon_attribut
		WHERE id_attribut = 43
	),
 	tr AS (
         SELECT tbs.id_base_site,
            taf.id_dataset,
            taf.dataset_name,
            tsg.sites_group_name AS site_code,
            la.area_name AS site_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN gn_meta.cor_acquisition_framework_site caf ON tsg.sites_group_name::text = caf.area_code
             LEFT JOIN gn_meta.t_datasets taf ON taf.id_acquisition_framework = caf.id_acquisition_framework
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%faune%'::text OR tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%taxon%'::text
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 32
        ), obs AS (
         SELECT o.id_observation,
            o.id_base_visit,
            o.cd_nom,
            tx.nom_valide,
            tx.nom_vern,
            o.comments,
            toc.data,
			mil.*
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
			LEFT JOIN milieux mil USING (cd_ref)
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT obs.id_observation,
    tr.id_dataset,
    tr.dataset_name,
    tr.site_code,
    tr.site_name,
    tr.transect_name,
    (pass.data -> 'annee'::text)::integer AS pass_annee,
    (pass.data -> 'num_passage'::text)::integer AS pass_num,
    pass.pass_date,
    (pass.data -> 'heure_debut'::text)::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data -> 'occ_sol'::text)::text AS pass_os1,
    (pass.data -> 'occ_sol_detail'::text)::text AS pass_os2,
    (pass.data -> 'hab_1'::text)::text AS pass_hab1,
    (pass.data -> 'hab_2'::text)::text AS pass_hab2,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying) AS temperature,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying) AS couv_nuageuse,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying) AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
	obs.id_milieu,
	obs.milieu,
    (obs.data -> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
    obs.comments AS commentaire,
	obs.couleur,
    tr.id_base_site,
    pass.id_base_visit,
    (pass.data -> 'source'::text)::text AS source_donnee,
    obs.data -> 'id_obs_mysql'::text AS id_obs_mysql,
    tr.altitude_min,
    tr.altitude_max,
    tr.geom,
    tr.centroid,
    tr.geom_wkt
   FROM obs
     LEFT JOIN observers USING (id_base_visit)
     LEFT JOIN pass USING (id_base_visit)
     JOIN tr USING (id_base_site)
WHERE (pass.data -> 'annee')::integer = extract(year from now() )
ORDER BY site_code, transect_name, pass_annee DESC, pass_num DESC, nom_valide
;

DROP VIEW  IF EXISTS  gn_monitoring.v_export_sterf_obs_n1;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_obs_n1 AS
WITH 
	milieux as (
		SELECT
			cd_ref,
			valeur_attribut as id_milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN 'ubiquistes'
			WHEN valeur_attribut ='II' THEN 'boisements'
			WHEN valeur_attribut ='III' THEN 'zones humides'
			WHEN valeur_attribut ='IV' THEN 'prairies mésophiles'
			WHEN valeur_attribut ='V' THEN 'milieux secs'
			WHEN valeur_attribut ='VI' THEN 'migratrices'
			ELSE NULL
			END as milieu,
			CASE 
			 WHEN valeur_attribut ='I' THEN '#d9d9d9'
			WHEN valeur_attribut ='II' THEN '#548235'
			WHEN valeur_attribut ='III' THEN '#9bc2e6'
			WHEN valeur_attribut ='IV' THEN '#e2efda'
			WHEN valeur_attribut ='V' THEN '#ffc000'
			WHEN valeur_attribut ='VI' THEN '#ccccff'
			ELSE NULL
			END as couleur
		FROM taxonomie.cor_taxon_attribut
		WHERE id_attribut = 43
	),
 	tr AS (
         SELECT tbs.id_base_site,
            taf.id_dataset,
            taf.dataset_name,
            tsg.sites_group_name AS site_code,
            la.area_name AS site_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN gn_meta.cor_acquisition_framework_site caf ON tsg.sites_group_name::text = caf.area_code
             LEFT JOIN gn_meta.t_datasets taf ON taf.id_acquisition_framework = caf.id_acquisition_framework
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%faune%'::text OR tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%taxon%'::text
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 32
        ), obs AS (
         SELECT o.id_observation,
            o.id_base_visit,
            o.cd_nom,
            tx.nom_valide,
            tx.nom_vern,
            o.comments,
            toc.data,
			mil.*
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
			LEFT JOIN milieux mil USING (cd_ref)
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT obs.id_observation,
    tr.id_dataset,
    tr.dataset_name,
    tr.site_code,
    tr.site_name,
    tr.transect_name,
    (pass.data -> 'annee'::text)::integer AS pass_annee,
    (pass.data -> 'num_passage'::text)::integer AS pass_num,
    pass.pass_date,
    (pass.data -> 'heure_debut'::text)::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data -> 'occ_sol'::text)::text AS pass_os1,
    (pass.data -> 'occ_sol_detail'::text)::text AS pass_os2,
    (pass.data -> 'hab_1'::text)::text AS pass_hab1,
    (pass.data -> 'hab_2'::text)::text AS pass_hab2,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying) AS temperature,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying) AS couv_nuageuse,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying) AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
	obs.id_milieu,
	obs.milieu,
    (obs.data -> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
    obs.comments AS commentaire,
	obs.couleur,
    tr.id_base_site,
    pass.id_base_visit,
    (pass.data -> 'source'::text)::text AS source_donnee,
    obs.data -> 'id_obs_mysql'::text AS id_obs_mysql,
    tr.altitude_min,
    tr.altitude_max,
    tr.geom,
    tr.centroid,
    tr.geom_wkt
   FROM obs
     LEFT JOIN observers USING (id_base_visit)
     LEFT JOIN pass USING (id_base_visit)
     JOIN tr USING (id_base_site)
WHERE (pass.data -> 'annee')::integer = (extract(year from now() ) - 1 )
ORDER BY site_code, transect_name, pass_num DESC, nom_valide
;


-------------------------------------------------
-- Export des obs sans géométrie ac statuts -----
-------------------------------------------------
DROP VIEW gn_monitoring.v_export_sterf_obs_2;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_obs_2 AS
 WITH milieux AS (
         SELECT cor_taxon_attribut.cd_ref,
            cor_taxon_attribut.valeur_attribut AS id_milieu,
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I'::text THEN 'ubiquistes'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'II'::text THEN 'boisements'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'III'::text THEN 'zones humides'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV'::text THEN 'prairies mésophiles'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'V'::text THEN 'milieux secs'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI'::text THEN 'migratrices'::text
                    ELSE NULL::text
                END AS milieu,
                CASE
                    WHEN cor_taxon_attribut.valeur_attribut = 'I'::text THEN '#d9d9d9'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'II'::text THEN '#548235'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'III'::text THEN '#9bc2e6'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'IV'::text THEN '#e2efda'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'V'::text THEN '#ffc000'::text
                    WHEN cor_taxon_attribut.valeur_attribut = 'VI'::text THEN '#ccccff'::text
                    ELSE NULL::text
                END AS couleur
           FROM taxonomie.cor_taxon_attribut
          WHERE cor_taxon_attribut.id_attribut = 43
        ), patri as(
			SELECT 
				cor_taxon_attribut.cd_ref,
				cor_taxon_attribut.valeur_attribut AS patrimonialite_hn
			FROM taxonomie.cor_taxon_attribut
			WHERE cor_taxon_attribut.id_attribut = 7
		), bern as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut, 
				cd_sig
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'BERN'
			ORDER BY cd_sig
		),
		dh as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut 
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'DH'
		),  lrm as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut 
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'LRM'
		),lre as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut 
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'LRE'
		),lrn as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut 
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'LRN'
		),lrr as (
			SELECT
				cd_nom,
				cd_ref,
				STRING_AGG (DISTINCT cd_type_statut, ',') as cd_type_statut,
				STRING_AGG (DISTINCT cd_sig || ' ' || label_statut, ',') as label_statut 
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'LRR'
			AND cd_sig in ('INSEER23', 'INSEER25', 'INSEER28')
			GROUP BY cd_ref, cd_nom
		), patnat as (
			SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut, 
				cd_sig
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'PAPNAT'
			AND label_statut = 'Prioritaire'
			ORDER BY cd_ref, cd_nom
		), pn as (SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut, 
				cd_sig
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'PN'
			ORDER BY cd_ref, cd_nom),
			regl as (
				SELECT
				cd_nom,
				cd_ref,
				cd_type_statut,
				label_statut, 
				cd_sig
			FROM taxonomie.bdc_statut
			WHERE ordre = 'Lepidoptera' AND cd_type_statut = 'REGL'
			),
			
		tr AS (
         SELECT tbs.id_base_site,
            taf.id_dataset,
            taf.dataset_name,
            tsg.sites_group_name AS site_code,
            la.area_name AS site_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN gn_meta.cor_acquisition_framework_site caf ON tsg.sites_group_name::text = caf.area_code
             LEFT JOIN gn_meta.t_datasets taf ON taf.id_acquisition_framework = caf.id_acquisition_framework
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%faune%'::text OR tsg.id_module = 32 AND lower(taf.dataset_name::text) ~~ '%taxon%'::text
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 32
        ), obs AS (
         SELECT o.id_observation,
            o.id_base_visit,
            o.cd_nom,
            tx.nom_valide,
            tx.nom_vern,
            o.comments,
            toc.data,
            mil.cd_ref,
            mil.id_milieu,
            mil.milieu,
            mil.couleur,
			patri.patrimonialite_hn,
			bern.label_statut  as statut_bern,
			dh.label_statut  as statut_dir_hab,
			lrm.label_statut  as statut_lrm,
			lre.label_statut  as statut_lre,
			lrn.label_statut  as statut_lrn,
			lrr.label_statut  as statut_lrr,
			patnat.label_statut  as prior_action_pub,
			pn.cd_type_statut  as protect_nat,
			regl.label_statut as cites
      FROM gn_monitoring.t_observations o
        LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
        LEFT JOIN taxonomie.taxref tx USING (cd_nom)
        LEFT JOIN milieux mil USING (cd_ref)
        LEFT JOIN patri USING (cd_ref)
        LEFT JOIN dh USING (cd_nom)
        LEFT JOIN bern USING (cd_nom)
        LEFT JOIN lrm USING (cd_nom)
        LEFT JOIN lre USING (cd_nom)
        LEFT JOIN lrn USING (cd_nom)
        LEFT JOIN lrr USING (cd_nom)
        LEFT JOIN patnat USING (cd_nom)
        LEFT JOIN pn USING (cd_nom)
        LEFT JOIN regl USING (cd_nom)
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT obs.id_observation,
    tr.id_dataset,
    tr.dataset_name,
    tr.site_code,
    tr.site_name,
    tr.transect_name,
    (pass.data -> 'annee'::text)::integer AS pass_annee,
    (pass.data -> 'num_passage'::text)::integer AS pass_num,
    pass.pass_date,
    (pass.data -> 'heure_debut'::text)::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data -> 'occ_sol'::text)::text AS pass_os1,
    (pass.data -> 'occ_sol_detail'::text)::text AS pass_os2,
    (pass.data -> 'hab_1'::text)::text AS pass_hab1,
    (pass.data -> 'hab_2'::text)::text AS pass_hab2,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying) AS temperature,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying) AS couv_nuageuse,
    ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying) AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
    obs.id_milieu,
    obs.milieu,
	  obs.patrimonialite_hn,
	  obs.statut_bern,
	  obs.statut_dir_hab,
	  obs.statut_lrm,
	  obs.statut_lre,
	  obs.statut_lrn,
	  obs.statut_lrr,
	  obs.prior_action_pub,
	  obs.protect_nat,
	  obs.cites,
    (obs.data -> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
    obs.comments AS commentaire,
    obs.couleur,
    tr.id_base_site,
    pass.id_base_visit,
    (pass.data -> 'source'::text)::text AS source_donnee,
    obs.data -> 'id_obs_mysql'::text AS id_obs_mysql,
    tr.altitude_min,
    tr.altitude_max
   FROM obs
     LEFT JOIN observers USING (id_base_visit)
     LEFT JOIN pass USING (id_base_visit)
     JOIN tr USING (id_base_site)
  ORDER BY tr.site_code, tr.transect_name, ((pass.data -> 'annee'::text)::integer) DESC, ((pass.data -> 'num_passage'::text)::integer) DESC, obs.nom_valide ;

-- Accès dans Qgis
GRANT SELECT ON TABLE gn_monitoring.v_export_sterf_obs_n1 TO geonat_visu;
GRANT SELECT ON TABLE gn_monitoring.v_export_sterf_obs_n TO geonat_visu;
GRANT SELECT ON TABLE gn_monitoring.v_export_sterf_obs TO geonat_visu;
GRANT SELECT ON TABLE gn_monitoring.v_export_sterf_transect TO geonat_visu;
GRANT SELECT ON TABLE gn_monitoring.v_export_sterf_obs_2 TO geonat_visu;