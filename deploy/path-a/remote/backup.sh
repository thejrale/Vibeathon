#!/usr/bin/env bash
# Daily ODK Central DB backup. Installed to /usr/local/sbin/odk-backup by 50_backup_setup.sh.
set -euo pipefail
. /etc/odk-backup.conf   # BACKUP_TARGET (rclone remote:path, may be empty), KEEP_LOCAL_DAYS
DIR=/var/backups/odk
mkdir -p "$DIR" && chmod 700 "$DIR"
f="$DIR/odk-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker compose -f /opt/central/docker-compose.yml exec -T postgres14 pg_dump -U odk -Fc odk > "$f.partial"
mv "$f.partial" "$f"
echo "dump: $f ($(du -h "$f" | cut -f1))"
if [ -n "${BACKUP_TARGET:-}" ]; then
  rclone copy "$f" "$BACKUP_TARGET" --config /root/.config/rclone/rclone.conf
  echo "copied to $BACKUP_TARGET"
else
  echo "WARN BACKUP_TARGET empty: backup is only on this server"
fi
find "$DIR" -name 'odk-*.dump' -mtime +"${KEEP_LOCAL_DAYS:-7}" -delete
