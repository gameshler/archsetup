#!/usr/bin/env bash

command_exists() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

check_package_manager() {
    local managers=("$@")
    for pgm in "${managers[@]}"; do
        if command_exists "${pgm}"; then
            PACKAGER=${pgm}
            printf "%b\n" "Using ${pgm} as package manager"
            return
        fi
    done
    echo "No supported package manager found" >&2
    exit 1
}
check_aur_helper() {
    local helpers=("yay" "paru")

    for h in "${helpers[@]}"; do
        if command_exists "${h}"; then
            HELPER="${h}"
            printf "%b\n" "Using ${h} as Aur Helper"
            return
        fi
    done

    printf "%b\n" "No AUR helper found. Installing yay..."

    sudo "$PACKAGER" -S --needed --noconfirm base-devel git || exit 1
    mkdir -p "$HOME/opt" || exit 1
    cd "$HOME/opt" || exit 1

    if [[ ! -d yay-bin ]]; then
        git clone https://aur.archlinux.org/yay-bin.git || exit 1
    fi
    sudo chown -R "$USER":"$USER" ./yay-bin
    cd yay-bin || exit 1
    makepkg --noconfirm -si || exit 1

    if command_exists yay; then
        HELPER="yay"
        printf "%b\n" "$HELPER installed and set as AUR helper"
    else
        printf "%b\n" "Failed to install $HELPER" >&2
        exit 1
    fi

}

check_flatpak() {
    if ! command_exists flatpak; then
        printf "%b\n" "Installing Flatpak..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm flatpak
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
        printf "%b\n" "Adding Flathub remote..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        printf "%b\n" "Applications installed by Flatpak may not appear on your desktop until the user session is restarted..."
    else
        if ! flatpak remotes | grep -q "flathub"; then
            printf "%b\n" "Adding Flathub remote..."
            sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        else
            printf "%b\n" "Flatpak is installed"
        fi
    fi
}

install_packages() {
    local source=""

    # Detect if first arg is a source flag
    case "$1" in
    --official | --aur | --flatpak)
        source="$1"
        shift
        ;;
    esac

    # Default to official if not specified
    source="${source:---official}"

    case "$source" in
    --official)
        sudo pacman -S --needed --noconfirm "$@"
        ;;
    --aur)
        check_aur_helper
        "$HELPER" -S --needed --noconfirm "$@"
        ;;
    --flatpak)
        check_flatpak
        flatpak install -y flathub "$@"
        ;;
    *)
        printf "%b\n" "Unsupported package manager: ""$source"
        exit 1

        ;;
    esac
}

check_init_manager() {
    local candidates="$1"
    local manager

    for manager in $candidates; do
        if command_exists "$manager"; then
            INIT_MANAGER="$manager"
            printf "%b\n" "Using ${manager} to interact with init system"
            return 0
        fi
    done

    printf "%b\n" "No supported init system found. Exiting."
    exit 1
}

is_service_active() {
    case "$INIT_MANAGER" in
    systemctl)
        sudo "$INIT_MANAGER" is-active --quiet "$1"
        ;;
    rc-service)
        sudo "$INIT_MANAGER" "$1" status --quiet
        ;;
    sv)
        sudo "$INIT_MANAGER" status "$1" >/dev/null 2>&1
        ;;
    esac
}

# lib32-* packages live only in the multilib repository, which Arch ships
# disabled. Any tab that installs one has to turn it on first or pacman fails
# with "target not found". system/setup.sh enables it, but system/gpu-driver.sh
# can be run on its own long before setup.sh ever is.
enable_multilib() {
    if grep -qE '^\s*\[multilib\]' /etc/pacman.conf; then
        return 0
    fi

    printf "%b\n" "Enabling the multilib repository (needed for lib32-* packages)..."
    sudo sed -i -E '/^\s*#?\s*\[multilib\]/,/^\s*\[.*\]/ {
    s/^\s*#\s*(\[multilib\])/\1/
    s/^\s*#\s*(Include\s*=\s*\/etc\/pacman\.d\/mirrorlist)/\1/
}' /etc/pacman.conf

    sudo "$PACKAGER" -Sy --noconfirm
}

