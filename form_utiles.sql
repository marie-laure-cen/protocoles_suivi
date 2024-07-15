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