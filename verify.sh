#!/bin/bash
# Read-only status check. Safe to run as a normal user.
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:$PATH"
echo "=== kernel ==="
uname -r
echo
echo "=== DKMS ==="
dkms status 2>/dev/null || echo "dkms not installed"
echo
echo "=== resolved cs35l41 module ==="
modinfo -n snd-hda-scodec-cs35l41 2>/dev/null || echo "module not found"
echo
echo "=== i2c amps bound to cs35l41-hda ==="
ls -l /sys/bus/i2c/drivers/cs35l41-hda/ 2>/dev/null || echo "driver dir not found"
echo
echo "=== modprobe workaround ==="
cat /etc/modprobe.d/thinkbook-audio.conf 2>/dev/null || echo "(not enabled)"
echo
echo "=== PipeWire audio sinks ==="
wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p' || true
echo
echo "Test tone (optional):"
echo "  timeout 5 speaker-test -D hw:0,0 -c 2 -t sine -f 440 -l 1"
if [[ $EUID -eq 0 ]]; then
    echo
    echo "=== recent kernel audio messages ==="
    dmesg | grep -iE "17AA3929|cs35l41|Falling back to default firmware" | tail -20 || true
fi
