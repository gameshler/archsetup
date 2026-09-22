#!/bin/sh

# menu: dwm
# desc: Build and install the dwm window manager

. "$COMMON_SCRIPT"

DWM_DIR="$HOME/.local/share/dwm"

setup_dwm() {
    install_packages \
        base-devel libx11 libxinerama libxft imlib2 libxcb git unzip flameshot nwg-look \
        feh mate-polkit alsa-utils ghostty rofi xclip xarchiver thunar tumbler tldr gvfs \
        thunar-archive-plugin dunst dex xscreensaver xorg-xprop xorg-xrandr xorg-xsetroot \
        xorg-xset polybar picom xdg-user-dirs xdg-desktop-portal-gtk pipewire pavucontrol \
        gnome-keyring flatpak networkmanager network-manager-applet noto-fonts-emoji pipewire-pulse tmux
}

make_dwm() {
    mkdir -p "$HOME/.local/share/"
    if [ ! -d "$DWM_DIR" ]; then
        printf "%b\n" "DWM not found, cloning repository..."
        git clone https://github.com/gameshler/dwm.git "$DWM_DIR" || {
            printf "%b\n" "Failed to clone dwm."
            exit 1
        }
    else
        printf "%b\n" "DWM directory already exists, updating.."
        git -C "$DWM_DIR" pull
    fi

    # An unchecked cd here used to leave the build - and every relative path
    # after it - running in whatever directory the tab happened to start in.
    cd "$DWM_DIR" || {
        printf "%b\n" "Could not enter $DWM_DIR."
        exit 1
    }
    sudo make clean install # Run make clean install
}

install_nerd_font() {
    # Check to see if the FiraCode Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="FiraCode Nerd Font"
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_INSTALLED=$(fc-list | grep -i "FiraCode")

    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "FiraCode Nerd-fonts are already installed."
        return 0
    fi

    printf "%b\n" "Installing FiraCode Nerd-fonts"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            printf "%b\n" "Failed to create directory: $FONT_DIR"
            return 1
        }
    fi
    printf "%b\n" "Installing font '$FONT_NAME'"
    # Change this URL to correspond with the correct font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_DIR="$HOME/.local/share/fonts"
    curl -sSLo "$TEMP_DIR"/"${FONT_NAME}".zip "$FONT_URL"
    unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
    mkdir -p "$FONT_DIR"/"$FONT_NAME"
    mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
    fc-cache -fv
    printf "%b\n" "'$FONT_NAME' installed successfully."
}

clone_config_folders() {
    # Ensure the target directory exists
    [ ! -d ~/.config ] && mkdir -p ~/.config
    [ ! -d ~/.local/bin ] && mkdir -p ~/.local/bin
    # Copy scripts to local bin
    cp -rf "$DWM_DIR/scripts/." "$HOME/.local/bin/"

    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    if [ -d "$DWM_DIR/config/polybar/fonts" ]; then
        cp -r "$DWM_DIR/config/polybar/fonts/"* "$FONT_DIR/"
        fc-cache -fv
        printf "%b\n" "Polybar icon fonts installed"
    fi

    # Absolute, not "config/*/": the relative glob only resolved because
    # make_dwm happened to leave the shell inside $DWM_DIR. If that cd had
    # failed the loop matched nothing, copied no configs, and said so for a
    # directory that does exist - which is why a second run appeared to fix it.
    for dir in "$DWM_DIR"/config/*/; do
        # Extract the directory name
        dir_name=$(basename "$dir")

        # Clone the directory to ~/.config/
        if [ -d "$dir" ]; then
            cp -r "$dir" ~/.config/
            printf "%b\n" "Cloned $dir_name to ~/.config/"
        else
            printf "%b\n" "Directory $dir_name does not exist, skipping"
        fi
    done
}

configure_backgrounds() {
    # Set the variable PIC_DIR which stores the path for images
    PIC_DIR="$HOME/Pictures"

    # Set the variable BG_DIR to the path where backgrounds will be stored
    BG_DIR="$PIC_DIR/backgrounds"
    mkdir -p "$PIC_DIR"
    mkdir -p "$BG_DIR"
    cp -r "$HOME/.local/share/dwm/backgrounds/"* "$BG_DIR/"

}

setup_display_manager() {
    printf "%b\n" "Setting up Xorg"
    install_packages xorg-xinit xorg-server
    printf "%b\n" "Xorg installed successfully"
    printf "%b\n" "Setting up Display Manager"
    currentdm="none"
    for dm in gdm sddm lightdm; do
        if command_exists "$dm" || is_service_active "$dm"; then
            currentdm="$dm"
            break
        fi
    done
    printf "%b\n" "Display Manager Setup: $currentdm"
    if [ "$currentdm" = "none" ]; then
        printf "%b\n" "--------------------------"
        DM="sddm"
        install_packages "$DM"
        if [ "$DM" = "lightdm" ]; then
            install_packages lightdm-gtk-greeter
        elif [ "$DM" = "sddm" ]; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
        fi
        printf "%b\n" "$DM installed successfully"
        enableService "$DM"

    fi
}

setup_display_manager
setup_dwm
make_dwm
install_nerd_font
clone_config_folders
configure_backgrounds
