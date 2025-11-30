-- Drop table of old results
DROP TABLE IF EXISTS tempo30_analysis_result;

-- Create new table based on the analysis
CREATE TABLE tempo30_analysis_result AS
WITH 
-- 0. DEFINE THE BOUNDING BOX (analysis area)
analysis_bbox AS (
    SELECT ST_Transform(
        ST_MakeEnvelope(
            8.787509625498963,  53.0709780564462,  -- Min Lon, Min Lat
            8.828257319140798,  53.07695241955986, -- Max Lon, Max Lat
            4326
        ), 
        3857 -- Transform to the coordinate system of the osm2pgsql database
    ) as geom
),

-- Retrieve relevant roads
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

-- Get social facilities
social_triggers AS (
    -- Polygons
    SELECT ST_Transform(p.way, 25832) as geom
    FROM planet_osm_polygon p, analysis_bbox b
    WHERE p.way && b.geom
      AND (p.amenity IN ('school', 'kindergarten', 'childcare', 'nursing_home', 'hospital')
       OR (p.amenity = 'social_facility' AND (p.tags->'social_facility:for') = 'senior')
       OR p.leisure = 'playground')
    
    UNION ALL
    
    -- Points
    SELECT ST_Buffer(ST_Transform(p.way, 25832), 1) as geom
    FROM planet_osm_point p, analysis_bbox b
    WHERE p.way && b.geom
      AND (p.amenity IN ('school', 'kindergarten', 'childcare', 'nursing_home', 'hospital')
       OR (p.amenity = 'social_facility' AND (p.tags->'social_facility:for') = 'senior')
       OR (p.highway = 'crossing' AND ((p.tags->'crossing') = 'zebra' OR (p.tags->'crossing_ref') = 'zebra')))
),

-- Get residential buildings
noise_triggers AS (
    SELECT ST_Transform(p.way, 25832) as geom
    FROM planet_osm_polygon p, analysis_bbox b
    WHERE p.way && b.geom
      AND p.building IN ('residential', 'apartments', 'house', 'terrace')
),

-- Create masks
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

-- Initial assignment
initial_tempo30 AS (
    -- A. Automatic: Residential streets
    SELECT osm_id, geom FROM relevant_roads WHERE highway = 'residential'

    UNION ALL

    -- B. Social facilities
    SELECT 
        r.osm_id,
        ST_Intersection(r.geom, large.geom) as geom
    FROM relevant_roads r, check_mask_social small, geo_mask_social large
    WHERE r.highway IN ('primary', 'secondary', 'tertiary')
      AND ST_Intersects(r.geom, small.geom)
      AND ST_Intersects(r.geom, large.geom)

    UNION ALL

    -- C. Noise protection
    SELECT 
        r.osm_id,
        ST_Intersection(r.geom, large.geom) as geom
    FROM relevant_roads r, check_mask_noise small, geo_mask_noise large
    WHERE r.highway IN ('primary', 'secondary', 'tertiary')
      AND ST_Intersects(r.geom, small.geom)
      AND ST_Intersects(r.geom, large.geom)
),

-- Fill gaps (< 500m)
gap_fill_mask AS (
    SELECT ST_Union(ST_Buffer(geom, 250)) as geom
    FROM initial_tempo30
)

-- Final output table
SELECT 
    row_number() over() as id, -- Candidate primary key
    r.osm_id,
    r.name,
    r.highway,
    CASE 
        WHEN r.highway = 'residential' THEN 'Residential Area (Automatic)'
        WHEN t30.osm_id IS NOT NULL THEN 'Protected Zone (300m area)'
        ELSE 'Gap Fill (<500m)'
    END as justification,
    ST_Multi(ST_Transform(ST_Intersection(r.geom, g.geom), 3857)) as geom -- ST_Multi for consistency
FROM relevant_roads r
JOIN gap_fill_mask g ON ST_Intersects(r.geom, g.geom)
LEFT JOIN initial_tempo30 t30 ON r.osm_id = t30.osm_id
WHERE NOT ST_IsEmpty(ST_Intersection(r.geom, g.geom));

-- Indexing
ALTER TABLE tempo30_analysis_result ADD PRIMARY KEY (id);
CREATE INDEX idx_tempo30_res_geom ON tempo30_analysis_result USING GIST (geom);

-- Number of suitable roads
SELECT count(*) as number_of_zone_segments FROM tempo30_analysis_result;

-- ALlow access for GeoServer
GRANT USAGE ON SCHEMA public TO geoserver_user;
GRANT SELECT ON tempo30_analysis_result TO geoserver_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO geoserver_user;
