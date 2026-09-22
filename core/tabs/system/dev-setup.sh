#!/usr/bin/env bash

# menu: Dev Environment
# desc: Node via nvm, Bun, Claude Code and Git dotfiles

. "$COMMON_SCRIPT"

export NVM_DIR="$HOME/.nvm"
export BUN_INSTALL="$HOME/.bun"

# nvm is a shell function, never a binary, so `command_exists nvm` is always
# false and the old guard reinstalled everything on every run. Test the files
# the installers actually drop instead.
nvm_installed() { [ -s "$NVM_DIR/nvm.sh" ]; }
bun_installed() { [ -x "$BUN_INSTALL/bin/bun" ] || command_exists bun; }
claude_installed() { [ -x "$HOME/.local/bin/claude" ] || command_exists claude; }

load_nvm() {
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

install_pkgs() {
    # PROFILE=/dev/null stops each installer editing ~/.bashrc. That file is a
    # symlink bash-setup.sh regenerates, so appended lines are discarded on the
    # next run - which is why nvm kept vanishing. files/.bashrc activates nvm,
    # bun and ~/.local/bin itself, so nothing here needs to touch it.
    if nvm_installed; then
        printf "%b\n" "nvm is already installed."
    else
        printf "%b\n" "Installing nvm..."
        NVM_VERSION="v0.40.7"
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" |
            PROFILE=/dev/null bash
    fi

    load_nvm

    if bun_installed; then
        printf "%b\n" "bun is already installed."
    else
        printf "%b\n" "Installing bun..."
        curl -fsSL https://bun.com/install | bash
    fi

    if claude_installed; then
        printf "%b\n" "Claude Code is already installed."
    else
        printf "%b\n" "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
    fi
}

install_node() {
    if ! command_exists nvm && ! nvm_installed; then
        printf "%b\n" "nvm is unavailable; skipping the Node.js install."
        return 1
    fi

    load_nvm

    printf "%b\n" "Installing Node.js v25 via nvm"
    nvm install 25
    nvm alias default 25
}

main() {
    install_pkgs
    install_packages --aur postman-bin
    install_node || true

    dotfiles=(.gitignore .gitconfig)

    for dotfile in "${dotfiles[@]}"; do
        src="$FILES/$dotfile"
        dest="$HOME/$dotfile"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            echo "Warning: $src not found, skipping."
        fi
    done

    printf "%b\n" "Open a new shell (or run 'exec bash') to pick up nvm, bun and claude."
}

main
