#!/bin/sh -e

. "$COMMON_SCRIPT"

install_lact() {
    if ! command_exists lact; then
        install_packages lact
        sudo systemctl enable --now lactd
    else
        printf "%b\n" "LACT is already installed."
    fi
}

detect_gpu() {
    gpu_lines=$(lspci | grep -Ei 'VGA|3D|Display' || true)

    if echo "$gpu_lines" | grep -qi nvidia; then
        gpu_vendor="nvidia"
    elif echo "$gpu_lines" | grep -Eqi 'amd|ati|advanced micro devices'; then
        gpu_vendor="amd"
    elif echo "$gpu_lines" | grep -qi intel; then
        gpu_vendor="intel"
    elif echo "$gpu_lines" | grep -Eqi 'intel|intel corporation|UHD'; then
        gpu_vendor="intel-uhd"
    else
        echo "Unsupported GPU:"
        echo "$gpu_lines"
        exit 1
    fi

    echo "Detected GPU: $gpu_vendor"

}

install_gpu_drivers() {

    printf "%b\n" "Installing GPU Drivers $gpu_vendor"
    case "$gpu_vendor" in
    nvidia)
        echo "Installing NVIDIA drivers"
        install_packages nvidia-dkms nvidia-utils nvidia-settings cuda
        ;;
    amd)
        echo "Installing AMD drivers"
        install_packages mesa vulkan-radeon libva-mesa-driver
        ;;
    intel)
        echo "Installing Intel drivers"
        install_packages mesa vulkan-intel intel-media-driver
        ;;
    intel-uhd)
        echo "Installing Intel UHD drivers"
        install_packages libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
        ;;
    esac
}

detect_gpu
install_gpu_drivers
install_lact
