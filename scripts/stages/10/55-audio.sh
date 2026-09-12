#!/bin/sh

# Enable microphone capture for voice search.
#
# The Car Thing's mic is exposed via Amlogic snd-soc drivers in the stock
# kernel modules (already copied into /usr/lib/modules by 50-stock-files.sh).
# We install arecord (alsa-utils), write an asound.conf with a "default"
# capture PCM, and add a one-shot service that runs depmod + probes all
# sound modules at first boot. Discovery is logged to /var/log/nocturne-audio.log
# so a working setup can be inspected after the first boot.

xbps-install -r "$ROOTFS_PATH" -y alsa-utils

# ALSA default config: route the "default" PCM to the first capture-capable card.
# arecord and Web/Native APIs that rely on "default" will pick up the PDM mic
# once snd-soc modules are loaded.
cat > "$ROOTFS_PATH"/etc/asound.conf <<'EOF'
pcm.!default {
    type asym
    playback.pcm "plughw:0,0"
    capture.pcm  "plughw:0,0"
}

ctl.!default {
    type hw
    card 0
}
EOF

# Audio module loader: probes every snd*.ko module shipped by the stock kernel,
# tolerant of missing modules. Runs once at first boot then logs results.
mkdir -p "$ROOTFS_PATH"/etc/sv/nocturne-audio
cat > "$ROOTFS_PATH"/etc/sv/nocturne-audio/run <<'EOF'
#!/bin/sh
exec 2>&1

LOG=/var/log/nocturne-audio.log
STAMP=/etc/nocturne/audio-loaded

if [ ! -f "$STAMP" ]; then
    mkdir -p /etc/nocturne
    {
        echo "=== nocturne-audio init $(date) ==="

        KVER=$(uname -r)
        MODDIR="/usr/lib/modules/$KVER"
        if [ ! -d "$MODDIR" ]; then
            MODDIR=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d | head -n1)
        fi
        echo "module dir: $MODDIR"

        depmod -a 2>&1 || echo "depmod failed (continuing)"

        # Probe every snd-* and amlogic audio related module
        find "$MODDIR" \( -name 'snd*.ko' -o -name 'aml*audio*.ko' -o -name '*pdm*.ko' \) | while read -r mod; do
            name=$(basename "$mod" .ko)
            if modprobe "$name" 2>/dev/null; then
                echo "loaded: $name"
            fi
        done

        echo "--- arecord -L ---"
        arecord -L 2>&1 || true
        echo "--- /proc/asound/cards ---"
        cat /proc/asound/cards 2>&1 || true

        touch "$STAMP"
        echo "=== done ==="
    } > "$LOG" 2>&1
fi

# One-shot: stay alive so runit doesn't loop-restart us.
exec sleep infinity
EOF
chmod +x "$ROOTFS_PATH"/etc/sv/nocturne-audio/run

DEFAULT_SERVICES="${DEFAULT_SERVICES} nocturne-audio"
