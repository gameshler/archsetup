#!/bin/sh -e

# menu: GitHub Desktop
# desc: GitHub Desktop Git client

. "$COMMON_SCRIPT"

install_github_desktop() {
    if ! command_exists github-desktop; then
        printf "%b\n" "Installing Github Desktop..."

        install_packages --aur github-desktop-bin
    else
        printf "%b\n" "Github Desktop is already installed."
    fi
}
install_github_desktop