# The SSH port is asked for once and remembered here rather than hardcoded in
# core/main.sh, so the number is not published in this repo. It is stored under
# $HOME and not under INSTALL_DIR because core/main.sh deletes INSTALL_DIR when
# it exits cleanly; keeping it outside means security/ssh.sh, security/ufw.sh
# and security/nftables.sh read back the same value on a later run and can never
# disagree about which port is open.
SSH_PORT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/archsetup/ssh-port"

is_valid_port() {
    case "${1:-}" in
    "" | *[!0-9]*) return 1 ;;
    esac
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

save_ssh_port() {
    mkdir -p "$(dirname "$SSH_PORT_FILE")"
    printf '%s\n' "$1" >"$SSH_PORT_FILE"
}

# Prints nothing when there is no usable saved answer, so callers can test with
# [ -n ... ] and fall through to prompting.
read_saved_ssh_port() {
    local saved=""

    [ -r "$SSH_PORT_FILE" ] || return 0
    saved="$(tr -d '[:space:]' <"$SSH_PORT_FILE" 2>/dev/null || true)"
    is_valid_port "$saved" || return 0

    printf '%s' "$saved"
}

# Returns 1 when SSH_PORT is unset so callers can fall through. An explicit but
# invalid value is fatal rather than ignored: quietly substituting a different
# port is how sshd and the firewall end up disagreeing.
accept_env_ssh_port() {
    [ -n "${SSH_PORT:-}" ] || return 1

    if ! is_valid_port "$SSH_PORT"; then
        printf "%b\n" "SSH_PORT='$SSH_PORT' is not a number between 1 and 65535." >&2
        exit 1
    fi

    export SSH_PORT
    save_ssh_port "$SSH_PORT"
    printf "%b\n" "Using SSH port $SSH_PORT from the environment."
}

# Always asks, defaulting to whatever is already known so pressing Enter keeps
# it. security/ssh.sh uses this because it is the tab that decides the port.
prompt_ssh_port() {
    local current="" answer="" at_eof=0

    accept_env_ssh_port && return 0

    current="$(read_saved_ssh_port)"

    # Ask on the terminal even when the tab's stdin is redirected. Testing
    # [ -r /dev/tty ] is not enough: the node is readable but opening it fails
    # when there is no controlling terminal, which left the loop below spinning
    # on an empty answer forever. Open it for real, and fall back to stdin.
    if (: </dev/tty) 2>/dev/null; then
        exec 3</dev/tty
    else
        exec 3<&0
    fi

    printf "%b\n" "Choose the port the SSH server will listen on."
    printf "%b\n" "Anything other than 22 keeps it off the obvious scan target."

    while :; do
        if [ -n "$current" ]; then
            printf "%b" "SSH port [$current]: "
        else
            printf "%b" "SSH port (1-65535): "
        fi

        read -r answer <&3 || at_eof=1
        [ -n "$answer" ] || answer="$current"

        is_valid_port "$answer" && break

        # Nothing more is coming, so re-prompting would never terminate.
        if [ "$at_eof" -eq 1 ]; then
            exec 3<&-
            printf "%b\n" "No SSH port given and no terminal to ask on." >&2
            printf "%b\n" "Set it non-interactively instead: SSH_PORT=<port> $0" >&2
            exit 1
        fi

        printf "%b\n" "'$answer' is not a number between 1 and 65535."
    done

    exec 3<&-
    export SSH_PORT="$answer"
    save_ssh_port "$SSH_PORT"
}

# Never asks when the answer is already known. The firewall tabs use this so
# they open exactly the port security/ssh.sh configured.
resolve_ssh_port() {
    local saved=""

    accept_env_ssh_port && return 0

    saved="$(read_saved_ssh_port)"
    if [ -n "$saved" ]; then
        export SSH_PORT="$saved"
        printf "%b\n" "Using SSH port $SSH_PORT (remembered from $SSH_PORT_FILE)."
        return 0
    fi

    printf "%b\n" "No SSH port has been chosen yet."
    prompt_ssh_port
}

check_package_manager "pacman"
check_init_manager 'systemctl rc-service sv'
