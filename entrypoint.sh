#!/bin/bash
# Remove 'set -e' for the cert import section to prevent crashes
set -u 

echo "----------------------------------------------------"
echo "!!! CUSTOM ENTRYPOINT STARTING ON EC2 !!!"
echo "----------------------------------------------------"

cd ${RANGER_HOME}

# 1. Run Setup
if [ ! -f ".setup_done" ]; then
    echo "[I] Running Ranger setup.sh..."
    ./setup.sh && touch .setup_done
fi

# 2. Apply LDAPS Patch
echo "[I] Applying LDAPS and Certificate Patch..."
ADMIN_CONF="${RANGER_HOME}/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml"

# Find the correct cacerts path dynamically
SYSTEM_CACERTS=$(find /opt/java/openjdk -name cacerts)

if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "[I] Found certificate, importing to $SYSTEM_CACERTS..."
    # Delete if exists, ignore errors
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit -noprompt 2>/dev/null || true
    # Import
    keytool -import -trustcacerts -noprompt -alias ldap-cert -file /opt/ranger/certs/ca.crt -keystore "$SYSTEM_CACERTS" -storepass changeit
else
    echo "[WARN] /opt/ranger/certs/ca.crt not found!"
fi

# Patch XML using xmlstarlet
if [ -f "$ADMIN_CONF" ]; then
    xmlstarlet ed -L -u "//property[name='ranger.ldap.url']/value" -v "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636" "$ADMIN_CONF"
    xmlstarlet ed -L -u "//property[name='ranger.ldap.ssl.enabled']/value" -v "true" "$ADMIN_CONF"
    echo "[I] XML Patch applied."
fi

# 3. Start Service
echo "[I] Starting Ranger Admin..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh stop 2>/dev/null || true
./ranger-admin-services.sh start

# 4. Keep container alive and stream logs
echo "[I] Streaming logs..."
touch ${RANGER_HOME}/logs/ranger-admin-$(hostname)-root.log

while [ ! -f /opt/ranger/ews/logs/ranger-admin-$(hostname)-root.log ]; do
  sleep 2
done

# Now that the file exists, the * will work perfectly
echo "[I] Logs found! Streaming..."
tail -f /opt/ranger/ews/logs/ranger-admin-*.log