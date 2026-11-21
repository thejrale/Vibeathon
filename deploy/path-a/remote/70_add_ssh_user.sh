#!/usr/bin/env bash
# Usage: 70_add_ssh_user.sh <username> "<ssh public key line>" yes|no(sudo)
set -euo pipefail
user="$1"; pubkey="$2"; want_sudo="${3:-no}"
[[ "$user" =~ ^[a-z_][a-z0-9_.-]{0,31}$ ]] || { echo "FAIL invalid username: $user"; exit 1; }
[[ "$pubkey" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[a-z0-9-]+|sk-[a-z0-9@.-]+)\ [A-Za-z0-9+/=]+ ]] || { echo "FAIL not an SSH public key"; exit 1; }

id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
home="$(getent passwd "$user" | cut -d: -f6)"
install -d -m 700 -o "$user" -g "$user" "$home/.ssh"
touch "$home/.ssh/authorized_keys"
grep -qxF "$pubkey" "$home/.ssh/authorized_keys" || echo "$pubkey" >> "$home/.ssh/authorized_keys"
chown "$user:$user" "$home/.ssh/authorized_keys"; chmod 600 "$home/.ssh/authorized_keys"
echo "OK $user can log in with the key"

if [ "$want_sudo" = yes ]; then
  usermod -aG sudo "$user"
  if [ "$(passwd -S "$user" | awk '{print $2}')" != P ]; then
    pw="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"; pw="${pw:0:16}"
    echo "$user:$pw" | chpasswd
    chage -d 0 "$user"   # must choose a new one at first login
    echo "OK $user has sudo. Temporary sudo password (shown once, share privately): $pw"
  else
    echo "OK $user has sudo with their existing password"
  fi
fi
