FROM eclipse-temurin:8-jdk

ENV RANGER_HOME=/opt/ranger
WORKDIR /opt/ranger

# Install dependencies
RUN apt-get update && apt-get install -y python3 python3-pip && \
    pip3 install --break-system-packages psycopg2-binary && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Ranger Admin build directory
COPY ranger-admin /opt/ranger

# Add PostgreSQL JDBC driver
COPY lib/postgresql-42.7.8.jar /opt/ranger/lib/

# Copy Python DB checker
COPY scripts/check_and_prepare_db.py /opt/ranger/scripts/check_and_prepare_db.py
RUN chmod +x /opt/ranger/scripts/check_and_prepare_db.py

# IMPORTANT FIX:
# DO NOT run setup.sh during build.
# Ranger setup needs to run at container startup (runtime), not build time.
# Running setup.sh during build bakes config into the image & breaks LDAP/Kerberos runtime config.
# So remove your earlier RUN that executed check_and_prepare_db here.
RUN echo "Skipping DB prepare at build stage."

# Ensure permissions
RUN chmod +x /opt/ranger/setup.sh && \
    chmod +x /opt/ranger/ews/ranger-admin-services.sh

# Entrypoint – performs:
# 1. Wait for DB
# 2. Run setup.sh if not configured
# 3. Start ranger-admin
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
