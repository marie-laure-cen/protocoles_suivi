-- fonction de base
UPDATE gn_monitoring.t_site_complements tsc 
SET
	data = jsonb_set(data::jsonb, '{surface_m2}',concat('"', ROUND(ST_area(geom_local)), '"')::jsonb, true)
FROM gn_monitoring.t_base_sites tbs
	WHERE tbs.id_base_site = tsc.id_base_site

-- trigger
CREATE OR REPLACE FUNCTION gn_monitoring.fct_get_surface_m2()
RETURNS TRIGGER as $$
BEGIN
	IF OLD.geom <> NEW.geom OR NOT EXISTS(OLD.geom)
		UPDATE gn_monitoring.t_base_sites tbs
		SET NEW.data = jsonb_set(data::jsonb, '{surface_m2}',concat('"', ROUND(ST_area(NEW.geom_local)), '"')::jsonb, true)
		FROM gn_monitoring.t_base_sites tbs
		WHERE tbs.id_base_site = NEW.id_base_site
	RETURN NEW
	;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER gn_monitoring.fct_trg_surface_m2
AFTER INSERT OR UPDATE ON gn_monitoring.t_base_sites
FOR EACH ROW 
WHEN (OLD.geom_local IS DISTINCT FROM NEW.geom_local) 
EXECUTE FUNCTION gn_monitoring.fct_get_surface_m2();