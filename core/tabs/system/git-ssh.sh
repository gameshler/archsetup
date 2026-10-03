#!/usr/bin/env bash

# menu: Git SSH Key
# desc: Create a GitHub SSH key and upload it

. "$COMMON_SCRIPT"

# `UseKeychain yes` in ~/.ssh/config and `ssh-add --apple-use-keychain` are
# deliberately absent: OpenSSH on Linux rejects both outright.

SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/id_ed25519"
PUB="$KEY.pub"
CONFIG="$SSH_DIR/config"

key_comment() {
    local email
    email="$(git config --get user.email 2>/dev/null)"

    if [ -n "$email" ]; then
        printf '%s' "$email"
        return 0
    fi

    printf '%s@%s' "$(whoami)" "$(hostnamectl --static 2>/dev/null || hostname -s)"
}

# Some networks block outbound 22. GitHub publishes ssh.github.com:443 for this,
# so detect it once and write the matching config block rather than leaving the
# user with a silent timeout.
port_22_reachable() {
    local out
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        -T git@github.com </dev/null 2>&1)"

    case "$out" in
    *"port 22: Connection refused"* | *"port 22: Connection timed out"* | \
        *"port 22: Operation timed out"* | *"port 22: Network is unreachable"*)
        return 1
        ;;
    esac

    return 0
}

ensure_key() {
    local comment

    if [ -e "$KEY" ] || [ -e "$PUB" ]; then
        printf "%b\n" "An ed25519 key already exists at $KEY; leaving it untouched."
        return 0
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    comment="$(key_comment)"
    printf "%b\n" "Generating an ed25519 key labelled $comment..."

    ssh-keygen -t ed25519 -C "$comment" -f "$KEY" || {
        printf "%b\n" "ssh-keygen failed; no key was written."
        return 1
    }
}

configure_ssh_client() {
    if [ -f "$CONFIG" ] && grep -qE '^[[:space:]]*Host[[:space:]]+.*\bgithub\.com\b' "$CONFIG"; then
        printf "%b\n" "$CONFIG already has a github.com entry; leaving it untouched."
        return 0
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    printf "%b\n" "Adding a github.com block to $CONFIG..."

    printf '\n' >>"$CONFIG"

    if port_22_reachable; then
        cat >>"$CONFIG" <<EOF
Host github.com
  User git
  AddKeysToAgent yes
  IdentityFile $KEY
EOF
    else
        printf "%b\n" "github.com:22 is blocked on this network; routing over ssh.github.com:443."
        cat >>"$CONFIG" <<EOF
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
  AddKeysToAgent yes
  IdentityFile $KEY
EOF
    fi

    chmod 600 "$CONFIG"
}

# An agent started with `eval "$(ssh-agent -s)"` dies when this script exits,
# so the key would have to be re-added in every new terminal. openssh ships an
# ssh-agent.service user unit for exactly this; files/.bashrc points
# SSH_AUTH_SOCK at its socket, so enabling it here makes the key persist.
enable_agent() {
    local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

    if systemctl --user enable --now ssh-agent.service 2>/dev/null; then
        export SSH_AUTH_SOCK="$sock"
        printf "%b\n" "ssh-agent.service enabled; the key stays loaded across terminals."
        return 0
    fi

    printf "%b\n" "No ssh-agent.service user unit available; starting a temporary agent."
    return 1
}

load_key() {
    local agent_status

    [ -f "$KEY" ] || return 1

    enable_agent || true

    ssh-add -l >/dev/null 2>&1
    agent_status=$?

    # 2 means "could not connect to the agent" — fall back to one for this run.
    if [ "$agent_status" -eq 2 ]; then
        printf "%b\n" "Starting ssh-agent..."
        eval "$(ssh-agent -s)" >/dev/null
    fi

    printf "%b\n" "Adding the key to the agent..."
    ssh-add "$KEY" || printf "%b\n" "ssh-add did not load the key."
}

ensure_gh() {
    if command_exists gh; then
        return 0
    fi

    printf "%b\n" "GitHub CLI is not installed; installing it..."
    install_packages github-cli || return 1
    command_exists gh
}

key_already_uploaded() {
    local material
    material="$(awk '{ print $2 }' "$PUB" 2>/dev/null)"
    [ -n "$material" ] || return 1

    gh api user/keys --jq '.[].key' 2>/dev/null |
        awk '{ print $2 }' |
        grep -qxF -- "$material"
}

# X11 (dwm) and Wayland need different clipboard tools; fall back to printing.
copy_to_clipboard() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command_exists wl-copy; then
        wl-copy <"$PUB" && return 0
    fi
    if [ -n "${DISPLAY:-}" ]; then
        command_exists xclip && xclip -selection clipboard <"$PUB" && return 0
        command_exists xsel && xsel --clipboard --input <"$PUB" && return 0
    fi
    return 1
}

manual_upload() {
    if copy_to_clipboard; then
        printf "%b\n" "The public key is on the clipboard. Paste it into the page opening now."
    else
        printf "%b\n" "Could not reach a clipboard. Copy the key below into https://github.com/settings/ssh/new:"
        cat "$PUB"
    fi

    if command_exists xdg-open; then
        xdg-open "https://github.com/settings/ssh/new" >/dev/null 2>&1 || true
    fi

    printf "%b\n" "GitHub accepts the key the moment you save it there."
    read -rp "  Press Enter once the key is saved on GitHub " || true
}

upload_key() {
    local title

    [ -f "$PUB" ] || {
        printf "%b\n" "No public key at $PUB; nothing to upload."
        return 1
    }

    if ! ensure_gh; then
        printf "%b\n" "GitHub CLI is not available, so the key cannot be uploaded here."
        manual_upload
        return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        printf "%b\n" "GitHub CLI is not logged in, so the key cannot be uploaded here."
        printf "%b\n" "Run \`gh auth login\` to do this automatically next time."
        manual_upload
        return 1
    fi

    if key_already_uploaded; then
        printf "%b\n" "This key is already on the GitHub account; not adding a duplicate."
        return 0
    fi

    title="$(hostnamectl --static 2>/dev/null || hostname -s) (archsetup)"
    printf "%b\n" "Uploading the public key as \"$title\"..."

    if gh ssh-key add "$PUB" --type authentication --title "$title"; then
        return 0
    fi

    printf "%b\n" "gh ssh-key add failed. It needs the admin:public_key scope:"
    printf "%b\n" "  gh auth refresh -h github.com -s admin:public_key"
    return 1
}

verify_github() {
    local out

    printf "%b\n" "Verifying authentication against GitHub..."

    out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        -T git@github.com </dev/null 2>&1)"

    case "$out" in
    *"successfully authenticated"*)
        printf "%b\n" "$out"
        printf "%b\n" "GitHub SSH authentication works."
        return 0
        ;;
    esac

    printf "%b\n" "Could not authenticate to GitHub:"
    printf "%b\n" "$out"
    return 1
}

git_ssh() {
    printf "%b\n" "Setting up the GitHub SSH key..."

    ensure_key || return 1
    configure_ssh_client
    load_key
    upload_key
    verify_github
}

git_ssh
