#!/bin/sh -e

# menu: Virtualisation
# desc: QEMU, libvirt and virt-manager

. "$COMMON_SCRIPT"

check_kvm() {
    if [ ! -e "/dev/kvm" ]; then
        printf "%b\n" "KVM is not available. Make sure you have CPU virtualization support enabled in your BIOS/UEFI settings. Please refer https://wiki.archlinux.org/title/KVM for more information."
    else
        sudo usermod "$USER" -aG kvm
    fi
}

install_qemu_desktop() {
    if ! command_exists qemu-img; then
        printf "%b\n" "Installing QEMU."
        install_packages qemu-desktop
    else
        printf "%b\n" "QEMU is already installed."
    fi
    check_kvm
}

install_qemu_emulators() {
    if ! "$PACKAGER" -Q | grep -q "qemu-emulators-full "; then
        printf "%b\n" "Installing QEMU-Emulators."
        install_packages qemu-emulators-full swtpm
    else
        printf "%b\n" "QEMU-Emulators already installed."
    fi
}

install_virt_manager() {
    if ! command_exists virt-manager; then
        printf "%b\n" "Installing Virt-Manager."
        install_packages virt-manager
    else
        printf "%b\n" "Virt-Manager already installed."
    fi
}

setup_libvirt() {
    printf "%b\n" "Configuring Libvirt."

    install_packages dnsmasq
    sudo sed -i 's/^#\?firewall_backend\s*=\s*".*"/firewall_backend = "nftables"/' "/etc/libvirt/network.conf"

    if systemctl is-active --quiet polkit; then
        sudo sed -i 's/^#\?auth_unix_ro\s*=\s*".*"/auth_unix_ro = "polkit"/' "/etc/libvirt/libvirtd.conf"
        sudo sed -i 's/^#\?auth_unix_rw\s*=\s*".*"/auth_unix_rw = "polkit"/' "/etc/libvirt/libvirtd.conf"
    fi

    sudo usermod "$USER" -aG libvirt

    for value in libvirt libvirt_guest; do
        if ! grep -wq "$value" /etc/nsswitch.conf; then
            sudo sed -i "/^hosts:/ s/$/ ${value}/" /etc/nsswitch.conf
        fi
    done

    sudo sed -i -E \
        -e 's/^(\s*)#\s*(unix_sock_group = "libvirt")/\1\2/' \
        -e 's/^(\s*)#\s*(unix_sock_rw_perms = "0770")/\1\2/' \
        /etc/libvirt/libvirtd.conf

    sudo systemctl enable --now libvirtd.service
    sudo virsh net-autostart default
    check_kvm
}

install_libvirt() {
    if ! command_exists libvirtd; then
        printf "%b\n" "Installing Libvirt..."

        install_packages libvirt dmidecode
    else
        printf "%b\n" "Libvirt is already installed."
    fi
    setup_libvirt
}

main() {
    printf "%b\n" "Choose what to install:"
    printf "%b\n" "1. QEMU"
    printf "%b\n" "2. QEMU-Emulators ( Extended architectures )"
    printf "%b\n" "3. Libvirt"
    printf "%b\n" "4. Virtual-Manager"
    printf "%b\n" "5. All"
    printf "%b" "Enter your choice [1-5]: "
    read -r CHOICE
    case "$CHOICE" in
    1) install_qemu_desktop ;;
    2) install_qemu_emulators ;;
    3) install_libvirt ;;
    4) install_virt_manager ;;
    5)
        install_qemu_desktop
        install_qemu_emulators
        install_libvirt
        install_virt_manager

        ;;
    *) printf "%b\n" "Invalid choice." && exit 1 ;;
    esac
}

main
