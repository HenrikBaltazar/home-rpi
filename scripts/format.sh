#!/usr/bin/env bash

set -euo pipefail

info()  { echo -e "\e[32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; exit 1; }

[[ $# -ne 1 ]] && error "Usage: sudo ./format.sh /dev/sdX"

DEVICE="$1"

[[ $EUID -ne 0 ]] && error "Run as root."

# Validate device exists
[[ ! -b "$DEVICE" ]] && error "Device $DEVICE does not exist."

# Prevent formatting partitions
if [[ "$DEVICE" =~ [0-9]$ ]]; then
    error "You must pass the disk (e.g., /dev/sda), NOT a partition (e.g., /dev/sda1)."
fi

echo "This will ERASE ALL DATA on: $DEVICE"
echo "Type YES to continue:"
read -r confirm
[[ "$confirm" != "YES" ]] && error "Aborted."

# Unmount any mounted partitions
info "Unmounting all partitions on $DEVICE..."
for p in $(lsblk -nrpo NAME,TYPE "$DEVICE" | awk '$2=="part"{print $1}'); do
    mnt=$(lsblk -nrpo MOUNTPOINT "$p")
    if [[ -n "$mnt" ]]; then
        info "Unmounting $mnt"
        umount -l "$mnt" || warn "Could not unmount $mnt"
    fi
done

sleep 1

# Clean signatures
info "Running wipefs -a on $DEVICE..."
wipefs -a "$DEVICE" || {
    warn "wipefs failed, attempting force wipe..."
    wipefs -a -f "$DEVICE" || error "wipefs failed even in force mode"
}

sleep 1

# Create GPT
info "Creating new GPT partition table..."
parted "$DEVICE" --script mklabel gpt

sleep 1

# Create one full-size partition
info "Creating full-disk partition..."
parted "$DEVICE" --script mkpart primary ext4 0% 100%

sleep 1

# Get new partition name
NEW_PART=$(lsblk -nrpo NAME,TYPE "$DEVICE" | awk '$2=="part"{print $1}' | head -n1)

[[ -z "$NEW_PART" ]] && error "Partition creation failed!"

# Format partition as ext4
info "Formatting $NEW_PART as ext4..."
mkfs.ext4 -F "$NEW_PART"

info "Finished!"
info "Disk $DEVICE has been completely reset and formatted as ext4."
info "New partition: $NEW_PART"

