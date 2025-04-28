UPDATE gn_imports.steli_import i SET id_digitiser = r.id_role
FROM utilisateurs.t_roles r WHERE lower(i.determiner) = lower(r.nom_role || ' ' || r.prenom_role)
;

WITH 
steli_transect as (
	SELECT
		*
	FROM gn_monitoring.t_base_sites tbs
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	WHERE id_module = 30
),
visits as (
SELECT
	s.transect,
	s.id_visit_steli,
	s.id_digitiser,
	s.visit_date_min
FROM gn_imports.steli_import s
GROUP BY 	 
	s.transect,
	s.id_digitiser,
	s.id_visit_steli,
	s.visit_date_min
)
INSERT INTO  gn_monitoring.t_base_visits 
(
	id_base_site,
	id_dataset,
	id_module,
	id_digitiser,
	visit_date_min,
	visit_date_max,
	id_nomenclature_tech_collect_campanule,
	id_nomenclature_grp_typ,
	comments
)
SELECT
	steli_transect.id_base_site,
	1388 as id_dataset, -- jdd STELI
	30 as id_module, -- module STELI
	visits.id_digitiser,
	visits.visit_date_min,
	visits.visit_date_min,
	240 as id_nomenclature_tech_collect_campanule , -- Observation directe terrestre diurne (chasse à vue de jour)
	132 as id_nomenclature_grp_typ , -- Passage
	visits.id_visit_steli as comments
FROM visits
LEFT JOIN steli_transect on steli_transect.base_site_name = visits.transect
ORDER BY extract(year from visit_date_min ), id_base_site, visit_date_min
;

UPDATE gn_imports.steli_import s
SET id_base_visit = tbv.id_base_visit
FROM  gn_monitoring.t_base_visits tbv
WHERE tbv.comments = s.id_visit_steli::text
AND tbv.id_module = 30
;

SELECT id_base_visit FROM gn_imports.steli_import s
GROUP BY s.id_base_visit
;

WITH nomen_cn as (
	SELECT
		id_nomenclature as id_nomenclature_cn,
		mnemonique as cn
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 173
),
nomen_tp as (
	SELECT
		id_nomenclature as id_nomenclature_tp,
		mnemonique as tp
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 172
),
nomen_vt as (
	SELECT
		id_nomenclature as id_nomenclature_vt,
		mnemonique as vt
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 183
),
nomen_mt as (
	SELECT
		id_nomenclature as id_nomenclature_mt,
		mnemonique as mt
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 180
),
nomen_ah as (
	SELECT
		id_nomenclature as id_nomenclature_ah,
		mnemonique as ah
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 170
),
nomen_ma as (
	SELECT
		id_nomenclature as id_nomenclature_ma,
		mnemonique as ma
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 179
),
nomen_ri as (
	SELECT
		id_nomenclature as id_nomenclature_ri,
		mnemonique as ri
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 178
),
nomen_ve as (
	SELECT
		id_nomenclature as id_nomenclature_ve,
		mnemonique as ve
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 175
),
nomen_eu as (
	SELECT
		id_nomenclature as id_nomenclature_eu,
		mnemonique as eu
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 901
),
nomen_co as (
	SELECT
		id_nomenclature as id_nomenclature_co,
		mnemonique as co
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 176
),
nomen_va as (
	SELECT
		id_nomenclature as id_nomenclature_va,
		mnemonique as va
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 177
)
INSERT INTO gn_monitoring.t_visit_complements (
	id_base_visit,
	data
)
SELECT 
	id_base_visit,
	jsonb_strip_nulls(
		jsonb_build_object(
			'annee', STRING_AGG(DISTINCT s.annee::text, ', ')::integer,
			'id_horaire_meteo', STRING_AGG(DISTINCT s.id_visit_steli::text, ', ')::integer,
			'periode', STRING_AGG(DISTINCT s.periode::text, ', ')::integer,
			'num_passage', STRING_AGG(DISTINCT s.num_passage::text, ', ')::integer,
			'id_nomenclature_mt', STRING_AGG(DISTINCT nomen_mt.id_nomenclature_mt::text, ', ')::integer,
			'id_nomenclature_ah', STRING_AGG(DISTINCT nomen_ah.id_nomenclature_ah::text, ', ')::integer,
			'id_nomenclature_ma', STRING_AGG(DISTINCT nomen_ma.id_nomenclature_ma::text, ', ')::integer,
			'id_nomenclature_ri', STRING_AGG(DISTINCT nomen_ri.id_nomenclature_ri::text, ', ')::integer,
			'id_nomenclature_ve', STRING_AGG(DISTINCT nomen_ve.id_nomenclature_ve::text, ', ')::integer,
			'id_nomenclature_eu', STRING_AGG(DISTINCT nomen_eu.id_nomenclature_eu::text, ', ')::integer,
			'id_nomenclature_co', STRING_AGG(DISTINCT nomen_co.id_nomenclature_co::text, ', ')::integer,
			'id_nomenclature_va', STRING_AGG(DISTINCT nomen_va.id_nomenclature_va::text, ', ')::integer,
			'id_nomenclature_cn', STRING_AGG(DISTINCT nomen_cn.id_nomenclature_cn::text, ', ')::integer,
			'id_nomenclature_tp', STRING_AGG(DISTINCT nomen_tp.id_nomenclature_tp::text, ', ')::integer,
			'id_nomenclature_vt', STRING_AGG(DISTINCT nomen_vt.id_nomenclature_vt::text, ', ')::integer,
			'source', 'Intranet SER',
			'heure_debut', STRING_AGG(DISTINCT s.heure_min, ', ')
		)
	) as data
