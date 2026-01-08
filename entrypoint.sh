#!/bin/bash
set -e

# Target the path you verified works manually
SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# 1. Wait for DB
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Waiting for DB..."
  sleep 2
done

# 2. Run Ranger Setup (DO THIS FIRST)
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "[I] Running Ranger setup.sh..."
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 3. NOW IMPORT THE CERTIFICATE (After setup has finished)
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "[I] Importing ca.crt into $SYSTEM_CACERTS..."
    # Ensure write permissions
    chmod +w "$SYSTEM_CACERTS"
    # Clean up old entry and import fresh
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    keytool -import -trustcacerts -noprompt \
        -alias ldap-cert \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit
    echo "[V] Success: Certificate trusted."
else
    echo "[E] ERROR: /opt/ranger/certs/ca.crt missing!"
    exit 1
fi

# 4. Patch XML configurations
echo "[I] Patching XML for LDAP SSL..."
CONF="conf/ranger-ugsync-site.xml"
update_prop() {
    local name=$1
    local value=$2
    if xmlstarlet sel -t -v "//property[name='$name']" "$CONF" > /dev/null 2>&1; then
        xmlstarlet ed -L -u "//property[name='$name']/value" -v "$value" "$CONF"
    else
        xmlstarlet ed -L -s "/configuration" -t elem -n "property" -v "" \
            -s "/configuration/property[last()]" -t elem -n "name" -v "$name" \
            -s "/configuration/property[last()]" -t elem -n "value" -v "$value" "$CONF"
    fi
}

update_prop "ranger.usersync.ldap.sslEnabled" "true"
update_prop "ranger.usersync.truststore.file" "$SYSTEM_CACERTS"
update_prop "ranger.usersync.truststore.password" "changeit"
update_prop "ranger.usersync.ldap.ssl.truststore" "$SYSTEM_CACERTS"
update_prop "ranger.usersync.ldap.ssl.truststore.password" "changeit"
update_prop "ranger.usersync.ldap.url" "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636"

# 5. Start the service
cd ${RANGER_HOME}/ews
# ./ranger-admin-services.sh start
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log