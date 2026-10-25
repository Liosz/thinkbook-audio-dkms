#!/bin/bash
# Disable the four-amp fixup. The DKMS module stays installed but is inert.
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run as root (sudo ./audio-fix-off.sh)"
    exit 1
fi

rm -f /etc/modprobe.d/thinkbook-audio.conf
update-initramfs -u -k all
echo "Disabled. Reboot to apply."
