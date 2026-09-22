#!/bin/sh -e

# menu: SSH Server
# desc: Install and harden the OpenSSH server

. "$COMMON_SCRIPT"

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.archsetup.bak"
# Written by an older version of this script. Drop-ins are read from the
# Include line at the top of sshd_config and sshd keeps the FIRST value it
# sees, so a leftover copy would silently outrank everything set below.
LEGACY_DROPIN="/etc/ssh/sshd_config.d/20-archsetup.conf"

install_openssh() {
    # `command_exists ssh` only proved the client was present. The daemon is
    # what this script configures, and it is a separate binary.
    if command_exists sshd || [ -x /usr/bin/sshd ]; then
        printf "%b\n" "openssh is already installed."
    else
        printf "%b\n" "Installing OpenSSH..."
        install_packages openssh
    fi
}

generate_host_keys() {
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ] &&
        [ ! -f /etc/ssh/ssh_host_rsa_key ] &&
        [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
        printf "%b\n" "Generating SSH host keys..."
        sudo ssh-keygen -A
    fi
}

backup_config() {
    if [ ! -f "$BACKUP" ]; then
        printf "%b\n" "Backing up $SSHD_CONFIG to $BACKUP."
        sudo cp "$SSHD_CONFIG" "$BACKUP"
    fi

    if [ -f "$LEGACY_DROPIN" ]; then
        printf "%b\n" "Removing $LEGACY_DROPIN so it cannot override $SSHD_CONFIG."
        sudo rm -f "$LEGACY_DROPIN"
    fi
}

# Set a directive in the global section of sshd_config, in place.
#
# The existing line is rewritten rather than a new one appended, because sshd
# keeps the first value it sees for these keywords: a second copy at the bottom
# of the file would simply be ignored. Any later duplicate in the global section
# is commented out so the file says what sshd actually does.
#
# Everything from the first `Match` line onward is left alone. Directives there
# apply only to connections matching that block, so rewriting them would change
# a rule this script was never asked about.
set_directive() {
    key="$1"
    value="$2"
    tmp="$(mktemp)"

    awk -v key="$key" -v value="$value" '
        BEGIN {
            # sshd keyword matching is case-insensitive, so compare lowercased.
            keypat = "^[[:space:]]*#?[[:space:]]*" tolower(key) "([[:space:]]|$)"
            done = 0
            past_global = 0
        }
        !past_global && tolower($0) ~ /^[[:space:]]*match([[:space:]]|$)/ {
            if (!done) { print key " " value; done = 1 }
            past_global = 1
            print
            next
        }
        !past_global && tolower($0) ~ keypat {
            if (!done) {
                print key " " value
                done = 1
            } else {
                print "#" $0
            }
            next
        }
        { print }
        END { if (!done) print key " " value }
    ' "$SSHD_CONFIG" >"$tmp"

    sudo install -m 644 -o root -g root "$tmp" "$SSHD_CONFIG"
    rm -f "$tmp"
}

write_config() {
    printf "%b\n" "Applying hardening to $SSHD_CONFIG..."

    set_directive Port "$SSH_PORT"
    set_directive AddressFamily inet
    set_directive PermitRootLogin no
    set_directive PubkeyAuthentication yes
    set_directive PasswordAuthentication no
    set_directive PermitEmptyPasswords no
    # Not one of the six, but required for them to mean anything: with
    # KbdInteractiveAuthentication yes, PAM still offers a password prompt over
    # keyboard-interactive and PasswordAuthentication no is bypassed.
    set_directive KbdInteractiveAuthentication no
}