FROM gn_imports.steli_import s
LEFT JOIN nomen_cn USING (cn)
LEFT JOIN nomen_tp USING (tp)
LEFT JOIN nomen_vt USING (vt)
LEFT JOIN nomen_mt USING (mt)
LEFT JOIN nomen_ah USING (ah)
LEFT JOIN nomen_ma USING (ma)
LEFT JOIN nomen_ri USING (ri)
LEFT JOIN nomen_ve USING (ve)
LEFT JOIN nomen_eu USING (eu)
LEFT JOIN nomen_co USING (co)
LEFT JOIN nomen_va USING (va)
GROUP BY 
	s.id_base_visit
ORDER BY id_base_visit
;

INSERT INTO gn_monitoring.cor_visit_observer (
	id_base_visit,
	id_role
)
SELECT
	id_base_visit,
	id_digitiser
FROM gn_monitoring.t_base_visits tbv
WHERE tbv.id_module = 30
ON CONFLICT DO NOTHING
;

INSERT INTO gn_monitoring.t_observations(
	id_base_visit,
	cd_nom,
	comments
)
SELECT 
	i.id_base_visit,
	i.cd_nom,
	i.id_obs_steli
FROM gn_imports.steli_import i
WHERE i.id_observation IS NULL
GROUP BY
	i.id_base_visit,
	i.cd_nom,
	i.id_obs_steli
ORDER BY i.id_base_visit, i.id_obs_steli
;

UPDATE gn_imports.steli_import i
SET id_observation = o.id_observation
FROM gn_monitoring.t_observations o
LEFT JOIN gn_monitoring.t_base_visits v USING (id_base_visit)
WHERE v.id_module = 30 AND i.id_obs_steli::text = o.comments
;

