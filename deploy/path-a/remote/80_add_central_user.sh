#!/usr/bin/env bash
# Usage: 80_add_central_user.sh <email> admin|user
set -euo pipefail
email="$1"; role="${2:-user}"
[[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || { echo "FAIL invalid email: $email"; exit 1; }
cd /opt/central
pw="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"; pw="${pw:0:16}"
printf '%s\n' "$pw" | docker compose exec -T service odk-cmd --email "$email" user-create >/dev/null \
  || { echo "FAIL could not create $email (already exists?)"; exit 1; }
[ "$role" = admin ] && docker compose exec -T service odk-cmd --email "$email" user-promote >/dev/null
echo "OK Central web user $email ($role)"
echo "Temporary password (shown once, share privately; change it in Central under the user menu → Edit profile): $pw"
