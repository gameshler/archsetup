#!/usr/bin/env bash

set -euo pipefail

REPO="gameshler/archsetup"
BRANCH="main"
# Assigned before export: `export TEMP_DIR=$(...)` takes the exit status of
# export, not of mktemp, so a failure here would sail past `set -e` and leave
# TEMP_DIR empty for every path below.
TEMP_DIR="$(mktemp -d -t archsetup-XXXXXX)"
export TEMP_DIR
export INSTALL_DIR="$HOME/Downloads/archsetup"

main() {

    if ! curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" |
        tar -xz -C "$TEMP_DIR"; then
        echo -e "Failed to download repository"
        exit 1
    fi

    EXTRACTED_DIR="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        echo -e "Extracted directory not found at $EXTRACTED_DIR"
        exit 1
    fi

    echo -e "Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"

    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +

    MAIN_SCRIPT="$INSTALL_DIR/core/main.sh"
    if [[ -f "$MAIN_SCRIPT" ]]; then
        "$MAIN_SCRIPT"
    else
        echo -e "Main script not found at $MAIN_SCRIPT"
        exit 1
    fi
}

main