WITH
nomen_ab as (
	SELECT
		id_nomenclature as id_nomenclature_ab,
		mnemonique as ab
	FROM ref_nomenclatures.t_nomenclatures WHERE id_type = 170
),
nomen_ir as (
	SELECT 
		id_obs_steli,
		array_remove(
			ARRAY[
				CASE WHEN lower(ir_app_sex) = 'oui' THEN 881 ELSE NULL END,
				CASE WHEN lower(ir_tandem) = 'oui' THEN 882 ELSE NULL END, 
				CASE WHEN lower(ir_accoupl) = 'oui' THEN 883 ELSE NULL END, 
				CASE WHEN lower(ir_ponte) = 'oui' THEN 884 ELSE NULL END, 
				CASE WHEN lower(ir_exuvie) = 'oui' THEN 885 ELSE NULL END, 
				CASE WHEN lower(ir_immature) = 'oui' THEN 984 ELSE NULL END
			],
		NULL ) as id_nomenclature_ir
	FROM gn_imports.steli_import
	WHERE NOT array_remove(
		ARRAY[
			CASE WHEN lower(ir_app_sex) = 'oui' THEN 881 ELSE NULL END,
			CASE WHEN lower(ir_tandem) = 'oui' THEN 882 ELSE NULL END, 
			CASE WHEN lower(ir_accoupl) = 'oui' THEN 883 ELSE NULL END, 
			CASE WHEN lower(ir_ponte) = 'oui' THEN 884 ELSE NULL END, 
			CASE WHEN lower(ir_exuvie) = 'oui' THEN 885 ELSE NULL END, 
			CASE WHEN lower(ir_immature) = 'oui' THEN 984 ELSE NULL END
		],
	NULL ) = '{}'
)
INSERT INTO gn_monitoring.t_observation_complements (
	id_observation,
	data
)
SELECT
	id_observation,
	jsonb_strip_nulls(
		jsonb_build_object(
			'effectif', min(i.effectif),
			'nb_male', min(i.nb_male),
			'nb_femelle', min(i.nb_femelle),
			'determiner', min(i.determiner),
			'id_obs_mysql', i.id_obs_steli,
			'id_nomenclature_obs_technique', 785,
			'id_nomenclature_determination_method', 453,
			'id_nomenclature_type_count', 89,
			'id_nomenclature_obj_count', 143,
			'id_nomenclature_ab', STRING_AGG(DISTINCT nomen_ab.id_nomenclature_ab::text, ', ')::integer,
			'id_nomenclature_ir', nomen_ir.id_nomenclature_ir,
			'autochtonie', STRING_AGG(DISTINCT i.autochtonie, ', ')
		)
	) as data
FROM gn_imports.steli_import i
LEFT JOIN nomen_ab USING (ab)
LEFT JOIN nomen_ir USING (id_obs_steli)
GROUP BY i.id_observation, i.id_obs_steli, nomen_ir.id_nomenclature_ir
ORDER BY i.id_observation
;

WITH obs as (
	SELECT
		id_observation,
		STRING_AGG(DISTINCT obs_comment, ', ') as commentaire
	FROM gn_imports.steli_import
	GROUP BY id_observation
)
UPDATE gn_monitoring.t_observations o
SET comments = obs.commentaire
FROM obs
WHERE o.id_observation = obs.id_observation
;

WITH vis as (
	SELECT
		id_base_visit,
		STRING_AGG(DISTINCT visit_comment, ', ') as commentaire
	FROM gn_imports.steli_import
	GROUP BY id_base_visit
)
UPDATE gn_monitoring.t_base_visits v
SET comments = vis.commentaire
FROM vis
WHERE v.id_base_visit = vis.id_base_visit
AND v.id_module = 30
;

WITH site as (
	SELECT * FROM ref_geo.l_areas WHERE id_type in (12,34,37)
),
com as (
	SELECT * FROM ref_geo.l_areas WHERE id_type = 25
),
sc as (
	SELECT
		site.area_code as id_site,
		site.area_name as nom_site,
		STRING_AGG(com.area_name, ',' ORDER BY com.area_name) as communes
	FROM site
	LEFT JOIN com ON ST_Intersects( com.geom, site.geom)
	GROUP BY site.area_code, site.area_name
	ORDER BY site.area_name
)
UPDATE gn_monitoring.t_sites_groups tsg
	SET data = jsonb_set(	
			tsg.data::jsonb, 
			'{commune}', 
			to_jsonb(
				sc.communes
			))
FROM sc 
WHERE id_module = 30 AND sc.id_site = tsg.sites_group_code
;

WITH determ as (
	SELECT
		toc.id_observation,
		r.id_role,
		toc.data->>'determiner',
		jsonb_set(
			toc.data,
			array['determiner'],
			to_jsonb(r.id_role)
		) as new_data
	FROM gn_monitoring.t_observation_complements toc
	LEFT JOIN gn_monitoring.t_observations o USING (id_observation)
	LEFT JOIN utilisateurs.t_roles r ON toc.data->>'determiner' = r.nom_role || ' ' || r.prenom_role
	LEFT JOIN gn_monitoring.t_base_visits tbv USING (id_base_visit)
	WHERE id_module = 30
)
UPDATE gn_monitoring.t_observation_complements compl
SET data = new_data
FROM determ
WHERE compl.id_observation = determ.id_observation
;

