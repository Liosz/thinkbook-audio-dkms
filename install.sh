#!/bin/bash
# Install the ThinkBook X G2 IAH / 17AA3929 CS35L41 DKMS backport.
# Run as root:  sudo ./install.sh [--no-enable]
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="snd-hda-scodec-cs35l41-thinkbook"
VER="1.0"
KREL="$(uname -r)"
ENABLE=1

for arg in "$@"; do
    case "$arg" in
        --enable)    ENABLE=1 ;;
        --no-enable) ENABLE=0 ;;
        *) echo "Unknown option: $arg"; echo "Usage: sudo $0 [--no-enable]"; exit 1 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run as root (sudo ./install.sh or pkexec ./install.sh)"
    exit 1
fi

if [[ ! "$KREL" =~ ^6\.12\. ]]; then
    echo "ERROR: this backport is restricted to kernel 6.12.x; current: $KREL"
    exit 1
fi

echo "Kernel: $KREL"
echo "Installing build dependencies (this does NOT change the kernel image):"
echo "  dkms build-essential linux-headers-amd64 linux-headers-$KREL"
echo "  dwarves libelf-dev libssl-dev firmware-cirrus"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    dkms build-essential linux-headers-amd64 "linux-headers-$KREL" \
    dwarves libelf-dev libssl-dev firmware-cirrus

SRC="/usr/src/${PKG}-${VER}"
rm -rf "$SRC"
install -d "$SRC"
cp -a "$HERE/dkms-src/." "$SRC/"

if dkms status | grep -q "${PKG}/${VER}"; then
    dkms remove "${PKG}/${VER}" --all || true
fi

dkms add "$SRC"
dkms build "${PKG}/${VER}" -k "$KREL"
dkms install "${PKG}/${VER}" -k "$KREL" --force

# Build for other installed 6.12 kernels too, if their headers exist.
dkms autoinstall >/dev/null 2>&1 || true

if [[ "$ENABLE" -eq 1 ]]; then
    echo 'options snd_sof_intel_hda_generic hda_model=1028:0c4d' \
        > /etc/modprobe.d/thinkbook-audio.conf
    update-initramfs -u -k all
fi

echo
echo "=== DKMS status ==="
dkms status || true
echo
echo "=== module path ==="
modinfo -n snd-hda-scodec-cs35l41 || true
echo
if [[ "$ENABLE" -eq 1 ]]; then
    echo "Audio fix ENABLED (hda_model=1028:0c4d). Reboot, then test the speakers."
else
    echo "Module installed but audio fix DISABLED."
    echo "Run 'sudo ./audio-fix-on.sh' and reboot to enable it."
fi
