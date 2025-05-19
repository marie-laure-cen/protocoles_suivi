-- alter table gn_monitoring.t_base_sites alter column id_nomenclature_type_site drop not null;

------------------------------------------------- Observations de prélocalisation des tourbières ------------------------------------------
-- View: gn_monitoring.v_export_prat_preloc

DROP VIEW  IF EXISTS  gn_monitoring.v_export_prat_preloc;

CREATE OR REPLACE VIEW gn_monitoring.v_export_prat_preloc AS
WITH 
	srce as (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = 'MONITORING_PRAT'
	),
	sites as (
		SELECT 
	        tbs.id_base_site,
	        tbs.base_site_name,
	        tbs.base_site_code,
	        tbs.altitude_min,
	        tbs.altitude_max,
			tsc.data,
	        tbs.geom AS the_geom_4326,
	        st_centroid(tbs.geom) AS the_geom_point,
	        tbs.geom_local
	      FROM gn_monitoring.t_base_sites tbs
	        LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	        LEFT JOIN gn_monitoring.cor_site_module csm USING (id_base_site)
	        JOIN srce ON csm.id_module = srce.id_module
	), 
    visits AS (
	 SELECT 
	 	tbv.id_base_visit,
		tbv.uuid_base_visit,
		tbv.id_module,
		tbv.id_base_site,
		tbv.id_dataset,
		srce.id_source,
		tbv.id_digitiser,
		tbv.visit_date_min AS date_min,
		COALESCE(tbv.visit_date_max, tbv.visit_date_min) AS date_max,
		tbv.comments,
		tbv.id_nomenclature_tech_collect_campanule,
		tbv.id_nomenclature_grp_typ,
		tvc.data
	   FROM gn_monitoring.t_base_visits tbv
		 LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
		 JOIN srce USING (id_module)
	), 
	observers AS (
		SELECT
			array_agg(r.id_role) AS ids_observers,
			string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
		FROM gn_monitoring.cor_visit_observer cvo
		JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
		GROUP BY cvo.id_base_visit
     )
	SELECT
		o.uuid_observation AS unique_id_sinp,
	    s.base_site_name AS tourbiere_nom,
		s.base_site_code AS tourbiere_id,
		(s.data->>'statut_tourbiere') as tourbiere_statut,
		(s.data->>'type_tourbiere') as tourbiere_type,
		(s.data->>'niv_flore') as tourbiere_niv_flore,
		(s.data->>'niv_bryoflore') as tourbiere_niv_bryoflore,
		(s.data->>'niv_habitat') as tourbiere_niv_habitat,
		(s.data->>'niv_pedologie') as tourbiere_niv_pedologie,
		(s.data->>'gestion_cen') as tourbiere_gestion_cen,
		(s.data->>'gestion_cen') as tourbiere_gestion_cen_2020,
		(s.data->>'validation') as tourbiere_validation,
		(s.data->>'enjeu_connaissance') as tourbiere_enjeu_connaissance,
		(s.data->>'enjeu_protection') as tourbiere_enjeu_protection,
		(s.data->>'enjeu_gestion') as tourbiere_enjeu_gestion,
		ROUND((s.data->>'proportionnel_intersection')::decimal,0) as tourbiere_pt_intersection,
	    s.altitude_min,
	    s.altitude_max,
	    v.date_min,
	    v.date_max,
	    obs.observers,
	    o.cd_nom,
	    t.nom_complet AS taxon,
    	1 AS count_min,
		1 AS count_max,
	    (((((((((((('num_passage : '::text || (v.data ->> 'num_passage'::text)) || ' | habitat : '::text) || COALESCE(v.data ->> 'habitat'::text, '/'::text)) || ' | gestion : '::text) || COALESCE(v.data ->> 'gestion'::text, '/'::text)) || ' | impact : '::text) || COALESCE(v.data ->> 'impact'::text, '/'::text)) || ' | vent : '::text) || ref_nomenclatures.get_nomenclature_label((v.data ->> 'id_nomenclature_vt'::text)::integer)::text) || ' | couverture_nuageuse : '::text) || ref_nomenclatures.get_nomenclature_label((v.data ->> 'id_nomenclature_cn'::text)::integer)::text) || ' | temperature : '::text) || ref_nomenclatures.get_nomenclature_label((v.data ->> 'id_nomenclature_tp'::text)::integer)::text AS comment_context,
	        CASE
	            WHEN v.comments IS NULL AND NOT o.comments IS NULL THEN o.comments
	            WHEN NOT v.comments IS NULL AND o.comments IS NULL THEN v.comments
	            ELSE (v.comments || ' '::text) || o.comments
	        END AS comment_description,
	    jsonb_strip_nulls(jsonb_build_object('annee', (v.data ->> 'annee'::text)::integer, 'num_passage', (v.data ->> 'num_passage'::text)::integer, 'habitat', v.data ->> 'habitat'::text, 'gestion', v.data ->> 'gestion'::text, 'impact', v.data ->> 'impact'::text, 'id_nomenclature_vt', (v.data ->> 'id_nomenclature_vt'::text)::integer, 'id_nomenclature_cn', (v.data ->> 'id_nomenclature_cn'::text)::integer, 'id_nomenclature_tp', (v.data ->> 'id_nomenclature_tp'::text)::integer)) AS additional_data,
	    ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO'::character varying, 'St'::character varying) AS id_nomenclature_geo_object_nature,
    	ref_nomenclatures.get_id_nomenclature('TYP_GRP'::character varying, 'PASS'::character varying) AS id_nomenclature_grp_typ,
    	ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS'::character varying, '59'::character varying) AS id_nomenclature_tech_collect_campanule,
    	ref_nomenclatures.get_id_nomenclature('METH_OBS'::character varying, '0'::character varying) AS id_nomenclature_obs_technique,
    	ref_nomenclatures.get_id_nomenclature('OBJ_DENBR'::character varying, 'IND'::character varying) AS id_nomenclature_obj_count,
	    ref_nomenclatures.get_id_nomenclature('TYP_DENBR'::character varying, 'Co'::character varying) AS id_nomenclature_type_count,
	    ref_nomenclatures.get_id_nomenclature('STATUT_OBS'::character varying, 'Pr'::character varying) AS id_nomenclature_observation_status,
	    ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE'::character varying, 'Te'::character varying) AS id_nomenclature_source_status,
	    ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO'::character varying, '1'::character varying) AS id_nomenclature_info_geo_type,
	    (toc.data ->> 'id_nomenclature_determination_method'::text)::integer AS id_nomenclature_determination_method,
		obs.ids_observers,
	    v.id_digitiser,
	    v.id_module,
   		v.id_source,
       	v.id_dataset,
	    v.id_base_site,
	    v.id_base_visit,
		v.uuid_base_visit AS unique_id_sinp_grp,
		o.id_observation,
   		o.id_observation AS entity_source_pk_value,
	    s.the_geom_point,
	    s.the_geom_4326,
	    s.geom_local AS the_geom_local
   FROM gn_monitoring.t_observations o
     LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
     JOIN visits v ON v.id_base_visit = o.id_base_visit
     JOIN sites s ON s.id_base_site = v.id_base_site
     JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
     LEFT JOIN observers obs ON obs.id_base_visit = v.id_base_visit
   ORDER BY s.base_site_name, v.date_min, t.nom_complet
    ;

