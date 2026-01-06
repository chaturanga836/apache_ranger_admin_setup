#!/bin/bash
set -e

# 1. Path to the System Java Truststore (for eclipse-temurin:8)
SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# 2. Import the certificate into the System Truststore
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "Importing LDAP CA certificate into System Java truststore..."
    # We use 'changeit' as it is the default Java password
    keytool -importcert -noprompt \
        -alias ldap-ca \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit || echo "Certificate already trusted."
fi

# 3. Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until pg_isready -h ranger-db -p 5432 -U postgres; do
  sleep 3
done

# 4. Run setup.sh if not configured
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "Running Ranger Admin setup..."
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 5. FIX: Patch the XML to force SSL=true
# Ranger setup.sh often defaults this to false even with ldaps:// url
ADMIN_CONF="${RANGER_HOME}/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml"
if [ -f "$ADMIN_CONF" ]; then
    echo "Ensuring ranger.ldap.url.ssl is true in config..."
    xmlstarlet ed -L -d "//property[name='ranger.ldap.url.ssl']" "$ADMIN_CONF"
    xmlstarlet ed -L -s "/configuration" -t elem -n "property" -v "" \
      -s "/configuration/property[last()]" -t elem -n "name" -v "ranger.ldap.url.ssl" \
      -s "/configuration/property[last()]" -t elem -n "value" -v "true" "$ADMIN_CONF"
fi

echo "Starting Ranger Admin Services..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start

# Keep container alive
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log