#!/usr/bin/env bash
#
# wsl2-hardware-pack.sh
# Hardware / diagnostic tools bundle for WSL2 (Debian/Ubuntu).
# Designed to be friendly to HP OmniBook Copilot/Copilot+ PCs:
# - No systemd/init modifications
# - No firmware/BIOS flashing tools
# - Only user‑space utilities

set -euo pipefail

echo "==> WSL2 Hardware Tools Pack"

# Require root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Please run this script as root, e.g.:"
  echo "  sudo $0"
  exit 1
fi

# Very basic WSL detection
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null \
   || grep -qiE "microsoft|wsl" /proc/sys/kernel/osrelease 2>/dev/null \
   || [ -n "${WSL_INTEROP-}" ]; then
  echo "Detected WSL/WSL2 environment."
else
  echo "Warning: this does not look like WSL. Continuing anyway..."
fi

# Check that we’re on an apt-based distro
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently supports Debian/Ubuntu (apt-get)."
  echo "On other distros, adapt the package list to your package manager."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo
echo "==> Updating package index..."
apt-get update -y -q

install_group () {
  local group_name="$1"
  shift
  local pkgs=("$@")

  echo
  echo "==> Installing ${group_name}..."
  echo "Packages: ${pkgs[*]}"

  # If some packages are missing on your release, this will warn but not abort.
  if ! apt-get install -y -q --no-install-recommends "${pkgs[@]}"; then
    echo "!! Warning: some packages in group '${group_name}' could not be installed."
  fi
}

# 1. Hardware / system enumeration
install_group "hardware / system enumeration tools" \
  pciutils \
  usbutils \
  lshw \
  hwinfo \
  dmidecode \
  inxi \
  lsscsi \
  lvm2

# 2. Storage utilities (no partition table manipulation is done automatically)
install_group "storage utilities" \
  smartmontools \
  hdparm \
  sdparm \
  nvme-cli \
  parted

# 3. Sensors & power info (safe, read‑only by default)
install_group "sensors & power tools" \
  lm-sensors \
  acpi

# 4. Network & wireless (WSL2 sees a virtual NIC; Wi‑Fi is still managed by Windows)
install_group "network & wireless tools" \
  ethtool \
  net-tools \
  wireless-tools \
  wpasupplicant \
  iproute2 \
  iputils-ping

# 5. GPU / graphics helper tools (for WSLg / GPU passthrough)
# Not touching drivers, just tools to query capabilities.
install_group "graphics / GPU helper tools" \
  mesa-utils \
  vulkan-tools \
  clinfo

# 6. Audio utilities (WSLg uses Windows audio; these just give CLI tools)
install_group "audio utilities" \
  alsa-utils \
  pulseaudio-utils

# 7. Misc debug helpers
install_group "misc system utilities" \
  psmisc \
  lsof \
  file \
  strace

echo
echo "============================================================"
echo "Installed hardware/diagnostic tools pack for WSL2."
echo
echo "- No systemd/init system packages were explicitly installed or altered."
echo "- No firmware/BIOS flashing tools were installed."
echo "- On WSL2, many tools will see virtualized devices; that's expected."
echo
echo "Optional next step (inside WSL2) to probe sensors safely:"
echo "  sudo sensors-detect"
echo "  sensors"
echo
echo "Done."
echo "============================================================"
