#!/usr/bin/env bash
# Runs once, only against a fresh (empty) postgres data directory, via
# /docker-entrypoint-initdb.d/. The official postgres image only auto-creates
# the single database named by POSTGRES_DB (`app`), so this creates the
# second database Keycloak needs on the same instance.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE keycloak;
EOSQL
