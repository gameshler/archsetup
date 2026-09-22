#!/bin/sh -e

# menu: Firefox
# desc: Mozilla Firefox web browser

. "$COMMON_SCRIPT"

install_firefox() {
    if ! command_exists firefox; then
        printf "%b\n" "Installing Firefox..."

        install_packages firefox
    else
        printf "%b\n" "Firefox Browser is already installed."
    fi
}
install_firefox
