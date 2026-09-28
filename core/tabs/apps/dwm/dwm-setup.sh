#!/bin/sh -e

# menu: dwm
# desc: Build and install the dwm window manager

# core/main.sh launches tabs with `bash "$path"`, and that discards the -e in
# the shebang above - the flag only applies when the file is executed directly.
# Setting it here means a failed clone, build or install stops the tab either
# way, instead of running on and reporting success.
set -e

. "$COMMON_SCRIPT"

DWM_REPO="https://github.com/gameshler/dwm.git"
DWM_DIR="$HOME/.local/share/dwm"

check_preconditions() {
    # The repo's install target reads SUDO_USER to decide whose ~/.config and
    # ~/.local/bin to write to. Running the whole tab as root leaves that unset,
    # and every config lands in /root instead of the account that will use dwm.
    if [ "$(id -u)" -eq 0 ]; then
        printf "%b\n" "Run this tab as your normal user - it calls sudo itself." >&2
        exit 1
    fi
}

# Everything dwm itself, the keybindings in config.h and the bar actually call.
# The bar is a Quickshell config now, not polybar: quickshell renders it,
# xorg-xprop reads dwm's state, wmctrl handles tag and window clicks, and
# xdotool tracks the focused window. Dropping any of those leaves the bar either
# missing or unable to respond to a click.
setup_dwm() {
    install_packages \
        base-devel git \
        libx11 libxinerama libxft libxcb imlib2 \
        xorg-xprop xorg-xrandr xorg-xsetroot xorg-xset \
        quickshell wmctrl xdotool \
        ghostty rofi picom dunst feh flameshot dex mate-polkit \
        xdg-utils xdg-user-dirs xdg-desktop-portal-gtk \
        ttf-firacode-nerd noto-fonts-emoji \
        networkmanager network-manager-applet \
        bluez bluez-utils \
        pipewire pipewire-pulse pavucontrol \
        papirus-icon-theme \
        thunar thunar-archive-plugin tumbler gvfs xarchiver \
        xclip unzip nwg-look alsa-utils gnome-keyring flatpak \
        xscreensaver tldr tmux
}

make_dwm() {
    mkdir -p "$(dirname "$DWM_DIR")"

    if [ ! -d "$DWM_DIR" ]; then
        printf "%b\n" "dwm not found, cloning repository..."
        git clone "$DWM_REPO" "$DWM_DIR" || {
            printf "%b\n" "Failed to clone dwm." >&2
            exit 1
        }
    else
        printf "%b\n" "dwm directory already exists, updating..."
        git -C "$DWM_DIR" pull || {
            printf "%b\n" "Could not update $DWM_DIR." >&2
            printf "%b\n" "Resolve it by hand, then re-run this tab." >&2
            exit 1
        }
    fi

    # This tab used to run `sudo make clean install`, which built as root and
    # left the object files and the binary owned by root. An unprivileged build
    # then cannot overwrite them. Clearing as root once fixes an existing
    # install; from here the build runs as you and only the install step is
    # privileged, so nothing under $HOME ends up root-owned again.
    printf "%b\n" "Building dwm..."
    sudo make -C "$DWM_DIR" clean
    make -C "$DWM_DIR"

    # The install target copies into these but does not always create them, so
    # on a home directory that has neither yet the copy fails outright. Making
    # them here also keeps them owned by you rather than by root.
    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    # install places the binary, the man page and the desktop entry, and copies
    # config/* to ~/.config, scripts/* to ~/.local/bin and .xinitrc to $HOME.
    # Copying any of that again here would only risk the two going out of sync.
    printf "%b\n" "Installing dwm, configs and scripts..."
    sudo make -C "$DWM_DIR" install
}

configure_backgrounds() {
    BG_DIR="$HOME/Pictures/backgrounds"
    mkdir -p "$BG_DIR"

    # config.h autostarts feh against this directory. An empty backgrounds/
    # leaves the glob unexpanded and cp fails, which under -e would abort the
    # tab on its very last step; with no wallpapers feh simply has nothing to
    # show, so warn and carry on.
    if [ -z "$(ls -A "$DWM_DIR/backgrounds" 2>/dev/null)" ]; then
        printf "%b\n" "No wallpapers in $DWM_DIR/backgrounds - skipping."
        return 0
    fi

    cp -f "$DWM_DIR"/backgrounds/* "$BG_DIR/"
    printf "%b\n" "Wallpapers installed to $BG_DIR"
}

setup_display_manager() {
    printf "%b\n" "Setting up Xorg"
    install_packages xorg-xinit xorg-server

    currentdm="none"
    for dm in gdm sddm lightdm ly; do
        if command_exists "$dm" || is_service_active "$dm"; then
            currentdm="$dm"
            break
        fi
    done

    if [ "$currentdm" != "none" ]; then
        printf "%b\n" "Display manager already present: $currentdm"
        printf "%b\n" "Choose dwm at the login screen."
        return 0
    fi

    printf "%b\n" "No display manager found, installing sddm..."
    install_packages sddm

    # Enable before theming. The previous version called enableService here,
    # which is defined nowhere in this repo, so sddm was installed and never
    # enabled and the next boot came up on a TTY. Doing it first also means a
    # failing theme installer cannot cost you a working login screen.
    sudo systemctl enable sddm.service
    printf "%b\n" "sddm installed and enabled."

    # Third-party theme installer, fetched and executed at install time. It is
    # cosmetic, so a failure here is reported rather than fatal.
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"; then
        printf "%b\n" "sddm theme setup failed - sddm itself is installed and enabled." >&2
    fi
}

check_preconditions
setup_dwm
make_dwm
configure_backgrounds
setup_display_manager