WITH lv AS 
(SELECT
	tbv.id_base_site,
	LAST_VALUE(tvc.data ->> 'habitat')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_habitat,
 	LAST_VALUE(tvc.data ->> 'gestion')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_gestion,
 	LAST_VALUE(tvc.data ->> 'impact')
	OVER (
		PARTITION BY id_base_site
		ORDER BY (tbv.visit_date_min)
		RANGE BETWEEN 
            UNBOUNDED PRECEDING AND 
            UNBOUNDED FOLLOWING
	) as last_impact
FROM gn_monitoring.t_base_visits tbv
LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
WHERE id_module = 30
 ), sd as (
	SELECT
		lv.id_base_site,
		jsonb_build_object(
			'habitat',lv.last_habitat,
			'gestion', lv.last_gestion,
			'impact', lv.last_impact
		) as data
	FROM lv
	LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
	WHERE tsc.id_module = 33
	GROUP BY id_base_site,last_habitat, last_gestion, last_impact, tsc.data
	ORDER BY id_base_site
)
UPDATE gn_monitoring.t_site_complements tsc
SET data = sd.data
FROM sd
WHERE sd.id_base_site = tsc.id_base_site
;

DROP VIEW  IF EXISTS  gn_monitoring.v_export_steli_obs;

CREATE OR REPLACE VIEW gn_monitoring.v_export_steli_obs
AS
 WITH 
 	patri_hn AS (
         SELECT cor_taxon_attribut.valeur_attribut,
            cor_taxon_attribut.cd_ref
           FROM taxonomie.cor_taxon_attribut
          WHERE cor_taxon_attribut.id_attribut = 7
        ), 
	milieux AS (
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
        ), 
	tr AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_name AS site_code,
            tsg.sites_group_description AS site_name,
            tsg.data ->> 'commune'::text AS site_com,
            la.area_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 30
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), 
	pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 30
        ),
	obs AS (
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
            patri.valeur_attribut AS patrimonialite
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
             LEFT JOIN milieux mil USING (cd_ref)
             LEFT JOIN patri_hn patri USING (cd_ref)
    ), 
	observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
    ),
	ir as (
		SELECT
			id_observation,
			ref_nomenclatures.get_nomenclature_label( 
				jsonb_array_elements (toc.data -> 'id_nomenclature_ir')::integer 
			) as ir_label
		FROM gn_monitoring.t_observation_complements toc
		WHERE NOT toc.data ->> 'id_nomenclature_ir' IS NULL
	),
	irs as (
		SELECT
			id_observation,
			STRING_AGG(DISTINCT ir_label, ', ') as indice_repro
		FROM ir
		GROUP BY id_observation
	)
 SELECT 
 	obs.id_observation,
    tr.site_code,
    tr.site_name,
    tr.site_com,
    tr.transect_name,
    (pass.data ->> 'annee')::integer AS pass_annee,
    (pass.data ->> 'periode')::integer AS periode,
    (pass.data ->> 'num_passage')::integer AS pass_num,
    pass.pass_date,
    (pass.data ->> 'heure_debut')::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data ->> 'gestion') AS gestion,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_mt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_mt'::text)::integer, 'fr'::character varying)
	END AS milieu_terrestre,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ah'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ah'::text)::integer, 'fr'::character varying)
	END AS activite_humaine,
	
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ma'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ma'::text)::integer, 'fr'::character varying)
	END AS milieu_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ri'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ri'::text)::integer, 'fr'::character varying)
	END AS rive,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ve'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ve'::text)::integer, 'fr'::character varying)
	END AS var_niv_eau,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_eu'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_eu'::text)::integer, 'fr'::character varying)
	END AS euthrophisation,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_co'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_co'::text)::integer, 'fr'::character varying)
	END AS courant,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_va'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_va'::text)::integer, 'fr'::character varying)
	END AS vegetation_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_tp'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying)
	END AS temperature,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_cn'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying)
	END AS couv_nuageuse,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_vt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying)
	END AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
    r.nom_role || ' ' || r.prenom_role as determiner,
    obs.id_milieu,
    obs.milieu,
    obs.patrimonialite,
    (obs.data ->> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ab'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ab'::text)::integer, 'fr'::character varying)
	END AS abondance,
	obs.data->>'autochtonie' as autochtonie,
	irs.indice_repro,
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
     JOIN pass USING (id_base_visit)
     LEFT JOIN tr USING (id_base_site)
	 LEFT JOIN utilisateurs.t_roles r ON (obs.data->>'determiner') = id_role::text
	 LEFT JOIN irs USING (id_observation)
  ORDER BY ((pass.data -> 'annee'::text)::integer) DESC, tr.site_code, tr.transect_name,  ((pass.data -> 'num_passage'::text)::integer) DESC, obs.id_observation;

