#!/bin/sh
set -e

for db in $(echo "$SERVICE_DATABASES" | tr ',' ' '); do
  echo "  -> creating database '$db'"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    -c "CREATE DATABASE $db;"
done

echo "Databases created: $SERVICE_DATABASES"
