#!/usr/bin/env bash
# iMac17,1 (27" 5K, Late 2015) speaker tuning installer for PipeWire on
# Fedora 45 (dnf) or Ubuntu 26.04 (apt); both tested on the real machine.
#
# What it does:
#   1. Installs the LV2 plugins the tuning needs (dnf or apt, needs sudo).
#   2. Sets `options snd-hda-intel model=imac27` so the kernel exposes the
#      separate tweeter + woofer channels (needs sudo, then a reboot).
#   3. Installs taprobane99's measured speaker tuning (FIR filters, bass
#      enhancement, loudness compensation, woofer protection) as a PipeWire
#      filter-chain for the current user.
#   4. Adds WirePlumber rules that select the 4.0 card profile automatically
#      and hide the raw (untuned) 4.0 output from sound menus.
#   5. Once the quirk is active (after reboot), sets the hardware level and
#      makes "iMac Speakers" the default output.
#
# Safe to re-run: every step is skipped if already done. Run it once, reboot
# when told, then run it again to finish.
#
# Usage:  ./install.sh            install / finish install
#         ./install.sh --uninstall remove everything this script added
#         ./install.sh --force     skip the iMac17,1 model check
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES="$HERE/files"

IRS_DIR="$HOME/.local/share/imac-audio"
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/70-imac-audio.conf"
WP_CONF="$HOME/.config/wireplumber/wireplumber.conf.d/51-imac-audio-profile.conf"
MODPROBE_FILE="/etc/modprobe.d/imac-audio.conf"
MODPROBE_LINE="options snd-hda-intel model=imac27"

# Same three components on each distro, under different package names:
# LSP plugins, bankstown bass enhancer, and PipeWire's LV2 filter-graph plugin.
if command -v dnf >/dev/null; then
    PKG=dnf
    PACKAGES=(lsp-plugins-lv2 lv2-bankstown pipewire-module-filter-chain-lv2)
elif command -v apt-get >/dev/null; then
    PKG=apt
    PACKAGES=(lsp-plugins-lv2 bankstown-lv2 libspa-0.2-modules-extra pulseaudio-utils)
else
    PKG=none
    PACKAGES=()
fi

pkg_installed() {
    case $PKG in
        dnf) rpm -q "$1" >/dev/null 2>&1 ;;
        apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    esac
}

pkg_install() {
    case $PKG in
        dnf) sudo dnf install -y "$@" ;;
        apt)
            # bankstown-lv2 is in Ubuntu's "universe" component.
            if ! apt-cache policy bankstown-lv2 2>/dev/null | grep -q 'Candidate: [0-9]'; then
                warn "Enabling Ubuntu 'universe' repository (needed for bankstown-lv2)"
                sudo add-apt-repository -y universe
            fi
            sudo apt-get update
            sudo apt-get install -y "$@"
            ;;
    esac
}

pkg_remove_hint() {
    case $PKG in
        dnf) echo "sudo dnf remove ${PACKAGES[*]}" ;;
        apt) echo "sudo apt remove ${PACKAGES[*]}" ;;
    esac
}

CARD="alsa_card.pci-0000_00_1f.3"
PROFILE="output:analog-surround-40+input:analog-stereo"
HW_SINK="alsa_output.pci-0000_00_1f.3.analog-surround-40"
DSP_SINK="audio_effect.iMac convolver"
HW_VOLUME="79%"   # level recommended by the tuning's author

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run as your normal user, not root (sudo is used only where needed)."

restart_audio() {
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 3
}

quirk_active() {
    grep -q '^imac27' /sys/module/snd_hda_intel/parameters/model 2>/dev/null
}

uninstall() {
    info "Removing iMac speaker tuning"
    rm -f "$PW_CONF" "$WP_CONF" && ok "Removed PipeWire / WirePlumber config"
    rm -rf "$IRS_DIR" && ok "Removed $IRS_DIR"
    if [[ -f $MODPROBE_FILE ]]; then
        sudo rm -f "$MODPROBE_FILE" && ok "Removed $MODPROBE_FILE (reboot to apply)"
    fi
    restart_audio
    pactl set-card-profile "$CARD" output:analog-stereo+input:analog-stereo 2>/dev/null || true
    ok "Done. Packages (${PACKAGES[*]}) were left installed; remove with: $(pkg_remove_hint)"
    exit 0
}

FORCE=0
case "${1:-}" in
    --uninstall) uninstall ;;
    --force) FORCE=1 ;;
    "") ;;
    *) die "Unknown option: $1 (use --uninstall or --force)" ;;
esac