GRANT SELECT ON TABLE gn_monitoring.v_export_steli_obs TO geonat_visu;

DROP VIEW  IF EXISTS  gn_monitoring.v_export_steli_obs_2;

CREATE OR REPLACE VIEW gn_monitoring.v_export_steli_obs_2
AS
 WITH 
 	patri_hn AS (
         SELECT cor_taxon_attribut.valeur_attribut,
            cor_taxon_attribut.cd_ref
           FROM taxonomie.cor_taxon_attribut
          WHERE cor_taxon_attribut.id_attribut = 7
        ), 
	milieux AS (
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
        ), 
	tr AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_name AS site_code,
            tsg.sites_group_description AS site_name,
            tsg.data ->> 'commune'::text AS site_com,
            la.area_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 30
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), 
		bern AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut,
            bdc_statut.cd_sig
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'BERN'::text
          ORDER BY bdc_statut.cd_sig
        ), dh AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'DH'::text
        ), lrm AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'LRM'::text
        ), lre AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'LRE'::text
        ), lrn AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'LRN'::text
        ), lrr AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            string_agg(DISTINCT bdc_statut.cd_type_statut::text, ','::text) AS cd_type_statut,
            string_agg(DISTINCT (bdc_statut.cd_sig::text || ' '::text) || bdc_statut.label_statut::text, ','::text) AS label_statut
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'LRR'::text AND (bdc_statut.cd_sig::text = ANY (ARRAY['INSEER23'::character varying::text, 'INSEER25'::character varying::text, 'INSEER28'::character varying::text]))
          GROUP BY bdc_statut.cd_ref, bdc_statut.cd_nom
        ), patnat AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut,
            bdc_statut.cd_sig
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'PAPNAT'::text AND bdc_statut.label_statut::text = 'Prioritaire'::text
          ORDER BY bdc_statut.cd_ref, bdc_statut.cd_nom
        ), pn AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut,
            bdc_statut.cd_sig
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'PN'::text
          ORDER BY bdc_statut.cd_ref, bdc_statut.cd_nom
        ), regl AS (
         SELECT bdc_statut.cd_nom,
            bdc_statut.cd_ref,
            bdc_statut.cd_type_statut,
            bdc_statut.label_statut,
            bdc_statut.cd_sig
           FROM taxonomie.bdc_statut
          WHERE bdc_statut.cd_type_statut::text = 'REGL'::text
        ), 
	pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 30
        ),
	obs AS (
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
            patri.valeur_attribut AS patrimonialite,
		 	bern.label_statut AS statut_bern,
            dh.label_statut AS statut_dir_hab,
            lrm.label_statut AS statut_lrm,
            lre.label_statut AS statut_lre,
            lrn.label_statut AS statut_lrn,
            lrr.label_statut AS statut_lrr,
            patnat.label_statut AS prior_action_pub,
            pn.cd_type_statut AS protect_nat,
            regl.label_statut AS cites
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
             LEFT JOIN milieux mil USING (cd_ref)
             LEFT JOIN patri_hn patri USING (cd_ref)
			 LEFT JOIN dh USING (cd_nom)
             LEFT JOIN bern USING (cd_nom)
             LEFT JOIN lrm USING (cd_nom)
             LEFT JOIN lre USING (cd_nom)
             LEFT JOIN lrn USING (cd_nom)
             LEFT JOIN lrr USING (cd_nom)
             LEFT JOIN patnat USING (cd_nom)
             LEFT JOIN pn USING (cd_nom)
             LEFT JOIN regl USING (cd_nom)
    ), 
	observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
    ),
	ir as (
		SELECT
			id_observation,
			ref_nomenclatures.get_nomenclature_label( 
				jsonb_array_elements (toc.data -> 'id_nomenclature_ir')::integer 
			) as ir_label
		FROM gn_monitoring.t_observation_complements toc
		WHERE NOT toc.data ->> 'id_nomenclature_ir' IS NULL
	),
	irs as (
		SELECT
			id_observation,
			STRING_AGG(DISTINCT ir_label, ', ') as indice_repro
		FROM ir
		GROUP BY id_observation
	)
 SELECT 
 	obs.id_observation,
    tr.site_code,
    tr.site_name,
    tr.site_com,
    tr.transect_name,
    (pass.data ->> 'annee')::integer AS pass_annee,
    (pass.data ->> 'periode')::integer AS periode,
    (pass.data ->> 'num_passage')::integer AS pass_num,
    pass.pass_date,
    (pass.data ->> 'heure_debut')::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data ->> 'gestion') AS gestion,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_mt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_mt'::text)::integer, 'fr'::character varying)
	END AS milieu_terrestre,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ah'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ah'::text)::integer, 'fr'::character varying)
	END AS activite_humaine,
	
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ma'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ma'::text)::integer, 'fr'::character varying)
	END AS milieu_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ri'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ri'::text)::integer, 'fr'::character varying)
	END AS rive,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ve'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ve'::text)::integer, 'fr'::character varying)
	END AS var_niv_eau,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_eu'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_eu'::text)::integer, 'fr'::character varying)
	END AS euthrophisation,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_co'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_co'::text)::integer, 'fr'::character varying)
	END AS courant,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_va'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_va'::text)::integer, 'fr'::character varying)
	END AS vegetation_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_tp'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying)
	END AS temperature,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_cn'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying)
	END AS couv_nuageuse,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_vt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying)
	END AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
    r.nom_role || ' ' || r.prenom_role as determiner,
    obs.id_milieu,
    obs.milieu,
    obs.patrimonialite,
	obs.statut_bern,
    obs.statut_dir_hab,
    obs.statut_lrm,
    obs.statut_lre,
    obs.statut_lrn,
    obs.statut_lrr,
    obs.prior_action_pub,
    obs.protect_nat,
    obs.cites,
    (obs.data ->> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ab'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ab'::text)::integer, 'fr'::character varying)
	END AS abondance,
	obs.data->>'autochtonie' as autochtonie,
	irs.indice_repro,
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
     JOIN pass USING (id_base_visit)
     LEFT JOIN tr USING (id_base_site)
	 LEFT JOIN utilisateurs.t_roles r ON (obs.data->>'determiner') = id_role::text
	 LEFT JOIN irs USING (id_observation)
  ORDER BY ((pass.data -> 'annee'::text)::integer) DESC, tr.site_code, tr.transect_name,  ((pass.data -> 'num_passage'::text)::integer) DESC, obs.id_observation;

