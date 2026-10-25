#!/bin/bash
# Remove the DKMS backport and the modprobe workaround.
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run as root (sudo ./uninstall.sh)"
    exit 1
fi

PKG="snd-hda-scodec-cs35l41-thinkbook"
VER="1.0"

if dkms status 2>/dev/null | grep -q "${PKG}/${VER}"; then
    dkms remove "${PKG}/${VER}" --all || true
fi

rm -rf "/usr/src/${PKG}-${VER}"
rm -f /etc/modprobe.d/thinkbook-audio.conf

depmod -a
update-initramfs -u -k all

echo "Removed. Reboot to return to the stock kernel modules."
