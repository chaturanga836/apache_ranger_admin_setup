#!/bin/bash
set -e

echo "Waiting for Postgres to be ready..."
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Postgres not ready yet, sleeping..."
  sleep 3
done

echo "Postgres is up. Running Ranger setup..."
# Run setup only if not already initialized
if [ ! -f "${RANGER_HOME}/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml" ]; then
  ${RANGER_HOME}/setup.sh
else
  echo "Ranger already setup. Skipping setup.sh"
fi

echo "Starting Ranger Admin..."
${RANGER_HOME}/ews/ranger-admin-services.sh start

# Keep container alive by tailing logs
tail -f ${RANGER_HOME}/ews/logs/ranger-admin-*log
