#!/usr/bin/env bash
# Path A runner: deploys ODK Central to an existing server over SSH.
# Usage: ./run.sh preflight|harden|docker|central|verify|backup-setup|restore-test|all
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ENV_FILE:-$HERE/../.env}"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && set -a && . "$ENV_FILE" && set +a

: "${SERVER_IP:?set SERVER_IP}" "${SSH_USER:?set SSH_USER}" "${SSH_KEY_PATH:?set SSH_KEY_PATH}"
: "${CENTRAL_DOMAIN:?set CENTRAL_DOMAIN}" "${ADMIN_EMAIL:?set ADMIN_EMAIL}"
CENTRAL_VERSION="${CENTRAL_VERSION:-v2026.3.2}"
BACKUP_TARGET="${BACKUP_TARGET:-}"

SSH_OPTS=(-i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
TARGET="$SSH_USER@$SERVER_IP"

remote_sudo() { # remote_sudo <script> [args...]
  local script="$1"; shift
  scp -q "${SSH_OPTS[@]}" "$HERE/remote/$script" "$TARGET:/tmp/$script"
  if [ -n "${SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$SUDO_PASSWORD" | ssh "${SSH_OPTS[@]}" "$TARGET" "sudo -S -p '' bash /tmp/$script $(printf '%q ' "$@"); rc=\$?; rm -f /tmp/$script; exit \$rc"
  else
    ssh "${SSH_OPTS[@]}" "$TARGET" "sudo -n bash /tmp/$script $(printf '%q ' "$@"); rc=\$?; rm -f /tmp/$script; exit \$rc"
  fi
}

preflight() {
  echo "== SSH + sudo"
  ssh "${SSH_OPTS[@]}" "$TARGET" true
  remote_sudo 00_facts.sh
  echo "== DNS: $CENTRAL_DOMAIN"
  resolved="$(getent ahostsv4 "$CENTRAL_DOMAIN" | awk 'NR==1{print $1}')"
  if [ "$resolved" = "$SERVER_IP" ]; then echo "OK resolves to $SERVER_IP"; else echo "FAIL resolves to '${resolved:-nothing}', expected $SERVER_IP"; exit 1; fi
}

external_checks() {
  echo "== External: 5432 must be closed"
  if timeout 5 bash -c "</dev/tcp/$SERVER_IP/5432" 2>/dev/null; then echo "FAIL 5432 reachable"; exit 1; else echo "OK 5432 closed"; fi
  echo "== External: HTTPS"
  if code=$(curl -fsS -o /dev/null -w "%{http_code}" "https://$CENTRAL_DOMAIN/"); then
    echo "OK HTTP $code with a valid certificate"
  else
    echo "FAIL HTTPS not working (certificate or port 443)"; exit 1
  fi
}

case "${1:-}" in
  preflight)    preflight ;;
  harden)       remote_sudo 10_harden.sh "$SSH_USER" ;;
  docker)       remote_sudo 20_docker.sh "$SSH_USER" ;;
  central)      remote_sudo 30_central.sh "$CENTRAL_DOMAIN" "$ADMIN_EMAIL" "$CENTRAL_VERSION" ;;
  verify)       remote_sudo 40_verify.sh; external_checks ;;
  backup-setup) scp -q "${SSH_OPTS[@]}" "$HERE/remote/backup.sh" "$TARGET:/tmp/backup.sh"
                remote_sudo 50_backup_setup.sh "$BACKUP_TARGET" ;;
  restore-test) remote_sudo 60_restore_test.sh ;;
  all)          preflight; "$0" harden; "$0" docker; "$0" central; "$0" verify ;;
  *) echo "usage: $0 preflight|harden|docker|central|verify|backup-setup|restore-test|all"; exit 2 ;;
esac
