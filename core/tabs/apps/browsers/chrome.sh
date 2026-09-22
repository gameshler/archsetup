#!/bin/sh -e

# menu: Google Chrome
# desc: Google Chrome web browser

. "$COMMON_SCRIPT"

install_chrome() {
    if ! command_exists google-chrome; then
        printf "%b\n" "Installing Chrome..."

        install_packages --aur google-chrome
    else
        printf "%b\n" "Google Chrome Browser is already installed."
    fi
}
install_chrome
