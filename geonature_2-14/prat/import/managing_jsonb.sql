SELECT 
	data::jsonb ? 'id_nomenclature_life_stage',
	data
--jsonb_set( data , '{effectif}', '0',false)
FROM gn_monitoring.t_observation_complements oc
LEFT JOIN  gn_monitoring.t_observations o ON oc.id_observation = o.id_observation 
LEFT JOIN gn_monitoring.t_base_visits v USING (id_base_visit)
WHERE data::jsonb ? 'id_nomenclature_life_stage' = false and v.id_module = 27