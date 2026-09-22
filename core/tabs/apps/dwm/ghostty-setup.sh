#!/bin/sh -e

# menu: Ghostty
# desc: Ghostty terminal emulator

. "$COMMON_SCRIPT"

install_ghostty() {
    if ! command_exists ghostty; then
        printf "%b\n" "Installing Ghostty..."

        install_packages ghostty
    else
        printf "%b\n" "Ghostty is already installed."
    fi
}

setup_ghostty_config() {
    printf "%b\n" "Copying ghostty config files..."
    if [ -d "${HOME}/.config/ghostty" ] && [ ! -d "${HOME}/.config/ghostty-bak" ]; then
        cp -r "${HOME}/.config/ghostty" "${HOME}/.config/ghostty-bak"
    fi
    mkdir -p "${HOME}/.config/ghostty/"
    curl -sSLo "${HOME}/.config/ghostty/config" "https://raw.githubusercontent.com/gameshler/dwm/main/config/ghostty/config"
    printf "%b\n" "Ghostty configuration files copied."
}
install_ghostty
setup_ghostty_config
