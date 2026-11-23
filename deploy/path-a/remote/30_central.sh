#!/usr/bin/env bash
# Clone the official getodk/central at a release tag, write .env, build and start.
set -euo pipefail
DOMAIN="$1" EMAIL="$2" VERSION="$3"
DIR=/opt/central
if [ ! -d "$DIR/.git" ]; then
  git clone https://github.com/getodk/central.git "$DIR"
fi
cd "$DIR"
git fetch --tags -q
git checkout -q "$VERSION"
git submodule update --init --recursive
# Fresh install: no 9.6 data to upgrade, but the upgrade image build requires this marker.
touch files/allow-postgres14-upgrade

if [ ! -f .env ]; then
  cp .env.template .env
fi
sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|; s|^SYSADMIN_EMAIL=.*|SYSADMIN_EMAIL=$EMAIL|; s|^SSL_TYPE=.*|SSL_TYPE=letsencrypt|" .env
chmod 600 .env
grep -E '^(DOMAIN|SYSADMIN_EMAIL|SSL_TYPE)=' .env

docker compose build
docker compose up -d
echo "Waiting for nginx to become healthy (Let's Encrypt can take a minute)..."
for _ in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q nginx)" 2>/dev/null)" = healthy ] && break
  sleep 5
done
docker compose ps
