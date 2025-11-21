#!/bin/bash
set -e  # Skript stoppt bei Fehlern

echo "Setup started."

# Datenbank aufsetzen
./database/setup.sh
echo "Database initialized."

# Analyse durchführen 
./database/analyze.sh
echo "Eligible roads identified."

# GeoServer konfigurieren
./geoserver/setup.sh
echo "GeoServer configured."

echo "Full setup completed."
