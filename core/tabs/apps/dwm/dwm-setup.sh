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

# Both of these read the kernel's view through /sys rather than asking a tool,
# because they have to answer before bluez or NetworkManager is installed.
#
# /sys/class/bluetooth and /sys/class/net exist whenever the subsystem is built
# into the kernel and are empty when no device is attached, so the test is for
# contents and not for the directory. An unmatched glob stays literal in POSIX
# sh, which is why each loop tests the entry with -e before believing it.
has_bluetooth_adapter() {
    for dev in /sys/class/bluetooth/*; do
        if [ -e "$dev" ]; then
            return 0
        fi
    done
    return 1
}

has_wifi_device() {
    for dev in /sys/class/net/*/wireless; do
        if [ -e "$dev" ]; then
            return 0
        fi
    done
    return 1
}

# Everything dwm itself, the keybindings in config.h and the bar actually call.
# The bar is a Quickshell config now, not polybar: quickshell renders it,
# xorg-xprop reads dwm's state, wmctrl handles tag and window clicks, and
# xdotool tracks the focused window. Dropping any of those leaves the bar either
# missing or unable to respond to a click.
# xorg-xrdb is the one whose absence is invisible. scripts/quickshell-launch.sh
# translates Xft.dpi into QT_FONT_DPI only when xrdb is on PATH, so without it a
# HiDPI screen scales dwm's font and rofi while the bar stays at 1x, and nothing
# reports why. inter-font is the bar's UI face and pacman-contrib provides
# checkupdates, which the update pill prefers over an offline `pacman -Qu`.
setup_dwm() {
    install_packages \
        base-devel git \
        libx11 libxinerama libxft libxcb imlib2 \
        xorg-xprop xorg-xrandr xorg-xsetroot xorg-xset xorg-xrdb \
        quickshell wmctrl xdotool \
        ghostty rofi picom dunst feh flameshot dex mate-polkit \
        xdg-utils xdg-user-dirs xdg-desktop-portal-gtk \
        ttf-firacode-nerd inter-font noto-fonts-emoji \
        networkmanager network-manager-applet \
        pipewire pipewire-pulse pavucontrol \
        papirus-icon-theme pacman-contrib \
        thunar thunar-archive-plugin tumbler gvfs xarchiver \
        xclip unzip nwg-look alsa-utils gnome-keyring flatpak \
        xscreensaver tldr tmux

    # NetworkManager stays in the list above unconditionally: it manages wired
    # connections as well as wireless, and the bar's pill reads `nmcli device`
    # either way, with an ethernet icon of its own. There is nothing in this tab
    # that only a wireless machine needs.
    # bluez is different. On a desktop with no adapter it is two dead packages
    # and a service with nothing to manage, so install it only when the kernel
    # reports an adapter.
    if has_bluetooth_adapter; then
        install_packages bluez bluez-utils
    else
        printf "%b\n" "No bluetooth adapter detected - skipping bluez."
        printf "%b\n" "If you add one later: sudo pacman -S --needed bluez bluez-utils"
    fi
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

    # The bar is a Quickshell config under config/quickshell/, and it exists
    # only on the dwm repo's default branch once the Quickshell work has landed
    # there. Installing a clone without it is worse than getting an old bar:
    # config.h sets usealtbar=1, so dwm draws no bar of its own, and autostart[]
    # starts nothing to take its place. The desktop comes up with no bar at all.
    # Refuse rather than hand back a bare screen and no clue why.
    if [ ! -f "$DWM_DIR/config/quickshell/shell.qml" ]; then
        printf "%b\n" "$DWM_DIR has no config/quickshell/ - this clone predates the bar." >&2
        printf "%b\n" "Installing it would leave you with no bar at all (config.h sets usealtbar=1)." >&2
        printf "%b\n" "Land the Quickshell branch on the dwm repo's default branch, then re-run." >&2
        exit 1
    fi

    # Only the install step is privileged. The clean is sudo because an earlier
    # root-owned build leaves objects an unprivileged make cannot overwrite.
    printf "%b\n" "Building dwm..."
    sudo make -C "$DWM_DIR" clean
    make -C "$DWM_DIR"

    # The install target copies into these but does not always create them, so
    # on a home directory that has neither yet the copy fails outright. Making
    # them here also keeps them owned by you rather than by root.
    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    # install places the binary, the man page and the desktop entry, and copies
    # config/* to ~/.config, scripts/* to ~/.local/bin, and both .xinitrc and
    # .xprofile to $HOME. Those last two are written only when absent, so an
    # .xprofile left over from another setup is kept as it is. Copying any of
    # this again here would only risk the two going out of sync.
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

# Installing bluez only puts it on disk. Arch enables nothing by preset, and on
# a machine that does have an adapter that is the difference between a working
# pill and one that never appears: with bluetooth.service stopped,
# `bluetoothctl show` prints no "Powered:" line, so BluetoothModel.qml reports
# available=false and the bar hides the pill outright. Correct behaviour, but
# indistinguishable from a bug.
enable_services() {
    if ! has_bluetooth_adapter; then
        printf "%b\n" "No bluetooth adapter - leaving bluetooth.service alone."
        printf "%b\n" "The bar hides its bluetooth pill when there is no adapter."
    elif is_service_active bluetooth; then
        printf "%b\n" "bluetooth.service is already running."
    else
        printf "%b\n" "Enabling bluetooth.service..."
        sudo systemctl enable --now bluetooth.service
    fi

    # NetworkManager is deliberately not enabled here. The bar's network pill
    # needs it, but a machine can just as legitimately be on systemd-networkd or
    # iwd, and starting NetworkManager alongside one of those breaks the stack
    # that was working. Report it and let the owner decide.
    if is_service_active NetworkManager; then
        if has_wifi_device; then
            printf "%b\n" "NetworkManager is running, with a wireless device present."
        else
            printf "%b\n" "NetworkManager is running. No wireless device, which is fine -"
            printf "%b\n" "the bar's network pill reads the wired connection and shows an"
            printf "%b\n" "ethernet icon."
        fi
    else
        printf "%b\n" "NetworkManager is not running - the bar's network pill will stay hidden." >&2
        printf "%b\n" "If nothing else manages this machine's network:" >&2
        printf "%b\n" "    sudo systemctl enable --now NetworkManager" >&2
    fi
}

# GTK applications are already dark at this point: make install placed
# ~/.config/gtk-3.0 and ~/.config/gtk-4.0, and GTK reads those directly because
# dwm runs no XSettings manager. libadwaita and Qt ask the desktop portal
# instead, and the portal's answers come out of dconf - these three keys.
# Without them those applications come up light against everything else.
configure_dark_mode() {
    if ! command_exists gsettings; then
        printf "%b\n" "gsettings not found - GTK4 and Qt applications may stay light." >&2
        return 0
    fi

    # Papirus, not Papirus-Dark: the Dark variant ships no application icons and
    # inherits breeze-dark, which would empty the bar's app dock and tray.
    portal_keys="
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
"

    printf "%b\n" "Setting the desktop portal to dark..."

    # gsettings needs a D-Bus session bus to commit to dconf, and this tab is
    # normally run from a TTY before any desktop session exists, where there is
    # none. dbus-run-session supplies a throwaway bus for the three writes; the
    # values still land in ~/.config/dconf/user and outlive it.
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        sh -c "$portal_keys"
    elif command_exists dbus-run-session; then
        dbus-run-session -- sh -c "$portal_keys"
    else
        printf "%b\n" "No session bus and no dbus-run-session - skipping dark mode." >&2
        return 0
    fi

    # gsettings exits 0 even when the dconf commit failed, so a `|| printf` on
    # the writes above can never fire. Reading one key back is the only honest
    # check that they took.
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" || scheme=""
    else
        scheme="$(dbus-run-session -- gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" || scheme=""
    fi

    case "$scheme" in
    *prefer-dark*) ;;
    *)
        printf "%b\n" "The portal colour scheme did not take - GTK4 and Qt apps may stay light." >&2
        ;;
    esac
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

    # Enabled before theming, so a failing theme installer cannot cost you a
    # working login screen.
    sudo systemctl enable sddm.service
    printf "%b\n" "sddm installed and enabled."

    # Third-party theme installer, fetched and executed at install time. It is
    # cosmetic, so a failure here is reported rather than fatal.
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"; then
        printf "%b\n" "sddm theme setup failed - sddm itself is installed and enabled." >&2
    fi
}

# Nothing creates ~/.Xresources - not this tab, and not the repo's own
# installer - and scripts/.xprofile merges it only when it is there. That single
# value is what scales dwm's font, rofi and the bar together, so a 4K screen
# comes up looking broken until it is set. Say so instead of leaving it to be
# discovered.
report_hidpi() {
    if [ -f "$HOME/.Xresources" ]; then
        return 0
    fi

    printf "%b\n" "No ~/.Xresources found. On a HiDPI screen, set the scale with:"
    printf "%b\n" "    echo 'Xft.dpi: 192' > ~/.Xresources"
    printf "%b\n" "192 is 2x and 144 is 1.5x. Leave it unset on a 1080p screen."
}

check_preconditions
setup_dwm
make_dwm
configure_backgrounds
enable_services
configure_dark_mode
setup_display_manager
report_hidpi
