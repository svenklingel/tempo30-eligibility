#!/bin/bash
set -e

DB_NAME="tempo30-eligibility"
SQL_FILE="analysis.sql"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_PATH="$SCRIPT_DIR/$SQL_FILE"

# Determine eligible roads and store results in the output table
sudo -u postgres psql -d "$DB_NAME" -f "$SQL_PATH"
