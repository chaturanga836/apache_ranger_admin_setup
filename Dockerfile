# ===============================
# Dockerfile.admin
# ===============================
FROM openjdk:8-jdk

ENV RANGER_HOME=/opt/ranger
WORKDIR /opt/ranger

# Install dependencies
RUN apt-get update && apt-get install -y bc curl

# Copy extracted Ranger admin tarball (already extracted)
COPY ranger-admin /opt/ranger

# Copy Postgres JDBC driver
COPY lib/postgresql-42.7.8.jar /opt/ranger/lib/

# Make setup and service scripts executable
RUN chmod +x ${RANGER_HOME}/setup.sh ${RANGER_HOME}/ews/ranger-admin-services.sh

# Run setup to initialize DB schema and configuration
# RUN ${RANGER_HOME}/setup.sh

# Expose web UI
EXPOSE 6080

# Start Ranger Admin service
CMD ["/bin/bash", "-c", "/opt/ranger/ews/ranger-admin-services.sh start && tail -f /opt/ranger/ews/logs/ranger-admin-*.log"]
