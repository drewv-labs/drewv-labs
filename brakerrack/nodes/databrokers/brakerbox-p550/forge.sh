#!/usr/bin/env bash
# ==============================================================================
# DREW-V Labs // SiFive HiFive Premier P550 Data Broker Forge Script
# Path: drewv-labs/brakerrack/nodes/databrokers/brakerbox-p550/forge.sh
# Architecture: RVA20 (RV64GC + Zba/Zbb) | 4x P550 3-Wide OoO | 32GB LPDDR5
#
# Usage:
#   ./forge.sh                                 # Standard idempotent P550 + NVMe + PG18 build
#   ./forge.sh --role bench                    # Set hostname to brakerbench-p550 (default: brakerbox-p550)
#   ./forge.sh --with-raid                     # Also provision/mount BigRed-WDR48 & LilBlu-WDB24
#   ./forge.sh --force-wipe-nvme               # Destructively re-format NVMe & rebuild PG
#   ./forge.sh --with-raid --force-wipe-raid   # Destructively rebuild USB RAID10
# ==============================================================================

set -euo pipefail

# --- Configuration Variables ---
NODE_ROLE="${NODE_ROLE:-prod}"
TARGET_HOSTNAME="${TARGET_HOSTNAME:-brakerbox-p550}"
LAB_SUBNET="${LAB_SUBNET:-10.0.10.0/24}"
NVME_DEV="${NVME_DEV:-/dev/nvme0n1}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/nvme_pgdata}"
FS_LABEL="PGDATA_NVME"
USE_LVM="${USE_LVM:-true}"          # true = LVM with 15% snapshot reserve; false = raw GPT partition
VG_NAME="vg_braker"
LV_NAME="lv_pgdata"
PG_VERSION="${PG_VERSION:-18}"

# SilverStone USB 3.0 RAID 10 Configuration (BigRed-WDR48 & LilBlu-WDB24)
BIGRED_MD="/dev/md/bigred"
BIGRED_LABEL="BIGRED_VAULT"
BIGRED_MOUNT="/mnt/bigred_wdr48"

LILBLU_MD="/dev/md/lilblu"
LILBLU_LABEL="LILBLU_ARCH"
LILBLU_MOUNT="/mnt/lilblu_wdb24"

# --- CLI Argument Parsing ---
WITH_RAID="false"
FORCE_WIPE_NVME="false"
FORCE_WIPE_RAID="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --role)
            NODE_ROLE="${2:-prod}"
            if [[ "$NODE_ROLE" == "bench" ]]; then
                TARGET_HOSTNAME="brakerbench-p550"
            else
                TARGET_HOSTNAME="brakerbox-p550"
            fi
            shift 2
            ;;
        --with-raid)       WITH_RAID="true"; shift ;;
        --force-wipe-nvme) FORCE_WIPE_NVME="true"; shift ;;
        --force-wipe-raid) FORCE_WIPE_RAID="true"; shift ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--role prod|bench] [--with-raid] [--force-wipe-nvme] [--force-wipe-raid]"
            exit 1
            ;;
    esac
done

