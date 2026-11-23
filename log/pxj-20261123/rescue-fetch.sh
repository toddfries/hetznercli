#!/bin/sh
# Download the Proxmox ISO on the rescue host and check its sha256.
# xorriso is installed here because the rescue image does not ship it.
set -eu
LOG=/root/pxj-setup.log
exec >>"$LOG" 2>&1
echo "=== fetch $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
df -h /root
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xorriso
cd /root
URL=https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso
wget -O proxmox-ve_9.2-1.iso "$URL"
echo '4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c  proxmox-ve_9.2-1.iso' | sha256sum -c
echo "=== fetch ok $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
