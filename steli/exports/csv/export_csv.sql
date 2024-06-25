-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --rhomeoodonate standard------------------------------------------
-- View: gn_monitoring.v_export_rhomeoodonate_standard

DROP VIEW  IF EXISTS  gn_monitoring.v_export_steli_standard;

CREATE OR REPLACE VIEW gn_monitoring.v_export_steli_standard AS

WITH source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1
	),, mt AS (
         SELECT x.id_base_site,
            string_agg(x.label_mt, '; '::text) AS milieu_terrestre
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_mt'::text)::integer)::text AS label_mt
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), ma AS (
         SELECT x.id_base_site,
            string_agg(x.label_ma, '; '::text) AS milieu_aquatique
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_ma'::text)::integer)::text AS label_ma
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), ah AS (
         SELECT x.id_base_site,
            string_agg(x.label_ah, '; '::text) AS activite_humaine
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_ah'::text)::integer)::text AS label_ah
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), ri AS (
         SELECT x.id_base_site,
            string_agg(x.label_ri, '; '::text) AS type_rive
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_ri'::text)::integer)::text AS label_ri
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), ne AS (
         SELECT x.id_base_site,
            string_agg(x.label_ne, '; '::text) AS niveau_eau
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_ne'::text)::integer)::text AS label_ne
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), eu AS (
         SELECT x.id_base_site,
            string_agg(x.label_eu, '; '::text) AS eutrophisation
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_eu'::text)::integer)::text AS label_eu
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), co AS (
         SELECT x.id_base_site,
            string_agg(x.label_co, '; '::text) AS courant
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_co'::text)::integer)::text AS label_co
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), va AS (
         SELECT x.id_base_site,
            string_agg(x.label_va, '; '::text) AS vegetation
           FROM ( SELECT t_site_complements.id_base_site,
                    ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_va'::text)::integer)::text AS label_va
                   FROM gn_monitoring.t_site_complements) x
          GROUP BY x.id_base_site
          ORDER BY x.id_base_site
        ), sites AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_code::integer AS id_dataset,
            taf.dataset_name,
            la.id_area AS id_area_attachment,
            cafs.area_code,
            la.area_name,
            (tbs.base_site_code::text || ' / '::text) || tbs.base_site_name::text AS transect,
            (r.nom_role::text || ' '::text) || r.prenom_role::text AS responsable,
            tbs.base_site_description AS site_comments,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom AS the_geom_4326,
            st_centroid(tbs.geom) AS the_geom_point,
            tbs.geom_local
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN utilisateurs.t_roles r ON (tsc.data -> 'id_resp'::text)::integer = r.id_role
             LEFT JOIN gn_meta.t_datasets taf ON taf.id_dataset = tsg.sites_group_code::integer
             LEFT JOIN gn_meta.cor_acquisition_framework_site cafs USING (id_acquisition_framework)
             LEFT JOIN ref_geo.l_areas la USING (area_code)
        ), visits AS (
         SELECT tbv.id_base_visit,
            tbv.uuid_base_visit,
            tbv.id_module,
            tbv.id_base_site,
            tbv.id_digitiser,
            (tbv.visit_date_min::text || ((tvc.data -> 'heure_debut'::text)::text))::timestamp without time zone AS date_min,
            COALESCE((tbv.visit_date_max::text || ((tvc.data -> 'heure_fin'::text)::text))::timestamp without time zone, (tbv.visit_date_min::text || ((tvc.data -> 'heure_fin'::text)::text))::timestamp without time zone) AS date_max,
            tbv.comments,
            tbv.id_nomenclature_tech_collect_campanule,
            tbv.id_nomenclature_grp_typ,
            (tvc.data -> 'num_passage'::text)::integer AS num_passage,
            ref_nomenclatures.get_nomenclature_label((tvc.data -> 'id_nomenclature_tp'::text)::integer) AS temperature,
            ref_nomenclatures.get_nomenclature_label((tvc.data -> 'id_nomenclature_cn'::text)::integer) AS couv_nuageuse,
            ref_nomenclatures.get_nomenclature_label((tvc.data -> 'id_nomenclature_vt'::text)::integer) AS vent,
            (tvc.data -> 'source'::text)::text AS srce
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
        ), visit_mt AS (
         SELECT t_site_complements.id_base_site,
            ref_nomenclatures.get_nomenclature_label(jsonb_array_elements(t_site_complements.data -> 'id_nomenclature_mt'::text)::integer)::text AS get_nomenclature_label
           FROM gn_monitoring.t_site_complements
          ORDER BY t_site_complements.id_base_site
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT o.uuid_observation AS unique_id_sinp,
    v.uuid_base_visit AS unique_id_sinp_grp,
    s.area_code AS id_site,
    s.area_name AS nom_site,
    s.id_dataset,
    s.dataset_name,
    m.module_code AS suivi,
    s.responsable,
    s.transect,
    s.altitude_min,
    s.altitude_max,
    mt.milieu_terrestre,
    ma.milieu_aquatique,
    ah.activite_humaine,
    ri.type_rive,
    ne.niveau_eau,
    eu.eutrophisation,
    co.courant,
    va.vegetation,
    date_part('year'::text, v.date_min) AS annee,
    v.num_passage,
    v.date_min,
    v.date_max,
    v.id_digitiser,
    v.temperature,
    v.couv_nuageuse,
    v.vent,
    o.cd_nom,
    t.cd_ref,
    t.nom_complet,
    t.regne,
    t.phylum,
    t.classe,
    t.ordre,
    t.famille,
    (oc.data -> 'effectif'::text)::integer AS effectif,
    oc.data -> 'nb_male'::text AS nb_male,
    oc.data -> 'nb_femelle'::text AS nb_femelle,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_ab'::text)::integer) AS abondance,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_ir'::text)::integer) AS indice_repro,
    obs.observers,
    oc.data -> 'determiner'::text AS determiner,
    'Stationnel'::text AS geo_object_nature,
    ref_nomenclatures.get_id_nomenclature('TYP_GRP'::character varying, 'PASS'::character varying) AS id_nomenclature_grp_typ,
    ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS'::character varying, '59'::character varying) AS id_nomenclature_tech_collect_campanule,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_determination_method'::text)::integer) AS determination_method,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_obs_technique'::text)::integer) AS obs_technique,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_obj_count'::text)::integer) AS obj_count,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_type_count'::text)::integer) AS _type_count,
    'Présent'::text AS observation_status,
    'Terrain'::text AS source_status,
    'Géoréférencement'::text AS info_geo_type,
    (s.site_comments || ' / '::text) || v.comments AS comment_context,
    o.comments AS comment_description,
    v.srce,
    s.the_geom_4326,
    s.the_geom_point,
    s.geom_local
   FROM gn_monitoring.t_observations o
     LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
     JOIN visits v USING (id_base_visit)
     JOIN sites s USING (id_base_site)
     JOIN gn_commons.t_modules m USING (id_module)
     JOIN taxonomie.taxref t USING (cd_nom)
     JOIN source ON true
     JOIN observers obs USING (id_base_visit)
     LEFT JOIN mt USING (id_base_site)
     LEFT JOIN ma USING (id_base_site)
     LEFT JOIN ah USING (id_base_site)
     LEFT JOIN ri USING (id_base_site)
     LEFT JOIN ne USING (id_base_site)
     LEFT JOIN eu USING (id_base_site)
     LEFT JOIN co USING (id_base_site)
     LEFT JOIN va USING (id_base_site)
     LEFT JOIN visit_mt USING (id_base_site)
    WHERE m.module_code = :'module_code'
	ORDER BY s.area_code, s.transect , extract(year from v.date_min), v.num_passage, o.cd_nom
    ;