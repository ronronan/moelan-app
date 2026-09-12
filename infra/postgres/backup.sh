#!/usr/bin/env bash
# Dumps both databases (app + keycloak) from the running postgres
# container to timestamped, gzipped files. Run from the repo root:
#   ./infra/postgres/backup.sh [destination-dir]
# Wire into cron for regular backups, e.g. nightly at 3am:
#   0 3 * * * cd /path/to/moelan-app && ./infra/postgres/backup.sh /var/backups/moelan >> /var/log/moelan-backup.log 2>&1
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
set -a; source .env; set +a

DEST="${1:-./backups}"
mkdir -p "$DEST"
STAMP=$(date +%Y%m%d-%H%M%S)

for db in app keycloak; do
    OUT="$DEST/${db}-${STAMP}.sql.gz"
    docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$db" | gzip > "$OUT"
    echo "Backed up $db to $OUT"
done

# Keep the last 14 backups per database; adjust to taste.
for db in app keycloak; do
    ls -1t "$DEST/${db}-"*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm --
done
