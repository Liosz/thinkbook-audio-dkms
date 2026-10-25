#!/bin/bash
# Enable the four-amp fixup (module must already be installed via install.sh).
set -euo pipefail
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run as root (sudo ./audio-fix-on.sh)"
    exit 1
fi

MODPATH="$(modinfo -n snd-hda-scodec-cs35l41 2>/dev/null || true)"
if [[ "$MODPATH" != *"/updates/dkms/"* ]]; then
    echo "WARNING: the loaded/resolved module is not the DKMS one:"
    echo "  ${MODPATH:-<not found>}"
    echo "Run install.sh first. Continuing anyway..."
fi

echo 'options snd_sof_intel_hda_generic hda_model=1028:0c4d' \
    > /etc/modprobe.d/thinkbook-audio.conf
update-initramfs -u -k all
echo "Enabled. Reboot to apply."
