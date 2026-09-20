#!/bin/sh -e

. "$COMMON_SCRIPT"

install_openssh() {
    if ! command_exists ssh; then
        printf "%b\n" "Installing OpenSSH..."

        install_packages openssh
    else
        printf "%b\n" "openssh is already installed."
    fi
}

generate_ssh_key() {

    if [ ! -f /etc/ssh/ssh_host_ed25519_key ] &&
        [ ! -f /etc/ssh/ssh_host_rsa_key ] &&
        [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
        echo "Generating SSH host keys..."
        sudo ssh-keygen -A # generates all default host keys
    fi

    if [ ! -f ~/.ssh/id_ed25519 ]; then
        printf "%b\n" "SSH key not found, generating one..."

        ssh-keygen -t ed25519 -C "$(whoami)@$HOSTNAME"
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519

    else
        printf "%b\n" "SSH key already exists."
    fi
}

configure_ssh() {
    printf "%b\\n" "Configuring SSH server..."

    # Port
    sudo sed -i "s/^#*Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config ||
        echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # AddressFamily inet
    sudo sed -i 's/^#*AddressFamily.*/AddressFamily inet/' /etc/ssh/sshd_config ||
        echo "AddressFamily inet" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PermitRootLogin no
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config ||
        echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PubkeyAuthentication yes
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config ||
        echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PasswordAuthentication no
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config ||
        echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PermitEmptyPasswords no
    sudo sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config ||
        echo "PermitEmptyPasswords no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # Test and restart
    sudo sshd -t && sudo systemctl restart sshd || {
        exit 1
    }
    printf "%b\\n" "SSH configured successfully."
}
install_openssh
generate_ssh_key
configure_ssh
