#!/usr/bin/env bash
set -euo pipefail

NVME_DEV="/dev/nvme0n1"
MOUNT_POINT="/mnt/nvme_pgdata"
PG_VERSION="18"


echo "=== 0. Pregame ==="
# Permanently disable all sleep/suspend states (prevents EIC7700X kernel hangs)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# Update packages and ensure the P550 hardware fan controller + core storage tools are installed
sudo apt update && sudo apt upgrade -y
sudo apt install -y fancontrol-config-p550-premier \
  mdadm lvm2 xfsprogs smartmontools nvme-cli \
  linux-tools-common linux-tools-generic sysstat iotop htop jq curl git build-essential
# Boot strictly to headless console
sudo systemctl set-default multi-user.target

# Purge Snap packages and the snapd daemon
sudo snap remove --purge firefox snap-store bare core22 gtk-common-themes gnome-42-2204 2>/dev/null || true
sudo systemctl stop snapd.socket snapd.service
sudo apt purge -y snapd ubuntu-desktop* gnome-shell* gdm3 xwayland \
apport whoopsie unattended-upgrades packagekit modemmanager

# Clean up orphaned GUI libraries
sudo apt autoremove -y --purge
sudo apt clean

cat << 'EOF' | sudo tee /etc/sysctl.d/90-brackerbox-broker.conf
# Allow non-root perf sampling of P550 L1/PL2/CCACHE hardware counters
kernel.perf_event_paranoid = -1
kernel.kptr_restrict = 0

# Broker memory & dirty page writeback tuning
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15

# Disable NMI watchdog interrupts to reduce CPU jitter
kernel.nmi_watchdog = 0
EOF

sudo sysctl --system


echo "=== 1. Installing NVMe & Filesystem Utilities ==="
sudo apt-get update
sudo apt-get install -y nvme-cli xfsprogs curl ca-certificates gnupg lsb-release

echo "=== 2. Checking WD_BLACK SN850X LBA Sector Format ==="
sudo nvme id-ns -H "$NVME_DEV" | grep "LBA Format"

# Find the LBA format index for 4096-byte sectors (lbads:12 -> 2^12 = 4096)
LBA_4K_INDEX=$(sudo nvme id-ns "$NVME_DEV" | awk '/lbads:12/ {print $2}' | tr -d ':' | head -n1)

if [ -n "$LBA_4K_INDEX" ]; then
    echo "Formatting $NVME_DEV to native 4K sectors (LBA index $LBA_4K_INDEX)..."
    sudo nvme format "$NVME_DEV" -l "$LBA_4K_INDEX" --force
    sudo partprobe "$NVME_DEV" || true
    sleep 2
else
    echo "4K LBA index not auto-detected; keeping current sector format."
fi

echo "=== 3. Partitioning & Formatting XFS (4K-Aligned) ==="
sudo parted -s "$NVME_DEV" mklabel gpt
sudo parted -s -a optimal "$NVME_DEV" mkpart primary xfs 1MiB 100%
sleep 2

PART_DEV="${NVME_DEV}p1"
sudo mkfs.xfs -f -s size=4096 -L PGDATA_NVME "$PART_DEV"

sudo mkdir -p "$MOUNT_POINT"
UUID=$(sudo blkid -s UUID -o value "$PART_DEV")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT xfs rw,noatime,nodiratime,logbsize=256k 0 2" | sudo tee -a /etc/fstab
fi
sudo mount -a
sudo systemctl daemon-reload

echo "=== 4. Installing PostgreSQL $PG_VERSION (PGDG Ubuntu Noble riscv64) ==="
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

sudo apt-get update
sudo apt-get install -y "postgresql-${PG_VERSION}"

echo "=== 5. Relocating Cluster to WD_BLACK SN850X & Tuning for SiFive P550 ==="
sudo systemctl stop postgresql
sudo mkdir -p "${MOUNT_POINT}/postgresql/${PG_VERSION}/main"
sudo chown -R postgres:postgres "${MOUNT_POINT}/postgresql"
sudo chmod 700 "${MOUNT_POINT}/postgresql/${PG_VERSION}/main"

# Sync initial cluster data over to NVMe
sudo rsync -av "/var/lib/postgresql/${PG_VERSION}/main/" "${MOUNT_POINT}/postgresql/${PG_VERSION}/main/"

# Write SiFive P550 32GB LPDDR5 + SN850X Tuning Drop-in
CONF_DIR="/etc/postgresql/${PG_VERSION}/main/conf.d"
sudo mkdir -p "$CONF_DIR"
cat <<EOF | sudo tee "${CONF_DIR}/99-brakerbox-p550.conf"
data_directory = '${MOUNT_POINT}/postgresql/${PG_VERSION}/main'
listen_addresses = '*'

# 32GB LPDDR5 Memory Allocation
shared_buffers = 8GB
effective_cache_size = 24GB
work_mem = 64MB
maintenance_work_mem = 2GB

# SiFive P550 4-Core Out-of-Order RISC-V Tuning
jit = off
max_worker_processes = 4
max_parallel_workers = 4
max_parallel_workers_per_gather = 2

# WD_BLACK SN850X 4Kn PCIe Gen3 x4 I/O & Linux io_uring
io_method = io_uring
random_page_cost = 1.1
effective_io_concurrency = 200
wal_compression = zstd
wal_buffers = 64MB
min_wal_size = 2GB
max_wal_size = 16GB
checkpoint_completion_target = 0.9
EOF

sudo chown -R postgres:postgres "$CONF_DIR"
sudo systemctl start postgresql
sudo systemctl status postgresql --no-pager

echo "=== BrakerBox PostgreSQL $PG_VERSION is LIVE on WD_BLACK SN850X ==="
