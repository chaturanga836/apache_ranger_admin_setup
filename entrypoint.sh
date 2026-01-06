#!/bin/bash
set -e

# 1. Dynamically find the correct truststore
SYSTEM_CACERTS=$(find $JAVA_HOME -name cacerts | head -n 1)
echo "Using Java Home: $JAVA_HOME"
echo "Targeting Truststore: $SYSTEM_CACERTS"

# 2. Import the LDAP CA (Mandatory for SSL)
if [ -f "/opt/ranger/certs/ca.crt" ]; then
    echo "Found ca.crt. Importing..."
    keytool -delete -alias ldap-ca -keystore "$SYSTEM_CACERTS" -storepass changeit 2>/dev/null || true
    keytool -importcert -noprompt -alias ldap-ca -file /opt/ranger/certs/ca.crt \
            -keystore "$SYSTEM_CACERTS" -storepass changeit
else
    echo "ERROR: /opt/ranger/certs/ca.crt missing."
    exit 1
fi

# 3. Update install.properties BEFORE running setup.sh
# This ensures the AWS hostname is baked into the config
INSTALL_PROPS="${RANGER_HOME}/install.properties"
LDAP_URL="ldaps://ec2-65-0-150-75.ap-south-1.compute.amazonaws.com:636"

if [ -f "$INSTALL_PROPS" ]; then
    echo "Updating $INSTALL_PROPS with the correct LDAPS URL..."
    # Update the URL
    sed -i "s|^AUTH_LDAP_URL=.*|AUTH_LDAP_URL=${LDAP_URL}|" "$INSTALL_PROPS"
    # Ensure SSL is enabled in properties
    sed -i "s|^AUTH_LDAP_URL_SSL=.*|AUTH_LDAP_URL_SSL=true|" "$INSTALL_PROPS"
else
    echo "Warning: install.properties not found at $INSTALL_PROPS"
fi

# 4. Wait for DB
until pg_isready -h ranger-db -p 5432 -U postgres; do
  echo "Waiting for DB..."
  sleep 2
done

# 5. Run setup (it will now use the updated install.properties)
if [ ! -f "${RANGER_HOME}/.setup_done" ]; then
    echo "Running Ranger Setup with updated properties..."
    ${RANGER_HOME}/setup.sh
    touch ${RANGER_HOME}/.setup_done
fi

# 6. Start the service
cd ${RANGER_HOME}/ews
./ranger-admin-services.sh start
tail -f ${RANGER_HOME}/logs/ranger-admin-*.log