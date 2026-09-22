#!/bin/sh -e

# menu: System Update
# desc: Update official, AUR and Flatpak packages

. "$COMMON_SCRIPT"

install_rate_mirrors() {
    if ! command_exists rate-mirrors; then
        install_packages --aur rate-mirrors-bin

    else
        printf "%b\n" "Rate Mirrors is already installed."
    fi
}

fast_update() {

    printf "%b\n" "Generating a new list of mirrors using rate-mirrors. This process may take a few seconds..."

    if [ -s "/etc/pacman.d/mirrorlist" ]; then
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    fi

    dtype_local="${DTYPE:-arch}"
    echo "Using rate-mirrors with distro: $dtype_local"

    if ! sudo rate-mirrors --top-mirrors-number-to-retest=5 --disable-comments --allow-root --save=/etc/pacman.d/mirrorlist "$dtype_local" --max-delay=21600 >/dev/null || [ ! -s "/etc/pacman.d/mirrorlist" ]; then
        printf "%b\n" "Rate-mirrors failed, restoring backup."
        sudo cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist

    fi

}

update_system() {
    printf "%b\n" "Updating system packages."
    case "$PACKAGER" in
    pacman)
        sudo "$PACKAGER" -Sy --noconfirm --needed archlinux-keyring
        "$HELPER" -Su --noconfirm
        ;;
    *)
        printf "%b\n" "Unsupported package manager: ${PACKAGER}"
        exit 1
        ;;
    esac
}

update_flatpaks() {
    if command_exists flatpak; then
        printf "%b\n" "Updating flatpak packages."
        flatpak update -y
    fi
}

check_aur_helper
install_rate_mirrors
fast_update
update_system
update_flatpaks