------------------------------------------------- Prélocalisation des tourbières ------------------------------------------
-- View: gn_monitoring.v_export_prat_preloc_site

DROP VIEW  IF EXISTS  gn_monitoring.v_export_prat_preloc_site;

CREATE OR REPLACE VIEW gn_monitoring.v_export_prat_preloc_site AS
WITH 
	srce as (
		SELECT 
			sc.id_source,
			mo.id_module
		FROM gn_synthese.t_sources sc
		LEFT JOIN gn_commons.t_modules mo ON 'MONITORING_' || UPPER(mo.module_code) = sc.name_source
		WHERE sc.name_source = 'MONITORING_PRAT'
	)
	SELECT
		tbs.id_base_site,
	    tbs.base_site_name AS tourbiere_nom,
		tbs.base_site_code AS tourbiere_id,
		(tsc.data->>'statut_tourbiere') as tourbiere_statut,
		(tsc.data->>'type_tourbiere') as tourbiere_type,
		(tsc.data->>'niv_flore') as tourbiere_niv_flore,
		(tsc.data->>'niv_bryoflore') as tourbiere_niv_bryoflore,
		(tsc.data->>'niv_habitat') as tourbiere_niv_habitat,
		(tsc.data->>'niv_pedologie') as tourbiere_niv_pedologie,
		(tsc.data->>'gestion_cen') as tourbiere_gestion_cen,
		(tsc.data->>'gestion_cen') as tourbiere_gestion_cen_2020,
		(tsc.data->>'validation') as tourbiere_validation,
		(tsc.data->>'enjeu_connaissance') as tourbiere_enjeu_connaissance,
		(tsc.data->>'enjeu_protection') as tourbiere_enjeu_protection,
		(tsc.data->>'enjeu_gestion') as tourbiere_enjeu_gestion,
		ROUND((tsc.data->>'proportionnel_intersection')::decimal,0) as tourbiere_pt_intersection,
	    tbs.altitude_min,
	    tbs.altitude_max,
	    St_Centroid(tbs.geom)::GEOMETRY(POINT, 4326) as the_geom_point,
	    ST_MULTI(tbs.geom)::GEOMETRY(MULTIPOLYGON, 4326) as the_geom_4326,
	    ST_MULTI(tbs.geom_local)::GEOMETRY(MULTIPOLYGON, 2154) as the_geom_local
	FROM gn_monitoring.t_base_sites tbs
		LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
		LEFT JOIN gn_monitoring.cor_site_module csm USING (id_base_site)
		JOIN srce ON csm.id_module = srce.id_module
   ORDER BY tbs.base_site_name
   ;