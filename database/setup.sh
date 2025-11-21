
#!/bin/bash
set -e

# -----------------------------------------------
# Create PostGIS database and import OSM PBF data
# -----------------------------------------------

DB_NAME="tempo30-eligibility"
DB_OWNER="postgres"
PBF_FILE_NAME="bremen-251117.osm.pbf"
PBF_PATH="data/$PBF_FILE_NAME"

# Check PBF file
if [ ! -f "$PBF_PATH" ]; then
    echo "PBF file not found: $PBF_PATH"
    exit 1
fi

# Create database
sudo -u postgres psql -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_OWNER\";"

# Enable PostGIS
sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Import OSM PBF
osm2pgsql --create --hstore -d "$DB_NAME" "$PBF_PATH"

#!/bin/bash
set -e

