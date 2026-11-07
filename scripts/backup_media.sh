#!/usr/bin/env bash

set -euo pipefail

info()  { echo -e "\e[32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; exit 1; }

[[ $# -ne 1 ]] && error "Usage: sudo ./backup_media.sh /dev/sdX"

DEVICE="$1"
TARGET_DIR="/mnt/backupdisk"
SOURCE_DIR="/srv/media"

[[ $EUID -ne 0 ]] && error "Run this script as root."

[[ ! -b "$DEVICE" ]] && error "Device $DEVICE does not exist."

# Detect partition (only first one)
PART=$(lsblk -nrpo NAME,TYPE "$DEVICE" | awk '$2=="part"{print $1}' | head -n1)

if [[ -z "$PART" ]]; then
    error "No partitions found in $DEVICE. Format the disk before using this script."
fi

info "Using target partition: $PART"

# Create mountpoint if missing
mkdir -p "$TARGET_DIR"

# Unmount if is already mounted
if mount | grep -q "$TARGET_DIR"; then
    info "Unmounting previous device at $TARGET_DIR..."
    umount -l "$TARGET_DIR"
fi

# Mount target
info "Mounting $PART to $TARGET_DIR..."
mount "$PART" "$TARGET_DIR"

# Show free space
FREE=$(df --output=avail -k "$TARGET_DIR" | tail -n1)
FREE_H=$(df -h "$TARGET_DIR" | awk 'NR==2{print $4}')

# Size of source
SOURCE_SIZE=$(du -sk "$SOURCE_DIR" | awk '{print $1}')
SOURCE_H=$(du -sh "$SOURCE_DIR" | awk '{print $1}')

echo
info "Source size: $SOURCE_H"
info "Free space on target: $FREE_H"
echo

# Check space
if (( FREE < SOURCE_SIZE )); then
    umount "$TARGET_DIR"
    error "ERROR: Not enough free space on the destination disk!"
fi

echo "This will BACK UP data FROM:"
echo "  $SOURCE_DIR"
echo "TO:"
echo "  $TARGET_DIR"
echo
echo "Type YES to begin:"
read -r confirm

[[ "$confirm" != "YES" ]] && error "Backup aborted."

info "Starting backup..."
echo

rsync -avh --progress --delete "$SOURCE_DIR"/ "$TARGET_DIR"/

echo
info "Backup completed successfully!"

# Suggest safe unmount
info "You can unmount using: sudo umount $TARGET_DIR"

