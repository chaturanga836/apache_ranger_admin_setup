#!/bin/bash
set -e

# THE SIGNATURE - You should see this in docker logs immediately
echo "----------------------------------------------------"
echo "!!! CUSTOM ENTRYPOINT STARTING ON EC2 !!!"
echo "----------------------------------------------------"

# Fix permissions for all Ranger scripts to prevent "Permission Denied"
chmod +x ${RANGER_HOME}/*.sh
chmod +x ${RANGER_HOME}/ews/*.sh

# 1. Run Setup
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "[I] Running Ranger setup.sh..."
    cd ${RANGER_HOME}
    ./setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 2. Apply your "Manual Fix" automatically
echo "[I] Applying LDAPS and Certificate Patch..."
ADMIN_CONF="${RANGER_HOME}/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml"
SYSTEM_CACERTS="/opt/java/openjdk/jre/lib/security/cacerts"

# Patch XML
xmlstarlet ed -L -u "//property[name='ranger.ldap.url']/value" -v "ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636" "$ADMIN_CONF"
xmlstarlet ed -L -u "//property[name='ranger.ldap.ssl.enabled']/value" -v "true" "$ADMIN_CONF"

# Import Cert
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    chmod +w "$SYSTEM_CACERTS"
    keytool -delete -alias ldap-cert -keystore "$SYSTEM_CACERTS" -storepass changeit || true
    keytool -import -trustcacerts -noprompt -alias ldap-cert -file /opt/ranger/certs/ca.crt -keystore "$SYSTEM_CACERTS" -storepass changeit
fi

# 3. THE RESTART (Crucial part of your manual fix)
echo "[I] Restarting Ranger to refresh JVM Truststore..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh stop || true
pkill -9 -f 'java' || true
sleep 2
./ranger-admin-services.sh start

# 4. Stream Logs
echo "[I] Streaming Ranger logs to console..."
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log