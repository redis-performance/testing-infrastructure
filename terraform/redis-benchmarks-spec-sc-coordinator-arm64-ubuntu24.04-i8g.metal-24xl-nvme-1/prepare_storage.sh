#!/bin/bash
# Prepare the two storage conditions this runner exists to compare:
#
#   /mnt/nvme  physically-attached EC2 instance store (RAID0 if multiple disks)
#   /mnt/ebs   a dedicated EBS data volume, separate from the root volume
#
# Both are prepared unconditionally so the same host can serve either condition
# with nothing but a coordinator restart. Per testing-infrastructure#162 this
# script FAILS rather than silently falling back to the root disk: a run that
# quietly lands on "/" is worse than no run, because it looks like a valid
# datapoint for whichever condition was requested.

set -euo pipefail

NVME_DIR="/mnt/nvme"
EBS_DIR="/mnt/ebs"
EBS_DEVICE_HINT="${EBS_DEVICE_HINT:-/dev/sdf}"
METADATA="/etc/benchmark-storage.json"
LOG_FILE="/var/log/prepare_storage.log"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root"

log "preparing storage conditions (instance store + dedicated EBS)"

################################################################################
# Local NVMe (EC2 instance store)
#
# An NVMe device name proves nothing about physical locality -- EBS is also
# exposed as /dev/nvme*. The authoritative check is the by-id symlink, which
# carries "Amazon_EC2_NVMe_Instance_Storage" only for physically attached disks.
################################################################################
declare -a instance_store_disks=()
while IFS= read -r disk_name; do
    if ls -l /dev/disk/by-id/ 2>/dev/null | grep -qi "Instance_Storage.*${disk_name}$"; then
        instance_store_disks+=("/dev/${disk_name}")
    fi
done < <(lsblk -e7 -nd -o NAME)

[ "${#instance_store_disks[@]}" -gt 0 ] || \
    die "no EC2 instance-store disks found. This instance type has no physically attached NVMe, or the by-id symlinks are missing. Refusing to fall back to the root volume."

log "found ${#instance_store_disks[@]} instance-store disk(s): ${instance_store_disks[*]}"

if mountpoint -q "$NVME_DIR"; then
    log "$NVME_DIR already mounted, leaving as-is"
else
    mkdir -p "$NVME_DIR"
    if [ "${#instance_store_disks[@]}" -eq 1 ]; then
        nvme_drive="${instance_store_disks[0]}"
        log "single instance-store disk, no RAID"
    else
        if ! command -v mdadm >/dev/null 2>&1; then
            log "installing mdadm"
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mdadm --no-install-recommends
        fi
        log "creating RAID0 across ${#instance_store_disks[@]} disks"
        mdadm --create --verbose --chunk=256 /dev/md0 \
            --level=0 \
            --raid-devices="${#instance_store_disks[@]}" \
            "${instance_store_disks[@]}"
        nvme_drive="/dev/md0"
        mdadm --detail --scan > /etc/mdadm/mdadm.conf
        update-initramfs -u
    fi

    # -E nodiscard: skip the full-device TRIM, which takes minutes on multi-TB
    # instance store and buys nothing on a scratch benchmark filesystem.
    log "formatting $nvme_drive as ext4"
    mkfs.ext4 -F -m 0 -E nodiscard "$nvme_drive"
    nvme_uuid="$(blkid -s UUID -o value "$nvme_drive")"
    echo "UUID=$nvme_uuid $NVME_DIR ext4 defaults,noatime,nofail 0 0" >> /etc/fstab
    mount "$NVME_DIR"
    chmod 1777 "$NVME_DIR"
fi

mountpoint -q "$NVME_DIR" || die "$NVME_DIR did not mount"
log "$NVME_DIR ready"

################################################################################
# Dedicated EBS data volume
#
# Deliberately NOT the root volume. The root volume also carries the OS, docker
# images and build artifacts, so benchmark I/O there competes with unrelated
# traffic and its provisioned throughput is shared. A dedicated volume makes the
# EBS condition attributable to a volume whose type/IOPS/throughput we set and
# record explicitly.
################################################################################
ebs_device=""
for candidate in "$EBS_DEVICE_HINT" /dev/xvdf /dev/nvme1n1 /dev/nvme2n1; do
    [ -b "$candidate" ] || continue
    # Exclude the root disk and anything that is instance store.
    if lsblk -no MOUNTPOINT "$candidate" 2>/dev/null | grep -q '^/$'; then continue; fi
    dev_base="$(basename "$(readlink -f "$candidate")")"
    if ls -l /dev/disk/by-id/ 2>/dev/null | grep -qi "Instance_Storage.*${dev_base}$"; then continue; fi
    ebs_device="$(readlink -f "$candidate")"
    break