# Password logins are about to be disabled, which locks out every remote login
# until a key is in place. Offer to install one now rather than let that be
# discovered from the wrong side of the door.
#
# The key wanted here is the PUBLIC key of the machine you connect FROM. The
# key system/git-ssh.sh creates is for authenticating outward to GitHub and is
# not interchangeable with this one.
ensure_authorized_key() {
    authkeys="$HOME/.ssh/authorized_keys"

    if [ -s "$authkeys" ]; then
        printf "%b\n" "Found $(grep -c . "$authkeys") key(s) in $authkeys."
        return 0
    fi

    printf "%b\n" ""
    printf "%b\n" "$authkeys is missing or empty and password logins are about to go away."
    printf "%b\n" "Paste the public key of the machine you connect FROM - the contents of"
    printf "%b\n" "its ~/.ssh/id_ed25519.pub - or press Enter to skip."

    if (: </dev/tty) 2>/dev/null; then
        exec 3</dev/tty
    else
        exec 3<&0
    fi
    printf "%b" "Public key: "
    read -r pubkey <&3 || pubkey=""
    exec 3<&-

    [ -n "$pubkey" ] || return 1

    # Let ssh-keygen decide whether this is a key, rather than pattern-matching
    # the prefix: a truncated paste looks right and fails at login time.
    tmp="$(mktemp)"
    printf '%s\n' "$pubkey" >"$tmp"
    if ! ssh-keygen -l -f "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        printf "%b\n" "That is not a usable SSH public key. Skipping."
        return 1
    fi
    rm -f "$tmp"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    printf '%s\n' "$pubkey" >>"$authkeys"
    chmod 600 "$authkeys"
    printf "%b\n" "Installed the key in $authkeys."
}

# Reached only when no key could be installed. Said before the restart rather
# than after it, because after it there is no way back in over the network.
warn_no_key() {
    printf "%b\n" ""
    printf "%b\n" "WARNING: no key in $HOME/.ssh/authorized_keys."
    printf "%b\n" "Password logins are now off, so SSH will refuse every remote login."
    printf "%b\n" "The local console still works. To recover, either run this from a"
    printf "%b\n" "machine that can already reach this one:"
    printf "%b\n" "    ssh-copy-id -p $SSH_PORT $USER@<this-host>"
    printf "%b\n" "or undo the hardening at the console:"
    printf "%b\n" "    sudo cp $BACKUP $SSHD_CONFIG && sudo systemctl restart sshd"
    printf "%b\n" ""
}

# sshd -t only proves the file parses. This checks the values sshd will actually
# use, which is not the same thing: a drop-in from another package is read from
# the Include line at the top and would win over everything set above.
verify_config() {
    effective="$(sudo sshd -G 2>/dev/null)" || {
        printf "%b\n" "sshd -G unavailable; skipping the effective-value check."
        return 0
    }

    for pair in \
        "port $SSH_PORT" \
        "addressfamily inet" \
        "permitrootlogin no" \
        "pubkeyauthentication yes" \
        "passwordauthentication no" \
        "permitemptypasswords no" \
        "kbdinteractiveauthentication no"; do
        printf '%s\n' "$effective" | grep -qx "$pair" && continue

        keyword="${pair%% *}"
        actual="$(printf '%s\n' "$effective" | grep "^$keyword " || true)"
        [ -n "$actual" ] || actual="$keyword <unset>"

        printf "%b\n" "Warning: requested '$pair' but sshd reports '$actual'."
        printf "%b\n" "         Check /etc/ssh/sshd_config.d/ for an override."
    done
}

apply_config() {
    if ! sudo sshd -t; then
        printf "%b\n" "sshd rejected the configuration. Restoring $BACKUP and leaving sshd as it was."
        sudo cp "$BACKUP" "$SSHD_CONFIG"
        exit 1
    fi

    verify_config

    [ "$KEY_INSTALLED" -eq 1 ] || warn_no_key

    # The old script only restarted sshd, so the hardening was gone after a
    # reboot unless the unit happened to be enabled already.
    sudo systemctl enable sshd.service
    sudo systemctl restart sshd.service

    printf "%b\n" "SSH server listening on port $SSH_PORT, passwords disabled."
    printf "%b\n" "Reach it with: ssh -p $SSH_PORT $USER@<this-host>"
    printf "%b\n" "Run the ufw or nftables tab to open it - they read the same port."
}

# This tab sets up the SSH *server*. Authenticating to GitHub is a different
# job, and conflating the two is why the key generated here never worked:
# nothing registered it with GitHub and the agent started here died with the
# script. The port chosen above does not affect GitHub either - that is an
# outbound connection to github.com:22, not a listener on this machine.
point_at_git_ssh() {
    printf "%b\n" "This tab configures the SSH server only."
    printf "%b\n" "For a GitHub key, run System > Git SSH Key."
}

install_openssh
generate_host_keys
prompt_ssh_port

KEY_INSTALLED=0
ensure_authorized_key && KEY_INSTALLED=1

backup_config
write_config
apply_config
point_at_git_ssh
