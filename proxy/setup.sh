#!/bin/bash
# -----------------------------------------------
# Setup to install necessary libraries for Geoserver Proxy
# -----------------------------------------------

# Install Node.js and npm if missing
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Node.js and npm not found. Installation will start..."
    # NodeSource Repository hinzufügen (aktuelle LTS-Version)
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js and npm are already installed."
fi

# 2. Change to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create package.json if not present
if [ ! -f package.json ]; then
    echo "Creating package.json..."
    npm init -y
fi

# 4. Install required libraries (express, node-fetch)
echo "Installing missing libraries..."
npm install express node-fetch

echo "Installation complete. Proxy can now be started with 'node proxy.js'."
