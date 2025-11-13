#!/usr/bin/env python3
import os
import psycopg2
import subprocess

INSTALL_PROPS = "/opt/ranger/install.properties"

def parse_properties(path):
    props = {}
    if not os.path.exists(path):
        print(f"⚠️  install.properties not found at {path}")
        return props
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
    return props


def check_db_connection(props):
    try:
        conn = psycopg2.connect(
            host=props.get("db_host", "localhost"),
            port=props.get("db_port", "5432"),
            dbname=props.get("db_name", "ranger"),
            user=props.get("db_user", "rangeradmin"),
            password=props.get("db_password", "")
        )
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM information_schema.tables WHERE table_name='x_portal_user';")
        result = cur.fetchone()
        cur.close()
        conn.close()
        if result:
            print("✅ Ranger DB schema already initialized.")
            return True
        else:
            print("⚠️  Ranger DB exists but schema missing — will initialize.")
            return False
    except Exception as e:
        print(f"❌ Could not connect to database: {e}")
        return False


def initialize_db(props):
    print("🟢 Initializing Ranger DB schema...")
    ranger_db_script = "/opt/ranger/db_setup.py"
    if not os.path.exists(ranger_db_script):
        print(f"⚠️  Ranger DB setup script not found: {ranger_db_script}")
        return

    cmd = ["python3", ranger_db_script]
    env = os.environ.copy()
    env.update({
        "db_root_user": props.get("db_root_user", "postgres"),
        "db_root_password": props.get("db_root_password", ""),
        "db_user": props.get("db_user", "rangeradmin"),
        "db_password": props.get("db_password", ""),
        "db_name": props.get("db_name", "ranger"),
        "db_host": props.get("db_host", "localhost"),
        "db_port": props.get("db_port", "5432"),
    })

    try:
        subprocess.run(cmd, check=True, env=env)
        print("✅ Ranger DB initialized successfully.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Ranger DB initialization failed: {e}")


def main():
    props = parse_properties(INSTALL_PROPS)
    if not props:
        print("⚠️  Missing install.properties — skipping DB check.")
        return

    if not check_db_connection(props):
        initialize_db(props)


if __name__ == "__main__":
    main()
