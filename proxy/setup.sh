#!/bin/bash
set -e

# -----------------------------------------------
# Setup to install necessary libraries for the proxy
# -----------------------------------------------

# Install Node.js and npm if missing
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Node.js/npm not found. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js and npm are already installed."
fi

# Change to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create package.json if not present
if [ ! -f package.json ]; then
    echo "Creating package.json..."
    npm init -y
fi

# Install required libraries
echo "Installing dependencies..."
rm -rf node_modules 
npm install express node-fetch@2

echo "Proxy setup complete"