# --- Checks -----------------------------------------------------------------
info "Checking system"
MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
if [[ $MODEL != "iMac17,1" ]]; then
    [[ $FORCE -eq 1 ]] || die "This tuning was measured on an iMac17,1; this machine is '$MODEL'. Use --force to install anyway."
    warn "Model is '$MODEL', continuing because of --force"
else
    ok "Model: $MODEL"
fi
[[ $PKG != none ]] || die "Neither dnf nor apt found; this installer supports Fedora and Ubuntu."
ok "Package manager: $PKG"
systemctl --user is-active --quiet pipewire wireplumber \
    || die "PipeWire / WirePlumber aren't running for this user; this setup needs them."
(cd "$FILES" && sha256sum --quiet -c SHA256SUMS) || die "Bundled files failed checksum verification."
ok "Bundled files verified"

# --- 1. Packages ------------------------------------------------------------
info "Plugins"
missing=()
for p in "${PACKAGES[@]}"; do pkg_installed "$p" || missing+=("$p"); done
if ((${#missing[@]})); then
    pkg_install "${missing[@]}"
    ok "Installed ${missing[*]}"
else
    ok "Already installed"
fi
for t in pactl wpctl pw-dump python3; do
    command -v "$t" >/dev/null || die "'$t' not found after installing packages."
done

# --- 2. Kernel quirk --------------------------------------------------------
info "Kernel driver option"
if [[ -f $MODPROBE_FILE ]] && grep -Fxq "$MODPROBE_LINE" "$MODPROBE_FILE"; then
    ok "Already set in $MODPROBE_FILE"
else
    echo "$MODPROBE_LINE" | sudo tee "$MODPROBE_FILE" >/dev/null
    ok "Wrote $MODPROBE_FILE"
fi

# --- 3. Tuning files + filter-chain ----------------------------------------
info "Speaker tuning"
mkdir -p "$IRS_DIR" "$(dirname "$PW_CONF")" "$(dirname "$WP_CONF")"
install -m644 "$FILES"/*.wav "$FILES/LICENSE.upstream" "$IRS_DIR"/
sed "s|@IRS_DIR@|$IRS_DIR|g" "$FILES/iMacAudio.conf.in" > "$PW_CONF"
ok "Installed filters to $IRS_DIR and config to $PW_CONF"

# --- 4. Auto-select 4.0 profile ---------------------------------------------
cat > "$WP_CONF" <<EOF
# 1. Select the 4-channel profile (tweeters FL/FR, woofers RL/RR) for the
#    iMac's built-in audio, so the speaker tuning has its output device.
# 2. Hide that raw 4.0 output from sound menus: selected directly it plays
#    untuned audio with no crossover. The tuning still feeds it.
# 3. Rename the card, so GNOME's leftover "Speakers" entry (a card port,
#    which can't be hidden) reads as raw/untuned rather than the real output.
monitor.alsa.rules = [
  {
    matches = [ { device.name = "$CARD" } ]
    actions = { update-props = {
      device.profile = "$PROFILE"
      device.description = "Built-in Audio (raw, untuned)"
    } }
  }
  {
    matches = [ { node.name = "$HW_SINK" } ]
    actions = { update-props = { media.class = "Audio/Sink/Internal" } }
  }
]
EOF
ok "Installed WirePlumber rules (4.0 profile, hide/rename raw output) to $WP_CONF"

# --- 5. Activate ------------------------------------------------------------
if ! quirk_active; then
    echo
    warn "The kernel option takes effect after a reboot."
    warn "Reboot, then run this script again to finish setup:  $0"
    exit 0
fi

info "Activating"
restart_audio
pactl set-card-profile "$CARD" "$PROFILE"
sleep 2
# The raw 4.0 output is hidden from pactl, so address it by PipeWire node id.
HW_ID="$(pw-dump | python3 -I -c '
import json, sys
name = sys.argv[1]
print(next((o["id"] for o in json.load(sys.stdin)
            if o.get("info", {}).get("props", {}).get("node.name") == name), ""))
' "$HW_SINK")"
[[ -n $HW_ID ]] || die "4.0 output ($HW_SINK) did not appear."
pactl list short sinks | grep -qF "$DSP_SINK" || die "Tuned sink did not load; check: journalctl --user -u pipewire"
wpctl set-volume "$HW_ID" "$HW_VOLUME"
pactl set-default-sink "$DSP_SINK"
ok "Card profile: 4.0, hardware level: $HW_VOLUME, default output: iMac Speakers"

echo
ok "All done. Use the normal volume slider for 'iMac Speakers'."
