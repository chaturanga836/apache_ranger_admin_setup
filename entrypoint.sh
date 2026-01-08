#!/bin/bash
set -e

# 1. Path to the truststore you verified
SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# 2. Wait for Postgres
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Waiting for DB..."
  sleep 2
done

# 3. Run Ranger Setup (This is where the overwrites happen)
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "[I] Running Ranger setup.sh..."
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 4. FIX THE CONFIGURATIONS (Do this AFTER setup.sh)
echo "[I] Setup finished. Patching configurations to force LDAPS..."

# ADMIN_CONF="${RANGER_HOME}/conf/ranger-admin-site.xml"
# SYNC_CONF="${RANGER_HOME}/conf/ranger-ugsync-site.xml"

# update_prop() {
#     local name=$1
#     local value=$2
#     local file=$3
#     # Delete then add to ensure it's clean and correctly formatted
#     xmlstarlet ed -L -d "//property[name='$name']" "$file"
#     xmlstarlet ed -L -s "/configuration" -t elem -n "property" -v "" \
#         -s "/configuration/property[last()]" -t elem -n "name" -v "$name" \
#         -s "/configuration/property[last()]" -t elem -n "value" -v "$value" "$file"
# }

# for FILE in "$ADMIN_CONF" "$SYNC_CONF"; do
#     if [ -f "$FILE" ]; then
#         echo "Updating $FILE..."
#         update_prop "ranger.ldap.url" "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636" "$FILE"
#         update_prop "ranger.ldap.ssl.enabled" "true" "$FILE"
#         update_prop "ranger.usersync.ldap.url" "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636" "$FILE"
#         update_prop "ranger.usersync.ldap.sslEnabled" "true" "$FILE"
#         # Force Ranger to look at the JRE truststore
#         update_prop "ranger.usersync.truststore.file" "$SYSTEM_CACERTS" "$FILE"
#     fi
# done

# 5. IMPORT THE CERTIFICATE (Last step before starting)
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "[I] Importing ca.crt into $SYSTEM_CACERTS..."
    chmod +w "$SYSTEM_CACERTS"
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    keytool -import -trustcacerts -noprompt \
        -alias ldap-cert \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit
fi

# 6. START THE SERVICE
echo "[I] Starting Ranger Admin..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start

# Keep container alive and show logs
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log