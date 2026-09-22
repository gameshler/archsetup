#!/bin/sh -e

# menu: GPU Drivers
# desc: Detect the GPU and install matching drivers

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
    # The word boundaries are load-bearing. Bare 'ati' matched the "ati" inside
    # "VGA compatible controller", which appears in every lspci display line,
    # so every non-NVIDIA GPU was detected as AMD and Intel machines were sent
    # AMD drivers. \bati\b does not match "compatible" but does match "[AMD/ATI]".
    elif echo "$gpu_lines" | grep -Eqi '\bamd\b|\bati\b|advanced micro devices'; then
        gpu_vendor="amd"
    # UHD has to be tested before the plain Intel match. A real device reports
    # "Intel Corporation UHD Graphics", which satisfies both, so with Intel
    # checked first this branch was unreachable for every card it was written
    # for and UHD machines silently took the generic Intel path.
    elif echo "$gpu_lines" | grep -qi uhd; then
        gpu_vendor="intel-uhd"
    elif echo "$gpu_lines" | grep -qi intel; then
        gpu_vendor="intel"
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
        # lib32-vulkan-intel and lib32-mesa are multilib-only, and this tab can
        # run before system/setup.sh has enabled that repository.
        enable_multilib
        # libva-intel-driver was listed twice in this line.
        install_packages libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
        ;;
    esac
}

detect_gpu
install_gpu_drivers
install_lact
