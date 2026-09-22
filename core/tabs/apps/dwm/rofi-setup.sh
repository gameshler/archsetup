#!/bin/sh -e

# menu: Rofi
# desc: Rofi application launcher

. "$COMMON_SCRIPT"

install_rofi() {
    if ! command_exists rofi; then
        printf "%b\n" "Installing Rofi..."

        install_packages rofi
    else
        printf "%b\n" "Rofi is already installed."
    fi
}

setup_rofi_config() {
    printf "%b\n" "Copying Rofi configuration files..."
    if [ -d "$HOME/.config/rofi" ] && [ ! -d "$HOME/.config/rofi-bak" ]; then
        cp -r "$HOME/.config/rofi" "$HOME/.config/rofi-bak"
    fi

    mkdir -p "$HOME/.config/rofi"

    curl -sSLo "$HOME/.config/rofi/powermenu.sh" https://github.com/gameshler/dwm/raw/main/config/rofi/powermenu.sh
    chmod +x "$HOME/.config/rofi/powermenu.sh"
    curl -sSLo "$HOME/.config/rofi/repo-finder.sh" https://github.com/gameshler/dwm/raw/main/config/rofi/repo-finder.sh
    chmod +x "$HOME/.config/rofi/repo-finder.sh"
    curl -sSLo "$HOME/.config/rofi/bookmarksmenu.sh" https://github.com/gameshler/dwm/raw/main/config/rofi/bookmarksmenu.sh
    chmod +x "$HOME/.config/rofi/bookmarksmenu.sh"

    curl -sSLo "$HOME/.config/rofi/config.rasi" https://github.com/gameshler/dwm/raw/main/config/rofi/config.rasi
    mkdir -p "$HOME/.config/rofi/themes"
    curl -sSLo "$HOME/.config/rofi/themes/nord.rasi" https://github.com/gameshler/dwm/raw/main/config/rofi/themes/nord.rasi

}
install_rofi
setup_rofi_config
