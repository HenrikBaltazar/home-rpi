#!/usr/bin/env bash

set -euo pipefail

SOURCE_MNT="/srv/media"
TEMP_MNT="/mnt/newdisk"

info()  { echo -e "\e[32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; exit 1; }

[[ $# -ne 1 ]] && error "Usage: sudo ./migrate.sh /dev/sdX"

NEW_DEVICE="$1"

[[ $EUID -ne 0 ]] && error "Run as root."

# Check source mount exists
[[ ! -d "$SOURCE_MNT" ]] && error "$SOURCE_MNT does not exist."

info "Checking current source mount: $SOURCE_MNT"
CURRENT_DEVICE=$(lsblk -nrpo NAME,MOUNTPOINT | grep " $SOURCE_MNT" | awk '{print $1}')

[[ -z "$CURRENT_DEVICE" ]] && error "$SOURCE_MNT is not currently mounted."

info "Current device mounted on $SOURCE_MNT: $CURRENT_DEVICE"

# Prevent using same disk
[[ "$CURRENT_DEVICE" =~ ${NEW_DEVICE}.* ]] && error "New device cannot be the same disk currently in use!"

# Detect partitions on new device
info "Detecting partitions on $NEW_DEVICE..."
PARTS=$(lsblk -nrpo NAME,TYPE "$NEW_DEVICE" | awk '$2=="part"{print $1}')

if [[ -z "$PARTS" ]]; then
    warn "No partitions found on $NEW_DEVICE."
    echo "Create 1 new full-disk partition? (yes/no): "
    read -r ans
    [[ "$ans" != "yes" ]] && error "Aborted."

    parted "$NEW_DEVICE" --script mklabel gpt
    parted "$NEW_DEVICE" --script mkpart primary ext4 0% 100%

    sleep 2

    PARTS=$(lsblk -nrpo NAME,TYPE "$NEW_DEVICE" | awk '$2=="part"{print $1}')
fi

NEW_PART=$(echo "$PARTS" | head -n1)
info "Using partition: $NEW_PART"

# Check if formatted
FSTYPE=$(lsblk -nrpo FSTYPE "$NEW_PART")

if [[ -z "$FSTYPE" ]]; then
    warn "Partition $NEW_PART has NO filesystem."
    echo "Format as ext4? (yes/no): "
    read -r ans
    [[ "$ans" != "yes" ]] && error "Aborted."

    mkfs.ext4 -F "$NEW_PART"
else
    info "Partition already formatted as $FSTYPE"
fi

# Prepare temp mount
mkdir -p "$TEMP_MNT"

info "Mounting $NEW_PART to $TEMP_MNT..."
mount "$NEW_PART" "$TEMP_MNT"

# Confirm migration
echo "Data will be copied FROM $SOURCE_MNT TO $TEMP_MNT"
echo "CONFIRM migration? Type YES to continue:"
read -r confirm

[[ "$confirm" != "YES" ]] && error "Aborted."

info "Starting data migration..."
rsync -aHAX --info=progress2 "$SOURCE_MNT"/ "$TEMP_MNT"/

info "Sync complete. Unmounting new partition..."
umount "$TEMP_MNT"

info "Unmounting current source partition..."
umount "$SOURCE_MNT"

info "Mounting new storage on $SOURCE_MNT..."
mount "$NEW_PART" "$SOURCE_MNT"

info "Migration complete!"
info "New storage is now active at $SOURCE_MNT"

