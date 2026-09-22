#!/bin/sh -e

# menu: Zoom
# desc: Zoom video conferencing

. "$COMMON_SCRIPT"

install_zoom() {
    if ! command_exists us.zoom.Zoom && ! command_exists zoom; then
        printf "%b\n" "Installing Zoom..."
        install_packages --aur zoom || install_packages --flatpak us.zoom.Zoom
    else
        printf "%b\n" "Zoom is already installed."
    fi
}
install_zoom
