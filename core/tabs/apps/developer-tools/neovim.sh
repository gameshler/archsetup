#!/bin/sh -e

# menu: Neovim
# desc: Neovim editor and configuration

. "$COMMON_SCRIPT"

clone_neovim() {
    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    git clone https://github.com/gameshler/neovim.git "$TEMP_DIR/neovim"

}

install_neovim() {
    if ! command_exists nvim ripgrep git fzf lua; then
        printf "%b\n" "Installing Neovim..."

        install_packages neovim ripgrep fzf luarocks shellcheck git lua
    else
        printf "%b\n" "Neovim is already installed."
    fi
}

link_neovim_config() {
    printf "Linking Neovim Configuration Files..."
    mkdir -p "$HOME/.config/nvim"
    cp -r "$TEMP_DIR/neovim/lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/init.lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/lazy-lock.json" "$HOME/.config/nvim/"

}
install_neovim
clone_neovim
link_neovim_config
