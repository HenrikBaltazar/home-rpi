#!/usr/bin/env bash
# prepare_disk.sh
# Safely wipe a disk, create a single partition, and format it.

set -euo pipefail

error() { echo "ERROR: $*" >&2; exit 1; }
info()  { echo "[INFO] $*"; }
warn()  { echo "[WARNING] $*"; }

usage() {
cat <<EOF
Usage: sudo $0 /dev/sdX [fs_type] [label_type]

  /dev/sdX        -> target device (e.g. /dev/sdb, /dev/nvme0n1)
  fs_type         -> ext4 (default), xfs, vfat, exfat, ntfs
  label_type      -> gpt (default) or msdos

Example:
  sudo $0 /dev/sdc ext4 gpt

WARNING: This script ERASES ALL DATA on the specified device.
EOF
}

# ------------------------
# Parameter parsing
# ------------------------
DEVICE=${1:-""}
FS=${2:-ext4}
LABEL_TYPE=${3:-gpt}

[[ -z "$DEVICE" ]] && usage && exit 1

if [[ ! -b "$DEVICE" ]]; then
    error "Device does not exist: $DEVICE"
fi

# Prevent passing a partition by mistake
if [[ "$DEVICE" =~ [0-9]$ ]]; then
    warn "It looks like you passed a partition instead of a full disk."
    read -rp "Continue anyway? (yes/no): " yn
    [[ "$yn" == "yes" ]] || error "Aborted."
fi

# Prevent formatting the root filesystem
ROOT_DEV=$(findmnt -n -o SOURCE / || true)
if [[ "$ROOT_DEV" == "$DEVICE" || "$ROOT_DEV" == ${DEVICE}* ]]; then
    error "The selected device appears to contain the root filesystem."
fi

echo ""
info "Target device: $DEVICE"
info "Filesystem type: $FS"
info "Partition table: $LABEL_TYPE"
echo ""

lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo ""

# ------------------------
# Confirmation
# ------------------------
read -rp "Type EXACTLY 'YES' to erase all data on $DEVICE: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || error "User did not confirm. Aborting."

# ------------------------
# Unmount all partitions properly (handles spaces)
# ------------------------
info "Unmounting any mounted partitions on $DEVICE..."

while IFS= read -r raw_mnt; do
    [[ -z "$raw_mnt" ]] && continue

    # Decode \x20 etc. into literal characters
    mnt=$(printf "%b" "$raw_mnt")

    info "Unmounting: $mnt"
    umount -l "$mnt" || warn "Could not unmount $mnt"
done < <(lsblk -nrpo MOUNTPOINT "$DEVICE" | grep -v '^$' || true)

sleep 1

# ------------------------
# Optional wipefs
# ------------------------
read -rp "Do you want to run wipefs -a on the device? (yes/no): " DO_WIPE
if [[ "$DO_WIPE" == "yes" ]]; then
    info "Running wipefs -a on $DEVICE..."
    wipefs -a "$DEVICE" || error "wipefs failed. Device still busy?"
fi

# ------------------------
# Create new partition table
# ------------------------
info "Creating new partition table: $LABEL_TYPE..."
parted --script "$DEVICE" mklabel "$LABEL_TYPE"

info "Creating single full-size partition..."
parted --script "$DEVICE" mkpart primary 1MiB 100%

partprobe "$DEVICE" || true
sleep 1

# ------------------------
# Determine partition name
# ------------------------
if [[ "$(basename "$DEVICE")" =~ ^(nvme|mmcblk) ]]; then
    PART="${DEVICE}p1"
else
    PART="${DEVICE}1"
fi

for i in {1..10}; do
    [[ -b "$PART" ]] && break
    sleep 0.5
done

[[ -b "$PART" ]] || error "Partition $PART did not appear. Check manually."

info "Partition created: $PART"

# ------------------------
# Format the partition
# ------------------------
info "Formatting $PART as $FS..."

case "$FS" in
    ext4) mkfs.ext4 -F "$PART" ;;
    xfs)  mkfs.xfs -f "$PART" ;;
    vfat|fat32) mkfs.vfat -F32 "$PART" ;;
    exfat)
        command -v mkfs.exfat >/dev/null \
            || error "mkfs.exfat not found. Install exfatprogs."
        mkfs.exfat "$PART"
        ;;
    ntfs)
        command -v mkfs.ntfs >/dev/null \
            || error "mkfs.ntfs not found. Install ntfs-3g."
        mkfs.ntfs -f "$PART"
        ;;
    *)
        error "Unknown filesystem: $FS"
        ;;
esac

sync
partprobe "$DEVICE" || true

echo ""
info "Disk prepared successfully!"
echo ""

lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DEVICE"
echo ""

info "To mount the disk manually:"
echo "  sudo mount $PART /mnt"
echo ""

exit 0