GRANT SELECT ON TABLE gn_monitoring.v_export_steli_obs_2 TO geonat_visu;
	
CREATE OR REPLACE VIEW gn_monitoring.v_export_steli_obs_n
AS
 WITH 
 	patri_hn AS (
         SELECT cor_taxon_attribut.valeur_attribut,
            cor_taxon_attribut.cd_ref
           FROM taxonomie.cor_taxon_attribut
          WHERE cor_taxon_attribut.id_attribut = 7
        ), 
	milieux AS (
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
        ), 
	tr AS (
         SELECT tbs.id_base_site,
            tsg.sites_group_name AS site_code,
            tsg.sites_group_description AS site_name,
            tsg.data ->> 'commune'::text AS site_com,
            la.area_name,
            tbs.base_site_name AS transect_name,
            tbs.altitude_min,
            tbs.altitude_max,
            tbs.geom_local AS geom,
            st_centroid(tbs.geom) AS centroid,
            st_astext(tbs.geom) AS geom_wkt
           FROM gn_monitoring.t_base_sites tbs
             LEFT JOIN gn_monitoring.t_site_complements tsc USING (id_base_site)
             LEFT JOIN gn_monitoring.t_sites_groups tsg USING (id_sites_group)
             LEFT JOIN ref_geo.l_areas la ON tsg.sites_group_name::text = la.area_code::text
          WHERE tsg.id_module = 30
          ORDER BY tsg.sites_group_name, tbs.base_site_name
        ), 
	pass AS (
         SELECT tbv.id_base_visit,
            tbv.id_base_site,
            tbv.visit_date_min AS pass_date,
            tvc.data
           FROM gn_monitoring.t_base_visits tbv
             LEFT JOIN gn_monitoring.t_visit_complements tvc USING (id_base_visit)
          WHERE tbv.id_module = 30
        ),
	obs AS (
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
            patri.valeur_attribut AS patrimonialite
           FROM gn_monitoring.t_observations o
             LEFT JOIN gn_monitoring.t_observation_complements toc USING (id_observation)
             LEFT JOIN taxonomie.taxref tx USING (cd_nom)
             LEFT JOIN milieux mil USING (cd_ref)
             LEFT JOIN patri_hn patri USING (cd_ref)
    ), 
	observers AS (
         SELECT array_agg(r.id_role) AS ids_observers,
            string_agg(concat(r.nom_role, ' ', r.prenom_role), ' ; '::text) AS observers,
            cvo.id_base_visit
           FROM gn_monitoring.cor_visit_observer cvo
             JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
          GROUP BY cvo.id_base_visit
    ),
	ir as (
		SELECT
			id_observation,
			ref_nomenclatures.get_nomenclature_label( 
				jsonb_array_elements (toc.data -> 'id_nomenclature_ir')::integer 
			) as ir_label
		FROM gn_monitoring.t_observation_complements toc
		WHERE NOT toc.data ->> 'id_nomenclature_ir' IS NULL
	),
	irs as (
		SELECT
			id_observation,
			STRING_AGG(DISTINCT ir_label, ', ') as indice_repro
		FROM ir
		GROUP BY id_observation
	)
 SELECT 
 	obs.id_observation,
    tr.site_code,
    tr.site_name,
    tr.site_com,
    tr.transect_name,
    (pass.data ->> 'annee')::integer AS pass_annee,
    (pass.data ->> 'periode')::integer AS periode,
    (pass.data ->> 'num_passage')::integer AS pass_num,
    pass.pass_date,
    (pass.data ->> 'heure_debut')::text AS pass_heure,
    observers.observers AS observateurs,
    (pass.data ->> 'gestion') AS gestion,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_mt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_mt'::text)::integer, 'fr'::character varying)
	END AS milieu_terrestre,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ah'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ah'::text)::integer, 'fr'::character varying)
	END AS activite_humaine,
	
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ma'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ma'::text)::integer, 'fr'::character varying)
	END AS milieu_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ri'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ri'::text)::integer, 'fr'::character varying)
	END AS rive,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ve'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ve'::text)::integer, 'fr'::character varying)
	END AS var_niv_eau,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_eu'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_eu'::text)::integer, 'fr'::character varying)
	END AS euthrophisation,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_co'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_co'::text)::integer, 'fr'::character varying)
	END AS courant,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_va'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_va'::text)::integer, 'fr'::character varying)
	END AS vegetation_aquatique,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_tp'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_tp'::text)::integer, 'fr'::character varying)
	END AS temperature,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_cn'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_cn'::text)::integer, 'fr'::character varying)
	END AS couv_nuageuse,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_vt'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_vt'::text)::integer, 'fr'::character varying)
	END AS vent,
    obs.cd_nom,
    obs.nom_valide,
    obs.nom_vern,
    r.nom_role || ' ' || r.prenom_role as determiner,
    obs.id_milieu,
    obs.milieu,
    obs.patrimonialite,
    (obs.data ->> 'effectif'::text)::integer AS effectif_total,
        CASE
            WHEN ((obs.data -> 'nb_male'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_male'::text)::integer
        END AS nb_male,
        CASE
            WHEN ((obs.data -> 'nb_femelle'::text)::text) = 'null'::text THEN NULL::integer
            ELSE (obs.data -> 'nb_femelle'::text)::integer
        END AS nb_femelle,
	CASE
		WHEN (pass.data ->> 'id_nomenclature_ab'::text) IS NULL THEN NULL::character varying
		ELSE ref_nomenclatures.get_nomenclature_label((pass.data -> 'id_nomenclature_ab'::text)::integer, 'fr'::character varying)
	END AS abondance,
	obs.data->>'autochtonie' as autochtonie,
	irs.indice_repro,
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
     JOIN pass USING (id_base_visit)
     LEFT JOIN tr USING (id_base_site)
	 LEFT JOIN utilisateurs.t_roles r ON (obs.data->>'determiner') = id_role::text
	 LEFT JOIN irs USING (id_observation)
  WHERE (pass.data -> 'annee'::text)::integer::double precision = date_part('year'::text, now())
  ORDER BY ((pass.data -> 'annee'::text)::integer) DESC, tr.site_code, tr.transect_name,  ((pass.data -> 'num_passage'::text)::integer) DESC, obs.id_observation;

GRANT SELECT ON TABLE gn_monitoring.v_export_steli_obs_n TO geonat_visu;