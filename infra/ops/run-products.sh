#!/bin/bash
cd /opt/banan
PG=$(docker compose --env-file infra/.env.prod -f docker-compose.prod.yml ps -q postgres)
docker cp /tmp/products.sql $PG:/tmp/products.sql
docker exec $PG sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/products.sql'
