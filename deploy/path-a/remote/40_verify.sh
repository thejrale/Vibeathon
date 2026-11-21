#!/usr/bin/env bash
# Container health + Postgres not exposed (host side).
set -uo pipefail
cd /opt/central || exit 1
fail=0
docker compose ps
echo "== Service states"
for svc in $(docker compose config --services); do
  id=$(docker compose ps -aq "$svc")
  [ -z "$id" ] && continue
  state=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}} exit={{.State.ExitCode}}' "$id")
  echo "$svc: $state"
  case "$svc:$state" in
    postgres:exited*exit=0|secrets:exited*exit=0) ;;   # one-shot jobs
    *:running*unhealthy*|*:exited*|*:restarting*) echo "FAIL $svc"; fail=1 ;;
  esac
done
echo "== Postgres exposure"
if [ -n "$(docker port "$(docker compose ps -q postgres14)")" ]; then echo "FAIL postgres publishes 5432"; fail=1; else echo "OK no published Postgres port"; fi
if ss -tlnH 'sport = :5432' | grep -q .; then echo "FAIL something listens on host :5432"; fail=1; else echo "OK nothing on host :5432"; fi
exit $fail
