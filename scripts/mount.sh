#!/usr/bin/env bash
set -e

DEVICE="/dev/sda1"
MOUNT_POINT="/srv"
DOCKER_UID=0
DOCKER_GID=0

if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root (sudo)"
  exit 1
fi

if [ ! -b "$DEVICE" ]; then
  echo "❌ Device $DEVICE not found"
  exit 1
fi

mkdir -p "$MOUNT_POINT"

UUID=$(blkid -s UUID -o value "$DEVICE")
FSTYPE=$(blkid -s TYPE -o value "$DEVICE")

if [ -z "$UUID" ] || [ -z "$FSTYPE" ]; then
  echo "❌ Unable to detect filesystem"
  exit 1
fi

echo "✔ UUID: $UUID"
echo "✔ Filesystem: $FSTYPE"

# Backup fstab
cp -n /etc/fstab /etc/fstab.backup

# Docker-friendly mount options
OPTS="defaults,noatime,nofail"

# Add fstab entry if missing
if ! grep -q "$UUID" /etc/fstab; then
  echo "UUID=$UUID  $MOUNT_POINT  $FSTYPE  $OPTS  0  2" >> /etc/fstab
  echo "✔ fstab entry added"
else
  echo "ℹ fstab entry already exists"
fi

# Mount
mount "$MOUNT_POINT"

# Docker likes predictable perms
chown -R "$DOCKER_UID:$DOCKER_GID" "$MOUNT_POINT"
chmod 755 "$MOUNT_POINT"

echo "🎉 Docker volume mounted at $MOUNT_POINT"
df -h | grep "$MOUNT_POINT"

