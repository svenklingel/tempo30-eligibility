#!/bin/bash
set -e

# ------------------------
# Konfiguration
# ------------------------
GEOSERVER_HOME="/usr/local/lib/geoserver-2.22.2"
GEOSERVER_REST_URL="http://localhost:8082/geoserver/rest/about/status.json"
HTML_FILE="frontend/map.html"
PROXY_SCRIPT="proxy.js"

# ------------------------
# 1️⃣ GeoServer starten
# ------------------------
echo "Starte GeoServer..."
nohup "$GEOSERVER_HOME/bin/start_admin.sh" > geoserver.log 2>&1 &

# ------------------------
# 2️⃣ Auf GeoServer warten
# ------------------------
echo "Warte auf GeoServer..."
MAX_RETRIES=30   # maximal 30 Versuche
SLEEP_SEC=2      # Wartezeit zwischen Versuchen

for ((i=1; i<=MAX_RETRIES; i++)); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GEOSERVER_REST_URL")
    if [ "$STATUS" -eq 200 ]; then
        echo "GeoServer ist bereit!"
        break
    else
        echo "GeoServer nicht bereit (Versuch $i/$MAX_RETRIES), warte $SLEEP_SEC Sekunden..."
        sleep $SLEEP_SEC
    fi

    if [ "$i" -eq $MAX_RETRIES ]; then
        echo "GeoServer konnte nicht gestartet werden. Skript wird beendet."
        exit 1
    fi
done

# ------------------------
# 3️⃣ Proxy starten
# ------------------------
echo "Starte GeoServer-Proxy..."
nohup node "$PROXY_SCRIPT" > proxy.log 2>&1 &
sleep 2
echo "GeoServer-Proxy gestartet"

# ------------------------
# 4️⃣ HTML Map öffnen
# ------------------------
echo "Öffne Map..."
if [ -f "$HTML_FILE" ]; then
    xdg-open "$HTML_FILE" &
    echo "Map geöffnet"
else
    echo "HTML file not found: $HTML_FILE"
fi

echo "✅ Master-Skript abgeschlossen"
