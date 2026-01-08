#!/bin/bash
set -e

SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# 1. Run Setup
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 2. THE TRICK: Kill everything to ensure a clean slate
echo "[I] Cleaning up any background processes from setup..."
${RANGER_HOME}/ews/ranger-admin-services.sh stop || true
pkill -f 'java' || true
sleep 2

# 3. IMPORT THE CERTIFICATE (Now that we know no Java is running)
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "[I] Importing certificate..."
    chmod +w "$SYSTEM_CACERTS"
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    keytool -import -trustcacerts -noprompt \
        -alias ldap-cert \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit
fi

# 4. START THE SERVICE FRESH
echo "[I] Starting Ranger Admin Service (Fresh JVM)..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start

# Keep alive
tail -f /opt/ranger-admin/logs/ranger-admin-*.log