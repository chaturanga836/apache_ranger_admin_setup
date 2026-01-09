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
    xmlstarlet ed -L -u "//property[name='ranger.ldap.url']/value" -v "ldaps://144.24.127.112:636" "$ADMIN_CONF"
    xmlstarlet ed -L -u "//property[name='ranger.ldap.ssl.enabled']/value" -v "true" "$ADMIN_CONF"
    echo "[I] XML Patch applied."
fi

# 3. Start Service
echo "[I] Starting Ranger Admin..."
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh stop 2>/dev/null || true
./ranger-admin-services.sh start

# 4. Keep container alive and stream logs
REAL_LOG_DIR=$(find /opt/ranger -name logs -type d | grep ews | head -n 1)

if [ -z "$REAL_LOG_DIR" ]; then
    echo "[WARN] Could not find ews/logs directory, creating it..."
    mkdir -p /opt/ranger/ews/logs
    REAL_LOG_DIR="/opt/ranger/ews/logs"
fi

echo "[I] Waiting for Ranger to write its first log file in $REAL_LOG_DIR..."

# Wait up to 60 seconds for ANY log file to appear
for i in {1..20}; do
    LOG_FILE=$(ls $REAL_LOG_DIR/*.log 2>/dev/null | head -n 1)
    if [ -n "$LOG_FILE" ]; then
        echo "[I] Found log file: $LOG_FILE"
        break
    fi
    echo "Checking... ($i/20)"
    sleep 3
done

if [ -z "$LOG_FILE" ]; then
    echo "[ERROR] Ranger failed to create logs within 60 seconds."
    echo "[I] Listing directory contents for debug:"
    ls -R /opt/ranger/ews/
    exit 1
fi

echo "🚀 Streaming logs from $REAL_LOG_DIR..."
tail -f $REAL_LOG_DIR/*.log