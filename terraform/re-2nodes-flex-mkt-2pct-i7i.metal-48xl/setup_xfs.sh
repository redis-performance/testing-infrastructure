#!/bin/bash -ex

# Tear down ext4 RAID created by prepare_flash.sh and rebuild with XFS + 256K chunks + 70% OP

apt-get install -y xfsprogs

# Dynamically find the 3.4T NVMe data drives (exclude the 2T boot disk)
DATA_DRIVES=($(lsblk -nd -o NAME,SIZE | awk '$2 == "3.4T" {print "/dev/"$1}' | sort))
NUM_DRIVES=${#DATA_DRIVES[@]}
echo "Found $NUM_DRIVES data drives: ${DATA_DRIVES[*]}"

if [ "$NUM_DRIVES" -ne 12 ]; then
    echo "ERROR: Expected 12 data drives, found $NUM_DRIVES"
    exit 1
fi

# Stop RS if running so nothing holds flash
systemctl stop rlec_supervisor 2>/dev/null || true
sleep 3

# Lazy unmount to avoid killing SSH
umount -l /var/opt/redislabs/flash || true
sleep 2

# Stop existing RAID
mdadm --stop /dev/md127 || true
sleep 2

for d in "${DATA_DRIVES[@]}"; do
    wipefs -af "$d" || true
    mdadm --zero-superblock "$d" || true
    blkdiscard -vf "$d" || true
done
sleep 10

mdadm --create /dev/md127 --level=0 --raid-devices=$NUM_DRIVES --chunk=256 "${DATA_DRIVES[@]}"

sed -i '/md127/d' /etc/mdadm/mdadm.conf
mdadm --detail --scan /dev/md127 >> /etc/mdadm/mdadm.conf

update-initramfs -u

# 80% usable (20% overprovisioning)
size=$(lsblk -nd -b -o SIZE /dev/md127 | awk '{printf "%.0fm\n", $1 * 0.8 / 1024 / 1024}')
mkfs.xfs -f -d su=256k,sw=12,size=${size} /dev/md127
xfs_info /dev/md127

mount -o noatime,allocsize=256k,largeio,swalloc,logbufs=8,logbsize=256k,noquota \
      /dev/md127 /var/opt/redislabs/flash

chmod 777 /var/opt/redislabs/flash
touch /var/opt/redislabs/flash/flash_ready

echo "XFS setup completed successfully (256K chunks, 20% OP)"
