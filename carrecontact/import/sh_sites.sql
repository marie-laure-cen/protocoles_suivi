SELECT
	CONCAT(shc.Site, shc.Transect, shc.Plot) AS id_unique_plot,
	shc.Site AS id_site,
	shc.Date AS annee,
	shc.Transect AS transect,
	shc.Plot AS plot,
	max(shc.Coord_X) AS coord_x,
	max(shc.Coord_Y) AS coord_y,
	max(shc.Longitude) AS longitude,
	max(shc.Latitude) AS latitude
FROM sh_coord_carre shc
GROUP BY 
	shc.Site,
	shc.Date,
	shc.Transect,
	shc.Plot