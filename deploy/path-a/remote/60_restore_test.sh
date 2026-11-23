#!/usr/bin/env bash
# Restores the latest dump into a throwaway Postgres 14 container and compares row counts with live.
set -euo pipefail
latest=$(ls -1t /var/backups/odk/odk-*.dump | head -1)
echo "restoring $latest"
docker rm -f odk-restore-test >/dev/null 2>&1 || true
docker run -d --name odk-restore-test -e POSTGRES_PASSWORD=test -e POSTGRES_USER=odk -e POSTGRES_DB=odk postgres:14 >/dev/null
trap 'docker rm -f odk-restore-test >/dev/null' EXIT
until docker exec odk-restore-test pg_isready -U odk -q; do sleep 1; done
sleep 2
docker exec -i odk-restore-test pg_restore -U odk -d odk --no-owner < "$latest"
q="select (select count(*) from users) users, (select count(*) from projects) projects, (select count(*) from forms) forms, (select count(*) from submissions) submissions;"
live=$(docker compose -f /opt/central/docker-compose.yml exec -T postgres14 psql -U odk -d odk -Atc "$q")
restored=$(docker exec odk-restore-test psql -U odk -d odk -Atc "$q")
echo "live     users|projects|forms|submissions = $live"
echo "restored users|projects|forms|submissions = $restored"
if [ "$live" = "$restored" ]; then echo "OK restore matches live"; else echo "DIFF (expected if data changed since the dump)"; exit 1; fi
