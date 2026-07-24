#!/bin/bash
#
# Enable PlayStation-controller support (DualShock 4 + AceGamer-style clones)
# on a Jetson whose L4T kernel ships without CONFIG_HID_PLAYSTATION.
#
# Without this, a PS4-style pad binds to hid-generic: wrong mapping, no
# battery, and clone pads never get the USB "activation" handshake they
# require before they will enter Bluetooth pairing mode at all.
#
# Run ON THE CAR'S HOST OS (not inside an airfield container), once per car:
#
#   ssh <car>
#   ~/roboracer_ws/scripts/install_ds4_driver.sh
#
# Any working directory is fine; needs sudo. Builds scripts/hid_playstation/
# (vendored kernel v6.8 source) via DKMS so the module survives reboots AND
# kernel updates. Falls back to a one-shot manual build if DKMS can't be
# installed (offline car) — re-run after kernel updates in that case.
#
# Afterwards, pair each controller: see docs/AIRFIELD.md §4f, or the summary
# this script prints at the end. Day-to-day pairing management (list/unpair):
# scripts/bluetooth_controller_manager.sh
#
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="$SCRIPT_DIR/hid_playstation"
KREL="$(uname -r)"
PKG=hid-playstation
VER=6.8   # keep in sync with PACKAGE_VERSION in hid_playstation/dkms.conf

say() { echo "[ds4] $*"; }

# --- 0. sanity -------------------------------------------------------------
[ -f "$SRC_DIR/hid-playstation.c" ] || { echo "ERROR: $SRC_DIR missing" >&2; exit 1; }

BUILD_DIR="/lib/modules/$KREL/build"
if [ ! -e "$BUILD_DIR/Makefile" ]; then
    echo "ERROR: kernel headers missing at $BUILD_DIR" >&2
    echo "JetPack preinstalls them; reinstall the matching L4T kernel-headers package and re-run." >&2
    exit 1
fi

if modprobe -n -q hid-playstation 2>/dev/null && [ ! -e "/lib/modules/$KREL/updates" ]; then
    # modprobe resolves it and nothing lives in updates/ -> the kernel itself
    # ships the driver (a future JetPack may enable it); nothing to build.
    say "kernel already provides hid-playstation; skipping build"
    sudo modprobe hid-playstation
    exit 0
fi

# --- 1. build & install ----------------------------------------------------
USE_DKMS=1
if ! command -v dkms >/dev/null 2>&1; then
    say "installing dkms..."
    sudo apt-get update -qq && sudo apt-get install -y dkms || USE_DKMS=0
fi

if [ "$USE_DKMS" = 1 ]; then
    say "installing $PKG/$VER via DKMS"
    # migrate away any pre-DKMS manual install BEFORE dkms runs, or dkms
    # archives it as "original_module" and restores it on every remove
    sudo rm -f "/lib/modules/$KREL/updates/hid-playstation.ko"
    sudo rm -rf "/usr/src/${PKG}-${VER}"
    sudo cp -a "$SRC_DIR" "/usr/src/${PKG}-${VER}"
    sudo dkms remove -m "$PKG" -v "$VER" --all >/dev/null 2>&1 || true
    sudo dkms add -m "$PKG" -v "$VER"
    sudo dkms install -m "$PKG" -v "$VER"
else
    say "dkms unavailable — one-shot build for $KREL (re-run after kernel updates)"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    cp -a "$SRC_DIR"/. "$TMP/"
    make -C "$TMP"
    sudo install -D -m644 "$TMP/hid-playstation.ko" \
        "/lib/modules/$KREL/updates/hid-playstation.ko"
fi
sudo depmod -a

# --- 2. load now + autoload at every boot ----------------------------------
echo hid-playstation | sudo tee /etc/modules-load.d/hid-playstation.conf >/dev/null
sudo modprobe hid-playstation
grep -qw '^hid_playstation' /proc/modules || { echo "ERROR: module did not load" >&2; exit 1; }
say "loaded: $(modinfo -F filename hid-playstation)"

# --- 3. next steps ---------------------------------------------------------
cat <<'EOF'

Driver installed. To pair a controller with THIS car (once per controller):
  1. Plug the controller in via USB — the 'playstation' driver claims it and
     runs the activation handshake clones need. Verify + get its Bluetooth MAC:
         ls /sys/class/power_supply/     ->  ps-controller-battery-<MAC>
  2. Unplug USB. Hold SHARE + PS ~5 s until the lightbar flashes (pairing mode).
  3. Pair (substitute the MAC from step 1):
         bluetoothctl --timeout 30 scan on    # wait for the MAC to appear
         bluetoothctl pair <MAC> && bluetoothctl trust <MAC> && bluetoothctl connect <MAC>
Once trusted, the PS button alone reconnects it from then on.
EOF
