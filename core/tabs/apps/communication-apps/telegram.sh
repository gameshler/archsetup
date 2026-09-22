#!/bin/sh -e

# menu: Telegram
# desc: Telegram desktop client

. "$COMMON_SCRIPT"

install_telegram() {
    if ! command_exists telegram-desktop; then
        printf "%b\n" "Installing Telegram..."

        install_packages telegram-desktop
    else
        printf "%b\n" "Telegram is already installed."
    fi
}
install_telegram
