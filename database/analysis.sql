-- 1. Alte Tabelle löschen (falls vorhanden), damit das Skript wiederholbar ist
DROP TABLE IF EXISTS tempo30_analyse_ergebnis;

-- 2. Neue Tabelle erstellen basierend auf der Analyse
CREATE TABLE tempo30_analyse_ergebnis AS
WITH 
-- 0. DEFINITION DER BOUNDING BOX (Der Analyse-Bereich)
analysis_bbox AS (
    SELECT ST_Transform(
        ST_MakeEnvelope(
            8.787509625498963,  53.0709780564462,  -- Min Lon, Min Lat
            8.828257319140798,  53.07695241955986, -- Max Lon, Max Lat
            4326
        ), 
        3857 -- Transformation in das Format der osm2pgsql-Datenbank
    ) as geom
),

-- 1. Relevante Straßen abrufen
relevant_roads AS (
    SELECT 
        p.osm_id,
        p.highway,
        p.name,
        ST_Transform(p.way, 25832) as geom 
    FROM planet_osm_line p, analysis_bbox b
    WHERE p.way && b.geom 
      AND p.highway IN ('residential', 'primary', 'secondary', 'tertiary')
      AND p.highway != 'living_street' 
      AND (
          (p.tags->'maxspeed') IS NULL 
          OR 
          ((p.tags->'maxspeed') ~ '^[0-9]+$' AND (p.tags->'maxspeed')::integer > 30)
          OR
          (
             NOT (p.tags->'maxspeed') ~ '^[0-9]+$' 
             AND (p.tags->'maxspeed') NOT IN ('DE:zone:30', 'DE:zone:20', 'walk', 'DE:living_street')
          )
      )
),

-- 2. Trigger-Objekte: Soziale Einrichtungen
social_triggers AS (
    -- Polygone
    SELECT ST_Transform(p.way, 25832) as geom
    FROM planet_osm_polygon p, analysis_bbox b
    WHERE p.way && b.geom
      AND (p.amenity IN ('school', 'kindergarten', 'childcare', 'nursing_home', 'hospital')
       OR (p.amenity = 'social_facility' AND (p.tags->'social_facility:for') = 'senior')
       OR p.leisure = 'playground')
    
    UNION ALL
    
    -- Punkte
    SELECT ST_Buffer(ST_Transform(p.way, 25832), 1) as geom
    FROM planet_osm_point p, analysis_bbox b
    WHERE p.way && b.geom
      AND (p.amenity IN ('school', 'kindergarten', 'childcare', 'nursing_home', 'hospital')
       OR (p.amenity = 'social_facility' AND (p.tags->'social_facility:for') = 'senior')
       OR (p.highway = 'crossing' AND ((p.tags->'crossing') = 'zebra' OR (p.tags->'crossing_ref') = 'zebra')))
),

-- 3. Trigger-Objekte: Lärmschutz / Wohngebäude
noise_triggers AS (
    SELECT ST_Transform(p.way, 25832) as geom
    FROM planet_osm_polygon p, analysis_bbox b
    WHERE p.way && b.geom
      AND p.building IN ('residential', 'apartments', 'house', 'terrace')
),

-- 4. MASKEN ERSTELLEN
check_mask_social AS (
    SELECT ST_Union(ST_Buffer(geom, 50)) as geom FROM social_triggers
),
check_mask_noise AS (
    SELECT ST_Union(ST_Buffer(geom, 15)) as geom FROM noise_triggers
),
geo_mask_social AS (
    SELECT ST_Union(ST_Buffer(geom, 150)) as geom FROM social_triggers
),
geo_mask_noise AS (
    SELECT ST_Union(ST_Buffer(geom, 150)) as geom FROM noise_triggers
),

-- 5. Initiale Zuweisung
initial_tempo30 AS (
    -- A. Automatisch: Wohnstraßen
    SELECT osm_id, geom FROM relevant_roads WHERE highway = 'residential'

    UNION ALL

    -- B. Soziale Einrichtungen
    SELECT 
        r.osm_id,
        ST_Intersection(r.geom, large.geom) as geom
    FROM relevant_roads r, check_mask_social small, geo_mask_social large
    WHERE r.highway IN ('primary', 'secondary', 'tertiary')
      AND ST_Intersects(r.geom, small.geom)
      AND ST_Intersects(r.geom, large.geom)

    UNION ALL

    -- C. Lärmschutz
    SELECT 
        r.osm_id,
        ST_Intersection(r.geom, large.geom) as geom
    FROM relevant_roads r, check_mask_noise small, geo_mask_noise large
    WHERE r.highway IN ('primary', 'secondary', 'tertiary')
      AND ST_Intersects(r.geom, small.geom)
      AND ST_Intersects(r.geom, large.geom)
),

-- 6. Lückenschluss (< 500m)
gap_fill_mask AS (
    SELECT ST_Union(ST_Buffer(geom, 250)) as geom
    FROM initial_tempo30
)

-- 7. Finale Ausgabe in die Tabelle
SELECT 
    row_number() over() as id, -- Primärschlüssel-Kandidat
    r.osm_id,
    r.name,
    r.highway,
    CASE 
        WHEN r.highway = 'residential' THEN 'Wohngebiet (Automatisch)'
        WHEN t30.osm_id IS NOT NULL THEN 'Schutzbereich (300m Zone)'
        ELSE 'Lückenschluss (<500m)'
    END as begruendung,
    ST_Multi(ST_Transform(ST_Intersection(r.geom, g.geom), 3857)) as geom -- ST_Multi für Einheitlichkeit
FROM relevant_roads r
JOIN gap_fill_mask g ON ST_Intersects(r.geom, g.geom)
LEFT JOIN initial_tempo30 t30 ON r.osm_id = t30.osm_id
WHERE NOT ST_IsEmpty(ST_Intersection(r.geom, g.geom));

-- 3. Aufräumen & Indizierung (Wichtig für Performance!)
ALTER TABLE tempo30_analyse_ergebnis ADD PRIMARY KEY (id);
CREATE INDEX idx_tempo30_res_geom ON tempo30_analyse_ergebnis USING GIST (geom);

-- Optional: Rückmeldung über die Anzahl der erstellten Zonen
SELECT count(*) as anzahl_zonen_segmente FROM tempo30_analyse_ergebnis;