#!/usr/bin/env bash

# menu: System Cleanup
# desc: Remove orphans and clear package caches

. "$COMMON_SCRIPT"

set -euo pipefail

cleanup_system() {

    printf "%b\n" "Performing system cleanup..."

    case "$PACKAGER" in
    pacman)
        sudo "$PACKAGER" -Sc --noconfirm
        sudo "$PACKAGER" -Rns "$(pacman -Qtdq)" --noconfirm >/dev/null || true
        ;;
    *)
        printf "%b\n" "Unsupported package manager: ${PACKAGER}. Skipping."
        ;;
    esac
}

common_cleanup() {
    [ -d /var/tmp ] &&
        sudo find /var/tmp -type f -atime +5 -delete

    [ -d /tmp ] &&
        sudo find /tmp -type f -atime +5 -delete

    [ -d /var/log ] &&
        sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

    if [ "$INIT_MANAGER" = "systemctl" ]; then
        sudo journalctl --vacuum-time=3d
    fi
}

clean_data() {
    printf "%b" "Clean up old cache files and empty the trash? (y/N): "
    read -r clean_response
    case $clean_response in
    y | Y)
        printf "%b\n" "Cleaning up old cache files and emptying trash..."
        if [ -d "$HOME/.cache" ]; then
            find "$HOME/.cache/" -type f -atime +5 -delete
        fi
        if [ -d "$HOME/.local/share/Trash" ]; then
            find "$HOME/.local/share/Trash" -mindepth 1 -delete
        fi
        printf "%b\n" "Cache and trash cleanup completed."
        ;;
    *)
        printf "%b\n" "Skipping cache and trash cleanup."
        ;;
    esac
}

main() {
    cleanup_system
    common_cleanup
    clean_data
}

main
