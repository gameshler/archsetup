#!/usr/bin/env bash

# menu: Base Setup
# desc: Core packages, pacman config and fastest mirrors

. "$COMMON_SCRIPT"

set -euo pipefail

# Rank mirrors worldwide by measured download rate, with no country filter.
#
# Filtering by country is what starved this box of mirrors: a small country can
# publish only a handful, and the Arch wiki says so outright — "It is typically
# not a good idea to filter by country; there are only a finite number of
# mirrors in a single country. Network throughput is only partly determined by
# geographical distance." So the pool is every HTTPS mirror synced recently,
# narrowed by --latest, then rate-tested by --fastest.
#
# reflector.service re-runs this on every boot (see enable_reflector), so the
# list follows whatever is actually fast from here today.
readonly -a REFLECTOR_ARGS=(
    --protocol https   # HTTPS only
    --age 12           # synced within the last 12 hours
    --latest 40        # 40 most recently synced, worldwide
    --fastest 10       # rate-test those, keep the 10 fastest
    --sort rate
)

rank_mirrors() {
    printf "%b\n" "Ranking mirrors worldwide by download rate (no country filter)..."

    # Timestamped, so a second run cannot overwrite the pristine backup with an
    # already-reflector-generated list.
    sudo cp /etc/pacman.d/mirrorlist "/etc/pacman.d/mirrorlist.bak.$(date +%Y%m%d-%H%M%S)"
    
    sudo reflector --verbose "${REFLECTOR_ARGS[@]}" --save "/etc/pacman.d/mirrorlist" || printf "%b\n" "reflector produced no usable mirrors; keeping the existing mirrorlist."
        
}

enable_reflector() {
    sudo mkdir -p /etc/xdg/reflector
    # reflector.service reads its options from this file. --save must be in it,
    # or the boot run would print to stdout and never touch the mirrorlist.
    printf '%s --save /etc/pacman.d/mirrorlist\n' "${REFLECTOR_ARGS[*]}" |
        sudo tee /etc/xdg/reflector/reflector.conf >/dev/null

    # reflector.service runs on every boot; reflector.timer runs it weekly. The
    # wiki calls enabling both redundant, and "on every boot" is what we want
    # here, so enable only the service and make sure the timer is not also armed.
    #
    # The service needs the network genuinely up, not merely configured, so the
    # NetworkManager wait unit must back network-online.target.
    sudo systemctl enable NetworkManager-wait-online.service
    sudo systemctl enable reflector.service
    sudo systemctl disable reflector.timer 2>/dev/null || true

    printf "%b\n" "reflector.service enabled — mirrors are re-ranked on every boot."
}

main() {

    printf "%b\n" "Checking System Package Manager and AUR"

    sudo "$PACKAGER" -Syu --noconfirm
    # pacman config
    printf "%b\n" "Configuring pacman"
    sudo sed -i -E \
        -e 's/^\s*#\s*(Color)/\1/' \
        -e 's/^\s*#\s*(ParallelDownloads\s*=)/\1/' \
        /etc/pacman.conf

    # Shared with system/gpu-driver.sh, which needs multilib for its lib32-*
    # packages and cannot assume this tab has already run.
    enable_multilib

    if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^ParallelDownloads *=.*/a ILoveCandy' /etc/pacman.conf
    fi

    sudo "$PACKAGER" -Syyu --noconfirm

    install_packages \
        libreoffice-fresh vlc curl flatpak fastfetch p7zip unzip unrar tar rsync \
        exfat-utils fuse-exfat flac jdk-openjdk gimp \
        base-devel mangohud lib32-mangohud \
        htop steam reflector python rust git

    rank_mirrors
    enable_reflector

    # mangohud config
    printf "%b\n" "Configuring MangoHud"
    mkdir -p "$HOME/.config/MangoHud" && cp /usr/share/doc/mangohud/MangoHud.conf.example "$HOME/.config/MangoHud/MangoHud.conf" || true
    config_file="$HOME/.config/MangoHud/MangoHud.conf"

    # Settings you want to enable
    settings_to_uncomment=(
        "gpu_stats"
        "gpu_temp"
        "gpu_core_clock"
        "gpu_mem_temp"
        "gpu_mem_clock"
        "gpu_power"
        "gpu_voltage"
        "cpu_stats"
        "cpu_temp"
        "cpu_power"
        "cpu_mhz"
        "fps"
        "frametime"
        "throttling_status"
        "frame_timing"
        "text_outline"
    )

    # Loop and uncomment each line that starts with the key (if commented)
    for setting in "${settings_to_uncomment[@]}"; do
        sed -i -E "s/^\s*#\s*(${setting})(\s*(=|$))/${setting}\2/" "$config_file"
    done

    printf "%b\n" "Setup completed successfully!"

}

main
