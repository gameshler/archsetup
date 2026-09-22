#!/bin/sh -e

# menu: Discord
# desc: Discord voice and text chat

. "$COMMON_SCRIPT"

install_discord() {
    if ! command_exists com.discordapp.Discord && ! command_exists discord; then
        printf "%b\n" "Installing Discord..."

        install_packages discord
    else
        printf "%b\n" "Discord is already installed."
    fi
}
install_discord
