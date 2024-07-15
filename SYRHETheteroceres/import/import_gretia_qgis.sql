to_json( 
    map(
        'uuid_gretia', "uuid_perm_sinp" ,
        'determiner', 381, -- Loïc Chéreau GRETIA
        'effectif',  "nombre_max",
        'id_nomenclature_loca_obs', 
            CASE 
            WHEN regexp_match( lower( "comment_occurrence" ) , 'dans') THEN 854
            WHEN regexp_match( lower( "comment_occurrence" ) , 'autour') THEN 853
            WHEN regexp_match( lower( "comment_occurrence" ) , 'hors') THEN 853
            WHEN regexp_match( lower( "comment_occurrence" ) , 'sous boite') THEN 857
            WHEN regexp_match( lower( "comment_occurrence" ) , 'sur bo') THEN 857
            WHEN regexp_match( lower( "comment_occurrence" ) , 'sur dr') THEN 858
            WHEN regexp_match( lower( "comment_occurrence" ) , 'sur pi') THEN 859
            ELSE null
            END,
        'id_nomenclature_obs_technique', 37,
        'id_nomenclature_determination_method', if( regexp_match("methode_determination" ,'individu en main'), 456 , 457),
        'id_nomenclature_sex', 
            CASE 
            WHEN "sexe" = 'Femelle' THEN 164
            WHEN "sexe" = 'Mâle' THEN 165
            ELSE 168
            END,
        'conservation', 'Non'
    )
)