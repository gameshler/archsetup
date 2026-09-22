#!/bin/sh -e

# menu: Slack
# desc: Slack team messaging

. "$COMMON_SCRIPT"

install_slack() {
    if ! command_exists com.slack.Slack && ! command_exists slack; then
        printf "%b\n" "Installing Slack..."
        install_packages --aur slack-desktop || install_packages --flatpak com.slack.Slack
    else
        printf "%b\n" "Slack is already installed."
    fi
}
install_slack
