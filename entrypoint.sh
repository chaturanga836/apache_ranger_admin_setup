#!/bin/bash
set -e

# LDAPS CA truststore settings
JAVA_TRUSTSTORE=${RANGER_HOME}/certs/truststore.jks
JAVA_TRUSTSTORE_PASSWORD=changeit

# Import LDAP CA if not already imported
if [ ! -f "$JAVA_TRUSTSTORE" ]; then
    echo "Importing LDAP CA certificate into Java truststore..."
    mkdir -p $(dirname $JAVA_TRUSTSTORE)
    keytool -importcert -noprompt \
        -alias ldap-ca \
        -file ${RANGER_HOME}/certs/ca.crt \
        -keystore $JAVA_TRUSTSTORE \
        -storepass $JAVA_TRUSTSTORE_PASSWORD
fi

# Export truststore for Ranger JVM
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$JAVA_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=$JAVA_TRUSTSTORE_PASSWORD"

# Wait for PostgreSQL
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Postgres not ready yet, sleeping..."
  sleep 3
done

echo "PostgreSQL is up. Running Ranger setup..."

# Run Solr audit setup (optional, if using Solr)
echo "Running Solr audit setup..."
${RANGER_HOME}/contrib/solr_for_audit_setup/setup.sh

# Run setup.sh only if Ranger not initialized
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
else
    echo "Ranger alrea
