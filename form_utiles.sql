UPDATE gn_monitoring.t_observation_complements oc 
SET data =  jsonb_set(
	 data::jsonb,
	 ARRAY ['determiner'],
	 to_jsonb(381),
	 true
)
WHERE oc.id_observation > 3021 and oc.id_observation < 3297
;

UPDATE gn_monitoring.t_observation_complements
SET data = NULL::jsonb
WHERE id_observation >= 3021
;


UPDATE gn_monitoring.t_observation_complements oc
	SET data = o.comments::jsonb
FROM gn_monitoring.t_observations o 
--LEFT JOIN t_base_visits v USING (ib_base_visit)
WHERE o.id_observation = oc.id_observation and o.id_observation > 3021 and o.id_observation < 3297
;

WITH site as (
SELECT * FROM gn_monitoring.t_base_sites
	LEFT JOIN gn_monitoring.t_site_complements USING (id_base_site)
)
SELECT 
	site.id_base_site,
	site.base_site_name,
	tbv.id_base_visit,
	tbv.visit_date_min
FROM gn_monitoring.t_base_visits tbv
LEFT JOIN site USING (id_base_site)
WHERE tbv.id_module = 27
ORDER BY tbv.id_base_site, tbv.visit_date_min
;


DROP FUNCTION IF EXISTS utilisateurs.get_name_by_id_role(integer);

CREATE OR REPLACE FUNCTION utilisateurs.get_name_by_id_role(
	roleId  integer )
    RETURNS character varying
    LANGUAGE 'plpgsql'
    COST 100
    IMMUTABLE PARALLEL UNSAFE
AS $BODY$
        BEGIN
            RETURN (
                SELECT nom_role || ' ' || prenom_role
                FROM utilisateurs.t_roles
                WHERE id_role = roleId -- nom_role = roleName
            );
        END;
    
$BODY$
;

-- STELI
SELECT 
	DISTINCT o.comments :: jsonb -> 'Rive'
FROM gn_monitoring.t_observation_complements toc
LEFT JOIN gn_monitoring.t_observations o USING (id_observation)
LEFT JOIN gn_monitoring.t_base_visits v USING (id_base_visit)
WHERE id_module = 30
;
SELECT * FROM ref_nomenclatures.v_0_nomen_active
WHERE mnemo_type LIKE '%STELI%'
ORDER BY mnemo_type ASC, cd_nomen ASC 
;

SELECT
 	(o.comments::jsonb -> 'Rive') ::text,
	ref_nomenclatures.get_id_nomenclature_by_mnemonique('STELI_RI', (o.comments::jsonb -> 'Rive') ::text)
FROM gn_monitoring.t_observation_complements toc
LEFT JOIN gn_monitoring.t_observations o USING (id_observation)
LEFT JOIN gn_monitoring.t_base_visits v USING (id_base_visit)
WHERE id_module = 30
;