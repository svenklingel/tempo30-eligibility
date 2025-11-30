#!/bin/bash
set -e  

echo "Setup started."

# Initialize database
./database/setup.sh
echo "Database initialized."

# Perform analysis
./database/analyze.sh
echo "Eligible roads identified."

# Initialize GeoServer
./geoserver/setup.sh
echo "GeoServer configured."

# Initialize Proxy
./proxy/setup.sh
echo "Proxy initialized."

echo "Full setup completed."
