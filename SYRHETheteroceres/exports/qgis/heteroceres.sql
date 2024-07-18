DROP VIEW IF EXISTS gn_monitoring.v_qgis_syrhetheteroceres;

CREATE VIEW gn_monitoring.v_qgis_syrhetheteroceres AS
	WITH 
	sites AS (
    SELECT
        tbs.id_base_site,
		tsg.sites_group_name,
		tbs.altitude_min,
		tbs.altitude_max,
		tbs.base_site_name,
        tbs.geom AS the_geom_4326,
	    tbs.geom_local as the_geom_local,
		ST_Centroid(geom_local) as the_geom_point
	FROM gn_monitoring.t_base_sites tbs
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
	),
	visits AS (
    SELECT
        tbv.id_base_visit,
		(tvc.data -> 'num_passage' )::text as num_passage,
		(tvc.data -> 'heure_debut' ) as heure_debut,
		(tvc.data -> 'heure_fin' ) as heure_fin,
		(tvc.data -> 'heure_ext' ) as heure_extinction,
		CASE WHEN (tvc.data->'meteo')::text = 'null' OR (tvc.data->'meteo')::text IS NULL THEN NULL
		ELSE ref_nomenclatures.get_nomenclature_label(
			(tvc.data->'meteo')::integer
		) 
		END as meteo, 
		CASE WHEN (tvc.data->'pluviosite')::text = 'null' OR (tvc.data->'pluviosite')::text IS NULL THEN NULL
		ELSE ref_nomenclatures.get_nomenclature_label(
			(tvc.data->'pluviosite')::integer
		)
		END as pluviosite, 
		CASE WHEN (tvc.data->'vent')::text = 'null' OR (tvc.data->'vent')::text IS NULL THEN NULL
		ELSE ref_nomenclatures.get_nomenclature_label(
			(tvc.data->'vent')::integer
		) END as vent,
		(tvc.data -> 'temperature' ) as temperature,
        tbv.uuid_base_visit,
        tbv.id_module,
        tbv.id_base_site,
        tbv.id_dataset,
		d.dataset_name,
        tbv.id_digitiser,
        tbv.visit_date_min AS date_min,
	    COALESCE (tbv.visit_date_max, tbv.visit_date_min) AS date_max,
        tbv.comments,
    	tbv.id_nomenclature_tech_collect_campanule,
	    tbv.id_nomenclature_grp_typ,
		tbv.meta_create_date,
		tbv.meta_update_date
        FROM gn_monitoring.t_base_visits tbv
		LEFT JOIN gn_meta.t_datasets d USING (id_dataset)
		LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
	), 
	observers AS (
    SELECT
        array_agg(r.id_role) AS ids_observers,
        STRING_AGG(CONCAT(r.nom_role, ' ', prenom_role), ' ; ') AS observers,
        id_base_visit
    FROM gn_monitoring.cor_visit_observer cvo
    JOIN utilisateurs.t_roles r
    ON r.id_role = cvo.id_role
    GROUP BY id_base_visit
)
	SELECT
		-- Identifiant unique observation		
		o.id_observation AS entity_source_pk_value,
		-- Niveau site / visit
		v.dataset_name,
		s.sites_group_name as lieu_dit,
		s.base_site_name as piege,
		s.altitude_min,
		s.altitude_max,
		v.num_passage,
		utilisateurs.get_name_by_id_role(v.id_digitiser) as numerisateur,
		v.date_min,
		v.date_max,
		v.heure_debut,
		v.heure_fin,
		v.heure_extinction,
		v.meteo,
		v.pluviosite,
		v.vent,
		v.temperature,
        'Stationnel' AS geo_object_nature,
		'Passage' AS grp_typ,
		'Piégeage lumineux automatique à fluorescence' AS tech_collect_campanule,
		-- Niveau Observation
		o.id_observation,
		utilisateurs.get_name_by_id_role((oc.data->'determiner')::integer) AS determinateur,
		obs.observers as observateurs,
		(oc.data->'effectif')::integer AS effectif,
		o.cd_nom,
		t.nom_complet AS nom_cite,
		t.nom_vern,
		ref_nomenclatures.get_nomenclature_label(
			(oc.data->'id_nomenclature_loca_obs')::integer
		) as loca_obs, 
 		'Individu' AS obj_count, -- l'objet du dénombrement est le nombre d'individus
 		'Compté' AS type_count, -- les individus sont comptés
 		'Présent' AS observation_status, -- le taxon est présent
		ref_nomenclatures.get_nomenclature_label(
			(oc.data->'id_nomenclature_life_stage')::integer
		) as life_stage, -- STADE_VIE
		ref_nomenclatures.get_nomenclature_label(
			(oc.data->'id_nomenclature_sex')::integer
		) as sex, -- SEXE
		ref_nomenclatures.get_nomenclature_label(
			(oc.data->'id_nomenclature_obs_technique')::integer 
		) as obs_technique, -- METH_OBS
		(oc.data->'collection') as exist_proof,
		'Certain / très probable' AS valid_status, 
		'Terrain' AS id_nomenclature_source_status, -- la source est le terrain
		ref_nomenclatures.get_nomenclature_label(
			(oc.data->'id_nomenclature_determination_method')::integer
		) AS id_nomenclature_determination_method,
		--meta_validation_date
		v.comments || ' ' || o.comments AS comments,
		--last_action,
		-- ## Colonnes complémentaires qui ont leur utilité dans la fonction synthese.import_row_from_table
		v.id_dataset,
		v.id_base_site,
		v.id_base_visit,
		v.id_module,
		o.uuid_observation AS unique_id_sinp,
		v.uuid_base_visit AS unique_id_sinp_grp,
		obs.ids_observers,
		v.meta_create_date,
		v.meta_update_date,
		-- Géométries
		--s.the_geom_4326::GEOMETRY(POINT, 4326),
		--s.the_geom_local::GEOMETRY(POINT, 2154),
		the_geom_point
    FROM gn_monitoring.t_observations o 
	LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
    JOIN visits v
        ON v.id_base_visit = o.id_base_visit
    JOIN sites s
        ON s.id_base_site = v.id_base_site
	LEFT JOIN gn_monitoring.t_site_complements v_compl ON v_compl.id_base_site = v.id_base_site
	LEFT JOIN gn_commons.t_modules m
        ON m.id_module = v.id_module
	JOIN taxonomie.taxref t
        ON t.cd_nom = o.cd_nom
	JOIN observers obs ON obs.id_base_visit = v.id_base_visit
	WHERE m.module_code = 'SYRHETheteroceres'
	ORDER BY s.sites_group_name, s.base_site_name, v.num_passage, o.id_observation
;


GRANT USAGE ON schema gn_monitoring to geonat_visu ;
GRANT SELECT ON table gn_monitoring.v_qgis_syrhetheteroceres to geonat_visu;

GRANT USAGE ON schema utilisateurs to geonat_visu ;
GRANT SELECT ON table utilisateurs.t_roles to geonat_visu;

GRANT USAGE ON schema ref_nomenclatures to geonat_visu ;
GRANT SELECT ON table ref_nomenclatures.t_nomenclatures to geonat_visu;

GRANT USAGE ON schema gn_commons to geonat_visu ;
GRANT SELECT ON table gn_commons.t_modules to geonat_visu;


GRANT USAGE ON schema gn_meta to geonat_visu ;
GRANT SELECT ON table gn_meta.t_datasets to geonat_visu;

GRANT USAGE ON schema taxonomie to geonat_visu ;
GRANT SELECT ON table taxonomie.taxref to geonat_visu;