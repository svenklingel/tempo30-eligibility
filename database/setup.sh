#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------
# Start PostgreSQL if not running
# -----------------------------------------------
if ! systemctl is-active --quiet postgresql; then
    echo "PostgreSQL is not running. Starting service..."
    sudo systemctl start postgresql
    echo "PostgreSQL started."
fi

# -----------------------------------------------
# Create PostGIS database and import OSM PBF data
# -----------------------------------------------
DB_NAME="tempo30-eligibility"
DB_OWNER="postgres"
PBF_FILE_NAME="bremen-251117.osm.pbf"
PBF_PATH="$SCRIPT_DIR/data/$PBF_FILE_NAME"

# Check PBF file
if [ ! -f "$PBF_PATH" ]; then
    echo "PBF file not found: $PBF_PATH"
    exit 1
fi

# Copy PBF to /tmp for postgres user access
TMP_PBF="/tmp/$PBF_FILE_NAME"
echo "Copying PBF file to temporary location for database import..."
cp "$PBF_PATH" "$TMP_PBF"
chmod 644 "$TMP_PBF"

# Create database if it does not exist
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating database $DB_NAME..."
    sudo -u postgres psql -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_OWNER\";"
else
    echo "Database $DB_NAME already exists."
fi

# Enable PostGIS extensions
sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS hstore;"

# Import OSM PBF (performed as postgres!)
echo "Importing OSM data from $TMP_PBF..."
sudo -u postgres osm2pgsql --create --hstore -d "$DB_NAME" "$TMP_PBF"

# Clean up temporary file
rm "$TMP_PBF"

echo "Database setup completed."