export DEBIAN_FRONTEND=noninteractive
APT_FLAGS=(-y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")

# --- Logging Helpers ---
log_step() { printf "\n\033[1;36m=== [%s] %s ===\033[0m\n" "$(date +%H:%M:%S)" "$1"; }
log_ok()   { printf "\033[1;32m  [OK]\033[0m %s\n" "$1"; }
log_skip() { printf "\033[1;33m[SKIP]\033[0m %s (already configured)\n" "$1"; }
log_warn() { printf "\033[1;31m[WARN]\033[0m %s\n" "$1"; }

# Ensure script runs as root or via sudo
if [[ $EUID -ne 0 ]]; then
   echo "Re-executing with sudo..."
   exec sudo -E bash "$0" "$@"
fi

# ==============================================================================
# STAGE 0: Hostname, Sleep Masking, Headless Strip & Sysctl Tuning
# ==============================================================================
log_step "0. Pregame: Hostname, Power States, Headless Strip & Sysctls"

# 0.1 Idempotent Hostname Check
CURRENT_HOSTNAME="$(hostname)"
if [[ "$CURRENT_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    hostnamectl set-hostname "$TARGET_HOSTNAME"
    if ! grep -qE "[[:space:]]${TARGET_HOSTNAME}([[:space:]]|$)" /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${TARGET_HOSTNAME}/g" /etc/hosts || true
        grep -qE "[[:space:]]${TARGET_HOSTNAME}([[:space:]]|$)" /etc/hosts || printf "127.0.1.1\t%s\n" "$TARGET_HOSTNAME" >> /etc/hosts
    fi
    log_ok "Hostname set to ${TARGET_HOSTNAME} ( was ${CURRENT_HOSTNAME} )"
else
    log_skip "Hostname is already ${TARGET_HOSTNAME}"
fi

# 0.2 Idempotent Sleep/Suspend Masking (Prevents EIC7700X SoC hangs)
SLEEP_TARGETS=(sleep.target suspend.target hibernate.target hybrid-sleep.target)
NEED_MASK="false"
for tgt in "${SLEEP_TARGETS[@]}"; do
    if [[ "$(systemctl is-enabled "$tgt" 2>/dev/null || true)" != "masked" ]]; then
        NEED_MASK="true"
        break
    fi
done

if [[ "$NEED_MASK" == "true" ]]; then
    systemctl mask "${SLEEP_TARGETS[@]}"
    log_ok "Masked sleep, suspend, hibernate, and hybrid-sleep targets"
else
    log_skip "Sleep/suspend targets already masked"
fi

# 0.3 Set Default Boot Target to Headless Console
if [[ "$(systemctl get-default)" != "multi-user.target" ]]; then
    systemctl set-default multi-user.target
    log_ok "Boot target set to headless multi-user.target"
else
    log_skip "Boot target is already multi-user.target"
fi

# 0.4 Idempotent Snap & Desktop GUI Bloat Purge (BEFORE apt upgrade to avoid upgrading bloat)
if command -v snap >/dev/null 2>&1 || dpkg -l snapd 2>/dev/null | grep -q "^ii"; then
    # Remove leaf snaps before base snaps so dependencies don't block removal
    for s in firefox snap-store gnome-42-2204 gtk-common-themes core22 bare snapd; do
        snap remove --purge "$s" 2>/dev/null || true
    done
    systemctl stop snapd.socket snapd.service 2>/dev/null || true
    apt-get purge "${APT_FLAGS[@]}" snapd 2>/dev/null || true
    rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd /root/snap /home/*/snap
    log_ok "Purged snapd and all snap packages"
else
    log_skip "snapd already purged"
fi

GUI_BLOAT=(
    ubuntu-desktop ubuntu-desktop-minimal gnome-shell gdm3 xwayland
    apport whoopsie unattended-upgrades packagekit modemmanager
)
PURGE_LIST=()
for pkg in "${GUI_BLOAT[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        PURGE_LIST+=("$pkg")
    fi
done

if [[ ${#PURGE_LIST[@]} -gt 0 ]]; then
    apt-get purge "${APT_FLAGS[@]}" "${PURGE_LIST[@]}"
    apt-get autoremove "${APT_FLAGS[@]}" --purge
    apt-get clean
    log_ok "Purged GUI & background bloat: ${PURGE_LIST[*]}"
else
    log_skip "Desktop GUI & telemetry bloat already purged"
fi

# 0.5 Install Core Packages & SiFive P550 PWM Fan Controller
CORE_PKGS=(
    fancontrol-config-p550-premier
    mdadm lvm2 xfsprogs parted smartmontools nvme-cli
    linux-tools-common sysstat iotop htop
    jq curl ca-certificates gnupg lsb-release git build-essential
)
MISSING_PKGS=()
for pkg in "${CORE_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    apt-get update -q
    apt-get upgrade "${APT_FLAGS[@]}"
    apt-get install "${APT_FLAGS[@]}" "${MISSING_PKGS[@]}"
    log_ok "Installed core packages: ${MISSING_PKGS[*]}"
else
    log_skip "All core P550 & storage packages already installed"
fi

# 0.6 Idempotent Sysctl Configuration (PMU Counters & Memory Writeback)
SYSCTL_FILE="/etc/sysctl.d/90-brakerbox-broker.conf"
SYSCTL_CONTENT="# Allow non-root perf sampling of P550 L1/PL2/CCACHE hardware counters
kernel.perf_event_paranoid = -1
kernel.kptr_restrict = 0

# Broker memory & dirty page writeback tuning
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15

# Disable NMI watchdog interrupts if supported by kernel architecture
-kernel.nmi_watchdog = 0"

if [[ ! -f "$SYSCTL_FILE" ]] || [[ "$(cat "$SYSCTL_FILE")" != "$SYSCTL_CONTENT" ]]; then
    echo "$SYSCTL_CONTENT" > "$SYSCTL_FILE"
    sysctl --system >/dev/null
    log_ok "Applied P550 PMU & broker sysctl parameters ($SYSCTL_FILE)"
else
    log_skip "Sysctl parameters in $SYSCTL_FILE already up to date"
fi

# ==============================================================================
# STAGE 1 & 2: Verify NVMe Presence & 4Kn Native Sector Size (4096-Byte LBA)
# ==============================================================================
log_step "1 & 2. Verifying NVMe Device ($NVME_DEV) & 4Kn LBA Sector Size"

if [[ ! -b "$NVME_DEV" ]]; then
    log_warn "NVMe device $NVME_DEV not detected! Check PCIe adapter seating and run 'lspci'."
    exit 1
fi

NVME_SHORT="$(basename "$NVME_DEV")"
CURRENT_LBA_SIZE="$(cat "/sys/block/${NVME_SHORT}/queue/logical_block_size")"
EXISTING_FS_DEV="$(blkid -L "$FS_LABEL" || true)"

if [[ -n "$EXISTING_FS_DEV" && "$FORCE_WIPE_NVME" == "false" ]]; then
    log_skip "Existing filesystem labeled '$FS_LABEL' found on $EXISTING_FS_DEV (Logical sector size: ${CURRENT_LBA_SIZE}B)"
else
    if [[ "$CURRENT_LBA_SIZE" == "4096" ]]; then
        log_skip "$NVME_DEV is already formatted to native 4096-byte (4Kn) sectors"
    else
        if lsblk -no MOUNTPOINT "$NVME_DEV" | grep -q "/"; then
            log_warn "$NVME_DEV has active mounts! Unmount before formatting."
            exit 1
        fi

        LBA_4K_INDEX="$(nvme id-ns "$NVME_DEV" | awk '/^lbaf.*lbads:12/ {print $2}' | tr -d ':' | head -n1)"
        if [[ -n "$LBA_4K_INDEX" ]]; then
            echo "Switching $NVME_DEV from ${CURRENT_LBA_SIZE}B to 4096B sectors (LBA Format Index: $LBA_4K_INDEX)..."
            nvme format "$NVME_DEV" -l "$LBA_4K_INDEX" -s 1 --force || nvme format "$NVME_DEV" -l "$LBA_4K_INDEX" --force
            partprobe "$NVME_DEV" || true
            udevadm settle
            sleep 2
            NEW_LBA_SIZE="$(cat "/sys/block/${NVME_SHORT}/queue/logical_block_size")"
            log_ok "$NVME_DEV formatted to ${NEW_LBA_SIZE}-byte native sectors"
        else
            log_warn "Could not auto-detect 4K LBA index on $NVME_DEV; keeping ${CURRENT_LBA_SIZE}B sectors"
        fi
    fi
fi

# ==============================================================================
# STAGE 3A: Partitioning / LVM & XFS Formatting on NVMe + /etc/fstab
# ==============================================================================
log_step "3A. Provisioning NVMe Storage Volume & Mounting XFS ($MOUNT_POINT)"

EXISTING_FS_DEV="$(blkid -L "$FS_LABEL" || true)"

if [[ -n "$EXISTING_FS_DEV" && "$FORCE_WIPE_NVME" == "false" ]]; then
    TARGET_BLOCK_DEV="$EXISTING_FS_DEV"
    log_skip "XFS volume '$FS_LABEL' already exists at $TARGET_BLOCK_DEV"
else
    log_warn "Creating fresh storage layout on $NVME_DEV..."
    umount "$MOUNT_POINT" 2>/dev/null || true

    if [[ "$USE_LVM" == "true" ]]; then
        vgremove -f "$VG_NAME" 2>/dev/null || true
        pvremove -f "$NVME_DEV" 2>/dev/null || true
        wipefs -a "$NVME_DEV"

        pvcreate --dataalignment 4m -f -y "$NVME_DEV"
        vgcreate "$VG_NAME" "$NVME_DEV"
        # Allocate 85% of VG, leaving 15% free for instant benchmark LVM snapshots
        lvcreate -l 85%VG -n "$LV_NAME" -y "$VG_NAME"
        TARGET_BLOCK_DEV="/dev/${VG_NAME}/${LV_NAME}"
        log_ok "Created LVM Logical Volume $TARGET_BLOCK_DEV (with 15% VG snapshot reserve)"
    else
        wipefs -a "$NVME_DEV"
        parted -s "$NVME_DEV" mklabel gpt
        parted -s -a optimal "$NVME_DEV" mkpart primary xfs 1MiB 100%
        partprobe "$NVME_DEV" || true
        udevadm settle
        sleep 2
        TARGET_BLOCK_DEV="${NVME_DEV}p1"
        log_ok "Created GPT partition $TARGET_BLOCK_DEV"
    fi

    SECTOR_SZ="$(cat "/sys/block/${NVME_SHORT}/queue/logical_block_size")"
    mkfs.xfs -f -s "size=${SECTOR_SZ}" -b size=4096 -L "$FS_LABEL" "$TARGET_BLOCK_DEV"
    udevadm settle
    log_ok "Formatted $TARGET_BLOCK_DEV as XFS (label: $FS_LABEL, sector: ${SECTOR_SZ}B)"
fi

mkdir -p "$MOUNT_POINT"

FSTAB_ENTRY="LABEL=${FS_LABEL}  ${MOUNT_POINT}  xfs  rw,noatime,nodiratime,logbsize=256k,nofail,x-systemd.device-timeout=15s  0  2"
if ! grep -q "LABEL=${FS_LABEL}" /etc/fstab && ! grep -q "[[:space:]]${MOUNT_POINT}[[:space:]]" /etc/fstab; then
    echo "$FSTAB_ENTRY" >> /etc/fstab
    systemctl daemon-reload
    log_ok "Added $FS_LABEL to /etc/fstab with nofail protection"
else
    log_skip "$MOUNT_POINT already present in /etc/fstab"
fi

if ! mountpoint -q "$MOUNT_POINT"; then
    mount "$MOUNT_POINT"
    log_ok "Mounted $MOUNT_POINT"
else
    log_skip "$MOUNT_POINT is already mounted"
fi

# ==============================================================================
# STAGE 3B: Optional SilverStone USB RAID 10 (BigRed-WDR48 & LilBlu-WDB24)
# ==============================================================================
provision_usb_raid10() {
    local array_name="$1"
    local md_dev="$2"
    local fs_label="$3"
    local mount_pt="$4"
    local min_bytes="$5"
    local max_bytes="$6"

    echo "--- Checking $array_name ($md_dev -> $mount_pt) ---"
    mdadm --assemble --scan 2>/dev/null || true

    local existing_fs
    existing_fs="$(blkid -L "$fs_label" || true)"

    if [[ -n "$existing_fs" && "$FORCE_WIPE_RAID" == "false" ]]; then
        log_skip "$array_name XFS volume '$fs_label' already exists on $existing_fs"
    else
        # Auto-discover matching disks by byte capacity (avoids /dev/sdX order roulette)
        mapfile -t CANDIDATE_DISKS < <(
            lsblk -b -dn -o NAME,SIZE,TYPE | awk -v min="$min_bytes" -v max="$max_bytes" '
                $3 == "disk" && $2 >= min && $2 <= max { print "/dev/"$1 }
            '
        )

        if [[ ${#CANDIDATE_DISKS[@]} -ne 4 ]]; then
            log_warn "$array_name skipped: Expected 4 individual disks in Clear RAID mode, found ${#CANDIDATE_DISKS[@]} (${CANDIDATE_DISKS[*]:-none})."
            return 0
        fi

        log_warn "Building $array_name RAID 10 across 4 drives: ${CANDIDATE_DISKS[*]}"
        umount "$mount_pt" 2>/dev/null || true
        mdadm --stop "$md_dev" 2>/dev/null || true

        for d in "${CANDIDATE_DISKS[@]}"; do
            mdadm --zero-superblock "$d" 2>/dev/null || true
            wipefs -a "$d"
        done

        # --assume-clean prevents an 18-hour background resync over 5Gbps USB on freshly wiped drives
        mdadm --create "$md_dev" \
            --level=10 --raid-devices=4 \
            --metadata=1.2 --bitmap=internal --assume-clean \
            --name="$array_name" --run --force \
            "${CANDIDATE_DISKS[@]}"

        udevadm settle
        mkfs.xfs -f -b size=4096 -L "$fs_label" "$md_dev"
        udevadm settle
        log_ok "Created and formatted $array_name ($md_dev) with XFS label '$fs_label'"
    fi

    mkdir -p "$mount_pt"
    local raid_fstab="LABEL=${fs_label}  ${mount_pt}  xfs  defaults,noatime,nodiratime,nofail,x-systemd.device-timeout=15s  0  2"
    if ! grep -q "LABEL=${fs_label}" /etc/fstab; then
        echo "$raid_fstab" >> /etc/fstab
        systemctl daemon-reload
        log_ok "Added $fs_label ($mount_pt) to /etc/fstab with nofail protection"
    else
        log_skip "$fs_label already in /etc/fstab"
    fi

    if ! mountpoint -q "$mount_pt"; then
        mount "$mount_pt"
        log_ok "Mounted $mount_pt"
    else
        log_skip "$mount_pt is already mounted"
    fi
}

if [[ "$WITH_RAID" == "true" ]]; then
    log_step "3B. Provisioning SilverStone USB RAID 10 Arrays (BigRed-WDR48 & LilBlu-WDB24)"

    # BigRed-WDR48: 4x 12TB WD Red (~12,000,138,625,024 bytes -> match 11TB to 13TB)
    provision_usb_raid10 "bigred" "$BIGRED_MD" "$BIGRED_LABEL" "$BIGRED_MOUNT" 11000000000000 13000000000000

    # LilBlu-WDB24: 4x 6TB WD Blue (~6,001,175,126,016 bytes -> match 5.5TB to 6.5TB)
    provision_usb_raid10 "lilblu" "$LILBLU_MD" "$LILBLU_LABEL" "$LILBLU_MOUNT" 5500000000000 6500000000000

    # Idempotently persist active mdadm array definitions into /etc/mdadm/mdadm.conf
    mkdir -p /etc/mdadm
    MDADM_SCAN="$(mdadm --detail --scan)"
    if ! grep -qF "$MDADM_SCAN" /etc/mdadm/mdadm.conf 2>/dev/null; then
        sed -i '/^ARRAY /d' /etc/mdadm/mdadm.conf 2>/dev/null || true
        echo "$MDADM_SCAN" >> /etc/mdadm/mdadm.conf
        update-initramfs -u
        log_ok "Updated /etc/mdadm/mdadm.conf and initramfs"
    else
        log_skip "/etc/mdadm/mdadm.conf already contains active array definitions"
    fi
else
    log_step "3B. SilverStone USB RAID Provisioning Skipped (Pass --with-raid to enable)"
fi

# ==============================================================================
# STAGE 4: Installing PostgreSQL $PG_VERSION (PGDG Ubuntu Noble riscv64)
# ==============================================================================
log_step "4. Installing PostgreSQL ${PG_VERSION} (PGDG riscv64)"

PGDG_KEY="/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc"
PGDG_LIST="/etc/apt/sources.list.d/pgdg.list"
CODENAME="$(lsb_release -cs)"

if [[ ! -f "$PGDG_KEY" ]]; then
    install -d /usr/share/postgresql-common/pgdg
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o "$PGDG_KEY"
    log_ok "Downloaded PGDG signing key"
else
    log_skip "PGDG signing key already present"
fi

EXPECTED_REPO="deb [arch=riscv64 signed-by=${PGDG_KEY}] https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main"
if [[ ! -f "$PGDG_LIST" ]] || ! grep -q "${CODENAME}-pgdg" "$PGDG_LIST"; then
    echo "$EXPECTED_REPO" > "$PGDG_LIST"
    apt-get update -q
    log_ok "Configured PGDG repository for ${CODENAME}-pgdg (riscv64)"
else
    log_skip "PGDG repository already configured"
fi

if ! dpkg -s "postgresql-${PG_VERSION}" >/dev/null 2>&1; then
    apt-get update -q
    apt-get install "${APT_FLAGS[@]}" "postgresql-${PG_VERSION}" "postgresql-client-${PG_VERSION}"
    log_ok "Installed postgresql-${PG_VERSION}"
else
    log_skip "postgresql-${PG_VERSION} is already installed"
fi

# ==============================================================================
# STAGE 5: Relocating Cluster to SN850X & Tuning for SiFive P550 32GB
# ==============================================================================
log_step "5. Relocating Cluster to $MOUNT_POINT & Applying SiFive P550 Tuning"

NVME_PG_ROOT="${MOUNT_POINT}/postgresql"
NVME_PG_DATA="${NVME_PG_ROOT}/${PG_VERSION}/main"
DEFAULT_PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
CONF_DIR="/etc/postgresql/${PG_VERSION}/main/conf.d"
DROPIN_CONF="${CONF_DIR}/99-brakerbox-p550.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

# Remove legacy typo config file if present (do NOT delete $DROPIN_CONF)
rm -f "${CONF_DIR}/99-brackerbox-p550.conf"

# 5.1 Idempotent Data Directory Migration
if [[ -f "${NVME_PG_DATA}/PG_VERSION" && "$FORCE_WIPE_NVME" == "false" ]]; then
    log_skip "PostgreSQL cluster already initialized on NVMe at ${NVME_PG_DATA}"
else
    echo "Migrating initial PostgreSQL ${PG_VERSION} cluster to ${NVME_PG_DATA}..."
    systemctl stop postgresql
    mkdir -p "$NVME_PG_DATA"
    chown -R postgres:postgres "$NVME_PG_ROOT"
    chmod 700 "$NVME_PG_DATA"

    rsync -a "${DEFAULT_PG_DATA}/" "${NVME_PG_DATA}/"
    chown -R postgres:postgres "$NVME_PG_ROOT"
    log_ok "Synced clean cluster from $DEFAULT_PG_DATA to $NVME_PG_DATA"
fi

# If BigRed / LilBlu are mounted, prepare warm/cold PostgreSQL tablespace directories
for raid_mp in "$BIGRED_MOUNT" "$LILBLU_MOUNT"; do
    if mountpoint -q "$raid_mp"; then
        mkdir -p "${raid_mp}/postgresql/tablespaces"
        chown -R postgres:postgres "${raid_mp}/postgresql"
        chmod 700 "${raid_mp}/postgresql/tablespaces"
    fi
done

# 5.2 Auto-verify io_uring support in PostgreSQL binary & kernel
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin/postgres"
IO_METHOD="worker"
if [[ -x "$PG_BIN" ]] && ldd "$PG_BIN" | grep -q "liburing"; then
    if [[ "$(sysctl -n kernel.io_uring_disabled 2>/dev/null || echo 0)" == "0" ]]; then
        IO_METHOD="io_uring"
    fi
fi
log_ok "Selected PostgreSQL 18 Async I/O method: io_method = ${IO_METHOD}"

# 5.3 Idempotent Drop-In Tuning File & Lab Subnet pg_hba.conf Rule
mkdir -p "$CONF_DIR"
DESIRED_PG_CONF="# DREW-V Labs: SiFive HiFive Premier P550 (32GB LPDDR5 + WD_BLACK SN850X 4Kn)
data_directory = '${NVME_PG_DATA}'
listen_addresses = '*'

# 32GB LPDDR5 Memory Allocation
shared_buffers = 8GB
effective_cache_size = 24GB
work_mem = 64MB
maintenance_work_mem = 2GB
huge_pages = try

# SiFive P550 4-Core (3-Wide Out-of-Order, RVA20+Zba/Zbb) Tuning
jit = off
max_worker_processes = 4
max_parallel_workers = 4
max_parallel_workers_per_gather = 2

# WD_BLACK SN850X 4Kn PCIe Gen3 x4 & PostgreSQL 18 Async I/O
io_method = ${IO_METHOD}
effective_io_concurrency = 200
maintenance_io_concurrency = 100
random_page_cost = 1.1
track_io_timing = on

# WAL & Checkpoints
wal_compression = zstd
wal_buffers = 64MB
min_wal_size = 2GB
max_wal_size = 16GB
checkpoint_completion_target = 0.9"

NEED_PG_RESTART="false"
if [[ ! -f "$DROPIN_CONF" ]] || [[ "$(cat "$DROPIN_CONF")" != "$DESIRED_PG_CONF" ]]; then
    echo "$DESIRED_PG_CONF" > "$DROPIN_CONF"
    chown -R postgres:postgres "$CONF_DIR"
    NEED_PG_RESTART="true"
    log_ok "Wrote tuning configuration to $DROPIN_CONF"
else
    log_skip "PostgreSQL configuration $DROPIN_CONF is already up to date"
fi

if [[ -f "$PG_HBA" ]] && ! grep -qF "$LAB_SUBNET" "$PG_HBA"; then
    printf "\n# DREW-V Labs BrakerRack Subnet Access\nhost    all             all             %s            scram-sha-256\n" "$LAB_SUBNET" >> "$PG_HBA"
    NEED_PG_RESTART="true"
    log_ok "Added lab subnet ($LAB_SUBNET) rule to $PG_HBA"
else
    log_skip "Lab subnet ($LAB_SUBNET) already authorized in $PG_HBA"
fi

# 5.4 Ensure Service is Running & Healthy
if ! systemctl is-active --quiet postgresql || [[ "$NEED_PG_RESTART" == "true" ]]; then
    systemctl enable postgresql >/dev/null 2>&1 || true
    systemctl restart postgresql
    log_ok "PostgreSQL ${PG_VERSION} service started/restarted"
else
    log_skip "PostgreSQL ${PG_VERSION} is already active and running current config"
fi

# ==============================================================================
# STAGE 6: Post-Flight Verification Summary
# ==============================================================================
log_step "6. Post-Flight Verification Summary"

ACTIVE_DATA_DIR="$(sudo -u postgres psql -tAc "SHOW data_directory;" 2>/dev/null || echo "N/A")"
ACTIVE_IO_METHOD="$(sudo -u postgres psql -tAc "SHOW io_method;" 2>/dev/null || echo "N/A")"
ACTIVE_BUFFERS="$(sudo -u postgres psql -tAc "SHOW shared_buffers;" 2>/dev/null || echo "N/A")"
FINAL_LBA="$(cat "/sys/block/${NVME_SHORT}/queue/logical_block_size")"

printf "  • Hostname           : %s\n" "$(hostname)"
printf "  • Kernel / Arch      : %s (%s)\n" "$(uname -r)" "$(uname -m)"
printf "  • NVMe LBA Block Sz  : %s bytes\n" "$FINAL_LBA"
printf "  • Hot NVMe Mount     : %s\n" "$(findmnt -n -o SOURCE,TARGET,FSTYPE,OPTIONS "$MOUNT_POINT" || echo "Not Mounted")"
printf "  • Warm RAID (BigRed) : %s\n" "$(findmnt -n -o SOURCE,TARGET,FSTYPE "$BIGRED_MOUNT" 2>/dev/null || echo "Not Mounted")"
printf "  • Cold RAID (LilBlu) : %s\n" "$(findmnt -n -o SOURCE,TARGET,FSTYPE "$LILBLU_MOUNT" 2>/dev/null || echo "Not Mounted")"
printf "  • PG Data Directory  : %s\n" "$ACTIVE_DATA_DIR"
printf "  • PG 18 Async I/O    : io_method = %s\n" "$ACTIVE_IO_METHOD"
printf "  • PG Shared Buffers  : %s\n" "$ACTIVE_BUFFERS"

echo ""
log_ok "${TARGET_HOSTNAME} PostgreSQL ${PG_VERSION} Forge Complete!"
