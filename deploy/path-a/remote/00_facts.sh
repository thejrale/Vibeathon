#!/usr/bin/env bash
# Read-only checks against the Path A minimums.
set -uo pipefail
fail=0
. /etc/os-release
echo "OS: $PRETTY_NAME ($(uname -m))"
case "$VERSION_ID" in 22.04|24.04) echo "OK Ubuntu LTS";; *) echo "WARN expected Ubuntu 22.04/24.04";; esac
[ "$(uname -m)" = x86_64 ] || { echo "FAIL needs x86_64"; fail=1; }
mem_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
swap_mb=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo)
disk_gb=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
echo "CPU: $(nproc)  RAM: ${mem_mb}MB  Swap: ${swap_mb}MB  Free disk: ${disk_gb}GB"
[ "$mem_mb" -ge 1800 ] || echo "WARN under 2 GB RAM (swap will be added)"
[ "$disk_gb" -ge 20 ] || { echo "FAIL under 20 GB free disk"; fail=1; }
for p in 80 443; do
  if ss -tlnH "sport = :$p" | grep -q .; then echo "WARN port $p already in use: $(ss -tlnpH "sport = :$p")"; fi
done
command -v docker >/dev/null && echo "Docker present: $(docker --version)" || echo "Docker not installed yet"
exit $fail
