#!/usr/bin/env bash
# Installs the backup script, rclone, and a daily cron at 02:30 server time.
set -euo pipefail
BACKUP_TARGET="${1:-}"
export DEBIAN_FRONTEND=noninteractive
command -v rclone >/dev/null || apt-get install -yq rclone
command -v cron >/dev/null || apt-get install -yq cron
systemctl enable --now cron
install -m 0700 /tmp/backup.sh /usr/local/sbin/odk-backup && rm -f /tmp/backup.sh
cat > /etc/odk-backup.conf <<CONF
BACKUP_TARGET="$BACKUP_TARGET"
KEEP_LOCAL_DAYS=7
CONF
chmod 600 /etc/odk-backup.conf
echo '30 2 * * * root /usr/local/sbin/odk-backup >> /var/log/odk-backup.log 2>&1' > /etc/cron.d/odk-backup
if [ -n "$BACKUP_TARGET" ] && [ ! -s /root/.config/rclone/rclone.conf ]; then
  echo "WARN configure the rclone remote first: sudo rclone config (remote used: ${BACKUP_TARGET%%:*})"
fi
/usr/local/sbin/odk-backup
