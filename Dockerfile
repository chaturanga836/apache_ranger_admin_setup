FROM eclipse-temurin:8-jdk

ENV RANGER_HOME=/opt/ranger
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop/hadoop-3.3.6
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
ENV CLASSPATH=$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/common/lib/*
WORKDIR /opt/ranger

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    xmlstarlet \
    postgresql-client \
    && pip3 install --break-system-packages psycopg2-binary \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $HADOOP_HOME && \
    wget -qO- https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    | tar -xz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME

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

COPY certs/tls.crt /opt/ranger/certs/ca.crt
# Entrypoint – performs:
# 1. Wait for DB
# 2. Run setup.sh if not configured
# 3. Start ranger-admin
# COPY scripts/entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# CMD ["/entrypoint.sh"]

COPY scripts/entrypoint.sh /entrypoint.sh

# FIX 1: Convert to Unix line endings (Crucial for EC2/Ubuntu)
RUN apt-get update && apt-get install -y dos2unix && \
    dos2unix /entrypoint.sh && \
    chmod +x /entrypoint.sh

# FIX 2: Use ENTRYPOINT instead of CMD
# This makes the script the "Owner" of the container process
ENTRYPOINT ["/entrypoint.sh"]