done

[ -n "$ebs_device" ] || \
    die "dedicated EBS data volume not found (looked for $EBS_DEVICE_HINT and NVMe aliases). Refusing to fall back to the root volume."

log "dedicated EBS data volume: $ebs_device"

if mountpoint -q "$EBS_DIR"; then
    log "$EBS_DIR already mounted, leaving as-is"
else
    mkdir -p "$EBS_DIR"
    if ! blkid "$ebs_device" >/dev/null 2>&1; then
        log "formatting $ebs_device as ext4"
        mkfs.ext4 -F -m 0 -E nodiscard "$ebs_device"
    fi
    ebs_uuid="$(blkid -s UUID -o value "$ebs_device")"
    echo "UUID=$ebs_uuid $EBS_DIR ext4 defaults,noatime,nofail 0 0" >> /etc/fstab
    mount "$EBS_DIR"
    chmod 1777 "$EBS_DIR"
fi

mountpoint -q "$EBS_DIR" || die "$EBS_DIR did not mount"
log "$EBS_DIR ready"

################################################################################
# Storage metadata
#
# testing-infrastructure#162 asks for device/mount identity, filesystem and
# options, EBS volume type and provisioned IOPS/throughput, and local device
# model to be recorded alongside results. Written here so it is captured at
# provisioning time; the runner copies it into each result set.
################################################################################
TOKEN="$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 300" 2>/dev/null || true)"
imds() {
    if [ -n "$TOKEN" ]; then
        curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null || true
    else
        curl -fsS "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null || true
    fi
}

nvme_source="$(findmnt -no SOURCE "$NVME_DIR")"
ebs_source="$(findmnt -no SOURCE "$EBS_DIR")"

python3 - "$NVME_DIR" "$EBS_DIR" "$nvme_source" "$ebs_source" "$METADATA" <<'PY'
import json, subprocess, sys, os

nvme_dir, ebs_dir, nvme_src, ebs_src, out_path = sys.argv[1:6]

def run(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        return ""

def mount_info(path):
    raw = run(f"findmnt -J -o TARGET,SOURCE,FSTYPE,OPTIONS {path}")
    try:
        return json.loads(raw)["filesystems"][0]
    except Exception:
        return {"target": path}

def members(src):
    """RAID0 members, so the recorded identity names the real disks not just md0."""
    if not src.startswith("/dev/md"):
        return []
    out = run(f"mdadm --detail {src}")
    return [t for t in out.split() if t.startswith("/dev/") and t != src]

def disk_identity(dev):
    base = os.path.basename(os.path.realpath(dev))
    return {
        "device": dev,
        "model": run(f"lsblk -ndo MODEL {dev}"),
        "serial": run(f"lsblk -ndo SERIAL {dev}"),
        "size": run(f"lsblk -ndo SIZE {dev}"),
        "rotational": run(f"cat /sys/block/{base}/queue/rotational"),
        "scheduler": run(f"cat /sys/block/{base}/queue/scheduler"),
        "by_id": run(f"ls -l /dev/disk/by-id/ | grep -i ' {base}$' | awk '{{print $9}}'"),
    }

nvme_devices = members(nvme_src) or [nvme_src]
ebs_devices = members(ebs_src) or [ebs_src]

doc = {
    "schema": "benchmark-storage/1",
    "generated_at": run("date -u +%Y-%m-%dT%H:%M:%SZ"),
    "instance_id": run("cat /var/lib/cloud/data/instance-id"),
    "conditions": {
        "nvme": {
            "backend": "ec2-instance-store",
            "physically_attached": True,
            "mount": mount_info(nvme_dir),
            "raid": {"level": "raid0", "members": nvme_devices} if nvme_src.startswith("/dev/md") else None,
            "disks": [disk_identity(d) for d in nvme_devices],
        },
        "ebs": {
            "backend": "ebs",
            "physically_attached": False,
            "mount": mount_info(ebs_dir),
            "raid": None,
            "disks": [disk_identity(d) for d in ebs_devices],
            "note": "volume type / provisioned IOPS / throughput are set in terraform and must be read back with ec2 describe-volumes; recorded here as the device view only.",
        },
    },
    "root_volume_note": "benchmark data must never live on '/'. prepare_storage.sh fails rather than falling back.",
}

with open(out_path, "w") as fh:
    json.dump(doc, fh, indent=2)
print(json.dumps(doc, indent=2))
PY

chmod 0644 "$METADATA"
log "wrote storage metadata to $METADATA"

log "storage preparation complete"
df -h "$NVME_DIR" "$EBS_DIR" | tee -a "$LOG_FILE"
