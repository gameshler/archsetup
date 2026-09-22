#!/bin/sh -e

# menu: Thorium
# desc: Performance-tuned Chromium fork

. "$COMMON_SCRIPT"

install_thorium() {
    if ! command_exists thorium-browser; then
        printf "%b\n" "Installing Thorium..."

        install_packages --aur thorium-browser-bin
    else
        printf "%b\n" "Thorium Browser is already installed."
    fi
}
install_thorium
