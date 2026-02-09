#!/bin/bash
# Simple RAID0 setup for Ubuntu 24.04 - local NVMe disks

set -e

FLASH_DIR="/mnt/flash"
LOG_FILE="/var/log/prepare_flash.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Please run as root."
    exit 1
fi

log "Starting flash preparation for Ubuntu 24.04"

# Check if already mounted
if mountpoint -q "$FLASH_DIR" 2>/dev/null; then
    log "Already mounted at $FLASH_DIR"
    exit 0
fi

# Find NVMe instance store disks (non-rotational, no filesystem, no partitions)
declare -a disks_to_use
log "Scanning for available NVMe disks..."

while IFS= read -r line; do
    disk_name=$(echo "$line" | awk '{print $1}')
    rota=$(echo "$line" | awk '{print $2}')
    fstype=$(echo "$line" | awk '{print $3}')

    # Check if it's an SSD (rota=0), has no filesystem, and no partitions
    if [ "$rota" = "0" ] && [ -z "$fstype" ]; then
        partition_count=$(lsblk -n "/dev/$disk_name" 2>/dev/null | wc -l)
        if [ "$partition_count" -eq 1 ]; then
            # Verify it's instance storage (not EBS)
            if ls -l /dev/disk/by-id/ 2>/dev/null | grep -q "Instance_Storage.*$disk_name"; then
                disks_to_use+=("/dev/$disk_name")
                log "Found disk: /dev/$disk_name"
            fi
        fi
    fi
done < <(lsblk -e7 -nd -o NAME,ROTA,FSTYPE)

# Check if we found any disks
if [ ${#disks_to_use[@]} -eq 0 ]; then
    log "ERROR: No suitable disks found"
    exit 1
fi

log "Found ${#disks_to_use[@]} disk(s): ${disks_to_use[*]}"

# Create mount point
mkdir -p "$FLASH_DIR"

# Single disk or RAID0?
if [ ${#disks_to_use[@]} -eq 1 ]; then
    log "Single disk setup"
    drive_to_use="${disks_to_use[0]}"
else
    log "Creating RAID0 array with ${#disks_to_use[@]} disks"

    # Install mdadm if needed
    if ! command -v mdadm >/dev/null 2>&1; then
        log "Installing mdadm..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq mdadm --no-install-recommends
    fi

    # Create RAID0
    log "Creating RAID0 array..."
    mdadm --create --verbose --chunk=256 /dev/md0 \
        --level=0 \
        --raid-devices=${#disks_to_use[@]} \
        "${disks_to_use[@]}"

    drive_to_use="/dev/md0"

    # Save mdadm config
    log "Saving mdadm configuration..."
    mdadm --detail --scan > /etc/mdadm/mdadm.conf
    update-initramfs -u
fi

# Format with ext4
log "Formatting $drive_to_use with ext4..."
mkfs.ext4 -F -m 0 -E nodiscard "$drive_to_use"

# Get UUID
drive_uuid=$(blkid -s UUID -o value "$drive_to_use")
log "Drive UUID: $drive_uuid"

# Add to fstab for persistence
log "Adding to /etc/fstab..."
echo "UUID=$drive_uuid $FLASH_DIR ext4 noatime,rw,relatime,user_xattr,barrier=0,journal_async_commit,data=writeback 0 0" >> /etc/fstab

# Mount
log "Mounting $FLASH_DIR..."
mount "$FLASH_DIR"

# Set permissions
chmod 755 "$FLASH_DIR"

log "Flash setup complete. Mounted at $FLASH_DIR"
df -h "$FLASH_DIR"

exit 0