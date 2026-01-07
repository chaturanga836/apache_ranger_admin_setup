#!/bin/bash
set -e

# 1. Use the ENV variable to find the correct truststore
# For Java 8, it is in jre/lib/security/
SYSTEM_CACERTS="${JAVA_HOME}/jre/lib/security/cacerts"

echo "Using Java Home: $JAVA_HOME"
echo "Targeting Truststore: $SYSTEM_CACERTS"

# 2. Import the LDAP CA
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "Found ca.crt. Importing into System Truststore..."
    
    # Delete if exists to prevent 'already exists' error
    keytool -delete -alias ldap-ca -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    
    # Import
    keytool -importcert -noprompt \
        -alias ldap-ca \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit
    
    echo "Success: Certificate imported into Ranger Admin's Java environment."
else
    echo "ERROR: /opt/ranger/certs/ca.crt is missing. Check your Dockerfile COPY command."
    exit 1
fi

# 3. Wait for DB
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Waiting for DB..."
  sleep 2
done

# 4. Run setup (only if not done)
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 5. Patch the XML for LDAPS (Crucial for John Doe)
echo "[I] Patching XML configurations..."
CONF="conf/ranger-ugsync-site.xml"

# Function to safely update or add properties
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

# Force these critical values to kill the NPE
update_prop "ranger.usersync.ldap.sslEnabled" "true"
update_prop "ranger.usersync.truststore.file" "/opt/java/openjdk/lib/security/cacerts"
update_prop "ranger.usersync.truststore.password" "changeit"
update_prop "ranger.usersync.ldap.ssl.truststore" "/opt/java/openjdk/lib/security/cacerts"
update_prop "ranger.usersync.ldap.ssl.truststore.password" "changeit"
update_prop "ranger.usersync.ldap.ssl.truststore.type" "JKS"
update_prop "ranger.usersync.ldap.url" "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636"

# 6. Start the service
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log