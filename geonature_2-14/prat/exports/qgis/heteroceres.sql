DROP VIEW gn_monitoring.v_qgis_syrhetheteroceres;

CREATE OR REPLACE VIEW gn_monitoring.v_qgis_syrhetheteroceres
 AS
 WITH sites AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.base_site_name,
            tbs.geom AS the_geom_4326,
            tbs.geom_local AS the_geom_local,
            st_centroid(tbs.geom_local) AS the_geom_point
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
        ), visits AS (
         SELECT tbv.id_base_visit,
            (tvc.data -> 'num_passage')::integer AS num_passage,
            (tvc.data -> 'heure_debut')::text AS heure_debut,
            (tvc.data -> 'heure_fin')::text AS heure_fin,
            (tvc.data -> 'heure_ext')::text AS heure_extinction,
                CASE
                    WHEN ((tvc.data -> 'meteo'::text)::text) = 'null'::text OR ((tvc.data -> 'meteo'::text)::text) IS NULL THEN NULL::character varying
                    ELSE ref_nomenclatures.get_nomenclature_label((tvc.data -> 'meteo'::text)::integer)
                END AS meteo,
                CASE
                    WHEN ((tvc.data -> 'pluviosite'::text)::text) = 'null'::text OR ((tvc.data -> 'pluviosite'::text)::text) IS NULL THEN NULL::character varying
                    ELSE ref_nomenclatures.get_nomenclature_label((tvc.data -> 'pluviosite'::text)::integer)
                END AS pluviosite,
                CASE
                    WHEN ((tvc.data -> 'vent'::text)::text) = 'null'::text OR ((tvc.data -> 'vent'::text)::text) IS NULL THEN NULL::character varying
                    ELSE ref_nomenclatures.get_nomenclature_label((tvc.data -> 'vent'::text)::integer)
                END AS vent,
            CASE
                    WHEN ((tvc.data -> 'temperature'::text)::text) = 'null'::text OR ((tvc.data -> 'temperature'::text)::text) IS NULL THEN NULL
                    ELSE (tvc.data -> 'temperature'::text)::integer
                END AS temperature,
            tbv.uuid_base_visit,
            tbv.id_module,
            tbv.id_base_site,
            tbv.id_dataset,
            d.dataset_name,
            tbv.id_digitiser,
            tbv.visit_date_min AS date_min,
            COALESCE(tbv.visit_date_max, tbv.visit_date_min) AS date_max,
            tbv.comments,
            tbv.id_nomenclature_tech_collect_campanule,
            tbv.id_nomenclature_grp_typ,
            tbv.meta_create_date,
            tbv.meta_update_date
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
        ), observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
        )
 SELECT o.id_observation AS entity_source_pk_value,
    v.dataset_name,
    s.sites_group_name AS lieu_dit,
    s.base_site_name AS piege,
    s.altitude_min,
    s.altitude_max,
    v.num_passage,
    utilisateurs.get_name_by_id_role(v.id_digitiser) AS numerisateur,
    v.date_min,
    v.date_max,
    v.heure_debut,
    v.heure_fin,
    v.heure_extinction,
    v.meteo,
    v.pluviosite,
    v.vent,
    v.temperature,
    'Stationnel'::text AS geo_object_nature,
    'Passage'::text AS grp_typ,
    'Piégeage lumineux automatique à fluorescence'::text AS tech_collect_campanule,
    o.id_observation,
    utilisateurs.get_name_by_id_role((oc.data -> 'determiner'::text)::integer) AS determinateur,
    obs.observers AS observateurs,
    (oc.data -> 'effectif')::integer AS effectif,
    o.cd_nom,
    t.nom_complet AS nom_cite,
    t.nom_vern,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_loca_obs'::text)::integer) AS loca_obs,
    'Individu'::text AS obj_count,
    'Compté'::text AS type_count,
    'Présent'::text AS observation_status,
        CASE
            WHEN ((oc.data -> 'id_nomenclature_life_stage'::text)::text) = 'null'::text OR ((oc.data -> 'id_nomenclature_life_stage'::text)::text) IS NULL THEN NULL::character varying
            ELSE ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_life_stage'::text)::integer)
        END AS life_stage,
        CASE
            WHEN ((oc.data -> 'id_nomenclature_sex'::text)::text) = 'null'::text OR ((oc.data -> 'id_nomenclature_sex'::text)::text) IS NULL THEN NULL::character varying
            ELSE ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_sex'::text)::integer)
        END AS sex,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_obs_technique'::text)::integer) AS obs_technique,
    (oc.data -> 'collection')::text AS exist_proof,
    'Certain / très probable'::text AS valid_status,
    'Terrain'::text AS id_nomenclature_source_status,
    ref_nomenclatures.get_nomenclature_label((oc.data -> 'id_nomenclature_determination_method'::text)::integer) AS id_nomenclature_determination_method,
    (v.comments || ' '::text) || o.comments AS comments,
    v.id_dataset,
    v.id_base_site,
    v.id_base_visit,
    v.id_module,
    o.uuid_observation AS unique_id_sinp,
    v.uuid_base_visit AS unique_id_sinp_grp,
    --obs.ids_observers,
    v.meta_create_date,
    v.meta_update_date,
    s.the_geom_point
   FROM gn_monitoring.t_observations o
     LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
     JOIN visits v ON v.id_base_visit = o.id_base_visit
     JOIN sites s ON s.id_base_site = v.id_base_site
     LEFT JOIN gn_monitoring.t_site_complements v_compl ON v_compl.id_base_site = v.id_base_site
     LEFT JOIN gn_commons.t_modules m ON m.id_module = v.id_module
     JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
     JOIN observers obs ON obs.id_base_visit = v.id_base_visit
  WHERE m.module_code::text = 'SYRHETheteroceres'::text
  ORDER BY s.sites_group_name, s.base_site_name, v.num_passage, o.id_observation;

GRANT SELECT ON TABLE gn_monitoring.v_qgis_syrhetheteroceres TO geonat_visu;