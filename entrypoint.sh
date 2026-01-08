#!/bin/bash
set -e

SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# 1. Run Setup
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "[I] Running setup.sh..."
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# --- THE FIX: FORCE A CLEAN SLATE ---
echo "[I] Setup finished. Killing all background Java/Ranger processes to clear SSL cache..."
${RANGER_HOME}/ews/ranger-admin-services.sh stop || true
pkill -9 -f 'java' || true
sleep 5
# -------------------------------------

# 2. Patch XML (Ensure we have the right URL)
echo "[I] Patching XML for LDAPS..."
ADMIN_CONF="${RANGER_HOME}/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml"
xmlstarlet ed -L -u "//property[name='ranger.ldap.url']/value" -v "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636" "$ADMIN_CONF"
xmlstarlet ed -L -u "//property[name='ranger.ldap.ssl.enabled']/value" -v "true" "$ADMIN_CONF"

# 3. Import Certificate
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "[I] Importing certificate into $SYSTEM_CACERTS..."
    chmod +w "$SYSTEM_CACERTS"
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    keytool -import -trustcacerts -noprompt \
        -alias ldap-cert \
        -file /opt/ranger/certs/ca.crt \
        -keystore "$SYSTEM_CACERTS" \
        -storepass changeit
fi

echo "[I] Stopping any existing Ranger processes to apply SSL changes..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh stop || true

# 4. Final Start (This is the 'Manual Restart' but automated)
echo "[I] Starting Ranger Admin Service FRESH..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start

# Follow logs
RANGER_ADMIN_LOG=$(ls ${RANGER_HOME}/logs/ranger-admin-*.log | head -n 1)
# tail -f /opt/ranger-admin/logs/ranger-admin-*.log
exec tail -f "$RANGER_ADMIN_LOG"