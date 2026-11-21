#!/usr/bin/env bash
# Baseline hardening: updates, firewall, key-only SSH, swap.
set -euo pipefail
SSH_USER="$1"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq
apt-get install -yq ufw unattended-upgrades curl git ca-certificates
dpkg-reconfigure -f noninteractive unattended-upgrades

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

if [ -n "$(cat /home/"$SSH_USER"/.ssh/authorized_keys 2>/dev/null; [ "$SSH_USER" = root ] && cat /root/.ssh/authorized_keys)" ]; then
  cat > /etc/ssh/sshd_config.d/90-odk-hardening.conf <<CONF
PasswordAuthentication no
KbdInteractiveAuthentication no
$( [ "$SSH_USER" = root ] || echo "PermitRootLogin no" )
CONF
  sshd -t
  systemctl reload ssh 2>/dev/null || systemctl reload sshd
else
  echo "WARN no authorized_keys for $SSH_USER; leaving SSH auth settings unchanged"
fi

if [ "$(awk '/SwapTotal/{print $2}' /proc/meminfo)" -eq 0 ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
ufw status verbose
echo "Harden done."
