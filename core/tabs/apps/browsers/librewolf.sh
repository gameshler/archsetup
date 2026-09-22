#!/bin/sh -e

# menu: LibreWolf
# desc: Privacy-hardened Firefox fork

. "$COMMON_SCRIPT"

install_librewolf() {
    if ! command_exists io.gitlab.librewolf-community && ! command_exists librewolf; then
        printf "%b\n" "Installing LibreWolf..."

        install_packages --aur librewolf
    else
        printf "%b\n" "LibreWolf Browser is already installed."
    fi
}
install_librewolf
