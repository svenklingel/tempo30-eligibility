#!/bin/bash
set -e  

echo "Setup started."

# Initialize database
./database/setup.sh
echo "Database initialized."

# Analyze data 
./database/analyze.sh
echo "Eligible roads identified."

# Initialize GeoServer
./geoserver/setup.sh
echo "GeoServer configured."

echo "Full setup completed."
