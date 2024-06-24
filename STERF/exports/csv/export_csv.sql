-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

-------------------------------------------------final --STERF standard------------------------------------------
-- View: gn_monitoring.v_export_terf_standard

DROP VIEW  IF EXISTS  gn_monitoring.v_export_terf_standard;

CREATE OR REPLACE VIEW gn_monitoring.v_export_sterf_standard AS

WITH source AS (
		SELECT
			id_source
		FROM gn_synthese.t_sources
		WHERE name_source = CONCAT('MONITORING_', UPPER(:'module_code'))
		LIMIT 1
	),sites AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_code::integer AS id_dataset,
            taf.dataset_name,
            la.id_area AS id_area_attachment,
            cafs.area_code,
            la.area_name,
            (tbs.base_site_code::text || ' / '::text) || tbs.base_site_name::text AS transect,
            (r.nom_role::text || ' '::text) || r.prenom_role::text AS responsable,
            (tsc.data -> 'lisiere'::text)::text AS lisiere,
            tsc.data -> 'hab_1'::text AS hab_1,
            (tsc.data -> 'hab_2'::text)::text AS hab_2,
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
        CASE
            WHEN s.lisiere = 'Oui'::text THEN true
            ELSE false
        END AS lisiere,
    s.hab_1,
    s.hab_2,
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
    obs.observers,
    oc.data -> 'determiner'::text AS determiner,
    'Stationnel'::text AS geo_object_nature,
    ref_nomenclatures.get_nomenclature_label(v.id_nomenclature_grp_typ) AS grp_typ,
    ref_nomenclatures.get_nomenclature_label(v.id_nomenclature_tech_collect_campanule) AS tech_collect_campanule,
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
    WHERE m.module_code = :'module_code'
  ORDER BY s.area_code, s.transect, (date_part('year'::text, v.date_min)), v.num_passage, o.cd_nom;
    ;