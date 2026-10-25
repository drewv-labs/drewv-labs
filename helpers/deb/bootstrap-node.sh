#!/usr/bin/env bash
# ==============================================================================
# DREW-V Labs // Day-0 Node Bootstrap Script (bootstrap-node.sh)
# Path: helpers/deb/bootstrap-node.sh
# Description: Idempotent user creation, group assignment, passwordless sudo,
#              and hostname configuration for Debian/Ubuntu edge & broker nodes.
#
# Usage:
#   ./bootstrap-node.sh --user drew --hostname brakerbox-titan --nopasswd
# ==============================================================================

set -euo pipefail

# --- Default State ---
TARGET_USER=""
TARGET_HOSTNAME=""
NOPASSWD_SUDO="false"
DEFAULT_GROUPS=("sudo" "adm" "dialout")

# --- Logging Helpers ---
log_info() { printf "\033[1;36m[INFO]\033[0m %s\n" "$1"; }
log_ok()   { printf "\033[1;32m  [OK]\033[0m %s\n" "$1"; }
log_skip() { printf "\033[1;33m[SKIP]\033[0m %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERR!]\033[0m %s\n" "$1" >&2; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -u, --user <username>       Username to create or update
  -H, --hostname <hostname>   New system hostname to configure
  -n, --nopasswd              Enable passwordless sudo (NOPASSWD) for --user
  -h, --help                  Show this help message and exit

Example:
  $0 --user drew --hostname brakerbox-titan --nopasswd
EOF
}

# ==============================================================================
# ARGUMENT PARSER
# ==============================================================================
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            if [[ -z "${2:-}" \vert{}\vert{} "${2:-}" == --* ]]; then
                log_err "Option '$1' requires a username argument."
                exit 1
            fi
            TARGET_USER="$2"
            shift 2
            ;;
        -H|--hostname)
            if [[ -z "${2:-}" \vert{}\vert{} "${2:-}" == --* ]]; then
                log_err "Option '$1' requires a hostname argument."
                exit 1
            fi
            TARGET_HOSTNAME="$2"
            shift 2
            ;;
        -n|--nopasswd|--passwordless-sudo)
            NOPASSWD_SUDO="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate flag combinations
if [[ "$NOPASSWD_SUDO" == "true" && -z "$TARGET_USER" ]]; then
    log_err "--nopasswd requires --user <username> to be specified."
    exit 1
fi

# Escalate to root via sudo if not already running as root
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        log_info "Escalating privileges via sudo..."
        exec sudo -E bash "$0" "$@"
    else
        log_err "This script must be run as root (and 'sudo' is not installed)."
        exit 1
    fi
fi

# Ensure 'sudo' package itself is installed (minimal Debian images often omit it)
if ! command -v sudo >/dev/null 2>&1; then
    log_info "Installing missing 'sudo' package..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q && apt-get install -y sudo
    log_ok "Installed 'sudo'"
fi

# ==============================================================================
# 1. USER & GROUP PROVISIONING (--user)
# ==============================================================================
if [[ -n "$TARGET_USER" ]]; then
    log_info "Processing user configuration for '${TARGET_USER}'..."

    # Validate POSIX username format
    if [[ ! "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_err "Invalid POSIX username format: '${TARGET_USER}'"
        exit 1
    fi

    # 1.1 Idempotent User Creation
    if id -u "$TARGET_USER" >/dev/null 2>&1; then
        log_skip "User '${TARGET_USER}' already exists"
    else
        log_info "Creating user '${TARGET_USER}' (you will be prompted to set a password)..."
        # --gecos "" bypasses interactive Full Name / Room Number / Phone prompts
        adduser --gecos "" "$TARGET_USER"
        log_ok "Created user '${TARGET_USER}'"
    fi

    # 1.2 Idempotent Group Membership Assignment
    for grp in "${DEFAULT_GROUPS[@]}"; do
        if getent group "$grp" >/dev/null 2>&1; then
            if id -nG "$TARGET_USER" \vert{} tr ' ' '\n' \vert{} grep -qx "$grp"; then
                log_skip "User '${TARGET_USER}' is already in group '${grp}'"
            else
                usermod -aG "$grp" "$TARGET_USER"
                log_ok "Added '${TARGET_USER}' to group '${grp}'"
            fi
        else
            log_skip "Group '${grp}' does not exist on this OS; skipping"
        fi
    done
fi

# ==============================================================================
# 2. PASSWORDLESS SUDO (--nopasswd)
# ==============================================================================
if [[ "$NOPASSWD_SUDO" == "true" ]]; then
    SUDOERS_FILE="/etc/sudoers.d/010_${TARGET_USER}-nopasswd"
    SUDOERS_RULE="${TARGET_USER} ALL=(ALL) NOPASSWD: ALL"

    # Check if the exact rule and 0440 permissions are already in place
    if [[ -f "$SUDOERS_FILE" ]] && grep -qxF "$SUDOERS_RULE" "$SUDOERS_FILE" && [[ "$(stat -c "\%a" "$SUDOERS_FILE")" == "440" ]]; then
        log_skip "Passwordless sudo already active at ${SUDOERS_FILE}"
    else
        TMP_SUDO="$(mktemp)"
        echo "$SUDOERS_RULE" > "$TMP_SUDO"
        chmod 0440 "$TMP_SUDO"

        # Validate syntax via visudo before moving into /etc/sudoers.d/
        if visudo -cf "$TMP_SUDO" >/dev/null 2>&1; then
            mv "$TMP_SUDO" "$SUDOERS_FILE"
            chown root:root "$SUDOERS_FILE"
            chmod 0440 "$SUDOERS_FILE"
            log_ok "Configured passwordless sudo in ${SUDOERS_FILE}"
        else
            rm -f "$TMP_SUDO"
            log_err "Generated sudoers rule failed visudo syntax validation!"
            exit 1
        fi
    fi
fi

# ==============================================================================
# 3. HOSTNAME CONFIGURATION (--hostname)
# ==============================================================================
if [[ -n "$TARGET_HOSTNAME" ]]; then
    CURRENT_HOSTNAME="$(hostname)"

    if [[ "$CURRENT_HOSTNAME" == "$TARGET_HOSTNAME" ]]; then
        log_skip "System hostname is already '${TARGET_HOSTNAME}'"
    else
        if command -v hostnamectl >/dev/null 2>&1; then
            hostnamectl set-hostname "$TARGET_HOSTNAME"
        else
            echo "$TARGET_HOSTNAME" > /etc/hostname
            hostname "$TARGET_HOSTNAME"
        fi
        log_ok "Updated system hostname: '${CURRENT_HOSTNAME}' -> '${TARGET_HOSTNAME}'"
    fi

    # Idempotently update /etc/hosts (replaces old hostname or injects 127.0.1.1)
    if grep -qE "[[:space:]]${TARGET_HOSTNAME}([[:space:]]\vert{}$)" /etc/hosts; then
