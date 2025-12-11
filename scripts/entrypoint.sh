#!/bin/bash
set -e

echo "⏳ Waiting for PostgreSQL..."
/opt/ranger/scripts/check_and_prepare_db.py

if [ ! -f /opt/ranger/.db_initialized ]; then
    echo "🛠 Running Ranger setup.sh for first time..."
    /opt/ranger/setup.sh
    touch /opt/ranger/.db_initialized
fi

echo "🚀 Starting Ranger Admin..."
/opt/ranger/ews/ranger-admin-services.sh start

tail -f /opt/ranger/ews/logs/ranger-admin-*log
