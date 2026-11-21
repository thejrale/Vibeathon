#!/usr/bin/env bash
# Path B (DigitalOcean): create the droplet + cloud firewall, then hand over to Path A.
# Usage: DIGITALOCEAN_TOKEN=... ./digitalocean.sh up|status|down
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${DIGITALOCEAN_TOKEN:?set DIGITALOCEAN_TOKEN}"
export DIGITALOCEAN_ACCESS_TOKEN="$DIGITALOCEAN_TOKEN"

NAME="${DROPLET_NAME:-eira-central}"
REGION="${REGION:-sfo3}"
SIZE="${SIZE:-s-2vcpu-2gb}"
IMAGE="${IMAGE:-ubuntu-24-04-x64}"
TAG="${TAG:-eira-central}"
OPERATOR_USER="${OPERATOR_USER:-eira-admin}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/eira_central}"
ENV_OUT="${ENV_OUT:-$HERE/../.env}"
ADMIN_EMAIL="${ADMIN_EMAIL:?set ADMIN_EMAIL}"

droplet_id() {
  local out ids
  out="$(doctl compute droplet list --tag-name "$TAG" --format ID,Name --no-header)" || { echo "FAIL could not list droplets" >&2; return 1; }
  ids="$(awk -v n="$NAME" '$2==n{print $1}' <<<"$out")"
  [ "$(grep -c . <<<"$ids")" -le 1 ] || { echo "FAIL several droplets named $NAME: $ids" >&2; return 1; }
  echo "$ids"
}

# Keeps other keys (CENTRAL_VERSION, BACKUP_TARGET, a custom domain) on re-runs.
set_env() { grep -v "^$1=" "$ENV_OUT" > "$ENV_OUT.tmp" || true; echo "$1=$2" >> "$ENV_OUT.tmp"; mv "$ENV_OUT.tmp" "$ENV_OUT"; chmod 600 "$ENV_OUT"; }
set_env_if_missing() { grep -q "^$1=." "$ENV_OUT" || set_env "$1" "$2"; }

up() {
  [ -f "$SSH_KEY_PATH" ] || ssh-keygen -q -t ed25519 -N "" -C "$NAME-operator" -f "$SSH_KEY_PATH"
  pub="$(cat "$SSH_KEY_PATH.pub")"
  fp="$(ssh-keygen -E md5 -lf "$SSH_KEY_PATH.pub" | awk '{print $2}' | sed 's/^MD5://')"
  doctl compute ssh-key get "$fp" >/dev/null 2>&1 || doctl compute ssh-key import "$NAME-operator" --public-key-file "$SSH_KEY_PATH.pub" >/dev/null
  doctl compute tag create "$TAG" >/dev/null 2>&1 || true

  id="$(droplet_id)"
  if [ -z "$id" ]; then
    userdata="$(mktemp)"
    cat > "$userdata" <<CLOUD
#cloud-config
users:
  - name: $OPERATOR_USER
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys: ["$pub"]
CLOUD
    doctl compute droplet create "$NAME" --region "$REGION" --size "$SIZE" --image "$IMAGE" \
      --ssh-keys "$fp" --tag-names "$TAG" --enable-monitoring --user-data-file "$userdata" --wait >/dev/null
    rm -f "$userdata"
  fi

  if ! doctl compute firewall list --format Name --no-header | grep -qx "$NAME-fw"; then
    doctl compute firewall create --name "$NAME-fw" --tag-names "$TAG" \
      --inbound-rules "protocol:tcp,ports:22,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:80,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:443,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
      --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" >/dev/null
  fi

  id="$(droplet_id)"
  ip="$(doctl compute droplet get "$id" --format PublicIPv4 --no-header)"
  echo "Waiting for SSH as $OPERATOR_USER@$ip ..."
  ready=0
  for _ in $(seq 1 60); do
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$OPERATOR_USER@$ip" 'cloud-init status --wait >/dev/null; sudo -n true' 2>/dev/null; then ready=1; break; fi
    sleep 5
  done
  [ "$ready" = 1 ] || { echo "FAIL no SSH + sudo as $OPERATOR_USER@$ip after 5 minutes"; exit 1; }

  touch "$ENV_OUT" && chmod 600 "$ENV_OUT"
  set_env SERVER_IP "$ip"
  set_env SSH_USER "$OPERATOR_USER"
  set_env SSH_KEY_PATH "$SSH_KEY_PATH"
  set_env_if_missing CENTRAL_DOMAIN "${ip//./-}.sslip.io"
  set_env_if_missing ADMIN_EMAIL "$ADMIN_EMAIL"
  echo "Droplet ready: $ip  (domain $(grep '^CENTRAL_DOMAIN=' "$ENV_OUT" | cut -d= -f2-))"
  echo "Next: ../path-a/run.sh all"
}

status() {
  doctl compute droplet list --tag-name "$TAG" --format ID,Name,PublicIPv4,Region,SizeSlug,Status
  doctl compute firewall list --format ID,Name,Status
}

down() {
  read -r -p "Delete droplet '$NAME' and firewall '$NAME-fw'? All Central data on it is lost. Type the droplet name: " ans
  [ "$ans" = "$NAME" ] || { echo "aborted"; exit 1; }
  id="$(droplet_id)"
  if [ -n "$id" ]; then doctl compute droplet delete "$id" --force; fi
  fw="$(doctl compute firewall list --format ID,Name --no-header | awk -v n="$NAME-fw" '$2==n{print $1}')"; [ -n "$fw" ] && doctl compute firewall delete "$fw" --force
  echo "deleted"
}

case "${1:-}" in up) up ;; status) status ;; down) down ;; *) echo "usage: $0 up|status|down"; exit 2 ;; esac
