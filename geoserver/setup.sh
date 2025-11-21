#!/bin/bash
set -e

# -----------------------------------------------
# GeoServer Setup Script (Workspace, DataStores, Layer)
# -----------------------------------------------

# ------------------------
# Konfiguration
# ------------------------
GEOSERVER_HOME="/usr/local/lib/geoserver-2.22.2"
GEOSERVER_REST="http://localhost:8082/geoserver/rest"
GEOSERVER_USER="admin"
GEOSERVER_PASS="geoserver"

WORKSPACE="roads_ws"  # wie im Proxy
DATASTORE="roads_store"  # Name des Datastores für OSM / PostGIS
DB_NAME="tempo30_eligibility"  # PostGIS DB
DB_USER="postgres"
DB_PASS="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# FeatureLayers / Tabellen in PostGIS
LAYER1="planet_osm_roads"
LAYER2="eligable_roads"

# ------------------------
# GeoServer starten
# ------------------------
echo "Starte GeoServer..."
nohup "$GEOSERVER_HOME/bin/start_admin.sh" > geoserver.log 2>&1 &
sleep 10  # kurz warten, bis GeoServer hochgefahren ist

# ------------------------
# Workspace erstellen
# ------------------------
echo "Erstelle Workspace: $WORKSPACE"
curl -u "$GEOSERVER_USER:$GEOSERVER_PASS" -XPOST \
  -H "Content-type: application/json" \
  -d "{\"workspace\": {\"name\": \"$WORKSPACE\"}}" \
  "$GEOSERVER_REST/workspaces"

# ------------------------
# DataStore erstellen (PostGIS)
# ------------------------
echo "Erstelle DataStore: $DATASTORE"
curl -u "$GEOSERVER_USER:$GEOSERVER_PASS" -XPOST \
  -H "Content-type: application/json" \
  -d "{
    \"dataStore\": {
      \"name\": \"$DATASTORE\",
      \"connectionParameters\": {
        \"entry\": [
          {\"@key\":\"host\",\"$\":\"$DB_HOST\"},
          {\"@key\":\"port\",\"$\":\"$DB_PORT\"},
          {\"@key\":\"database\",\"$\":\"$DB_NAME\"},
          {\"@key\":\"user\",\"$\":\"$DB_USER\"},
          {\"@key\":\"passwd\",\"$\":\"$DB_PASS\"},
          {\"@key\":\"dbtype\",\"$\":\"postgis\"}
        ]
      }
    }
  }" \
  "$GEOSERVER_REST/workspaces/$WORKSPACE/datastores"

# ------------------------
# FeatureTypes / Layer erstellen
# ------------------------
for LAYER in "$LAYER1" "$LAYER2"; do
  echo "Erstelle FeatureType / Layer: $LAYER"
  curl -u "$GEOSERVER_USER:$GEOSERVER_PASS" -XPOST \
    -H "Content-type: application/json" \
    -d "{\"featureType\": {\"name\": \"$LAYER\"}}" \
    "$GEOSERVER_REST/workspaces/$WORKSPACE/datastores/$DATASTORE/featuretypes"
done

echo "GeoServer Setup abgeschlossen!"
echo "Workspace: $WORKSPACE"
echo "DataStore: $DATASTORE"
echo "Feature Layers: $LAYER1, $LAYER2"
echo "GeoServer URL: http://localhost:8082/geoserver"
