#!/bin/sh -e

# menu: Docker
# desc: Docker engine, compose and the docker group

. "$COMMON_SCRIPT"

choose_installation() {
    printf "%b\n" "Choose what to install:"
    printf "%b\n" "1. Docker"
    printf "%b\n" "2. Docker Compose"
    printf "%b\n" "3. Both"
    printf "%b" "Enter your choice [1-3]: "
    read -r CHOICE

    case "$CHOICE" in
    1)
        INSTALL_DOCKER=1
        INSTALL_COMPOSE=0
        ;;
    2)
        INSTALL_DOCKER=0
        INSTALL_COMPOSE=1
        ;;
    3)
        INSTALL_DOCKER=1
        INSTALL_COMPOSE=1
        ;;
    *)
        printf "%b\n" "Invalid choice. Exiting."
        exit 1
        ;;
    esac
}

install_docker() {
    printf "%b\n" "Installing Docker..."
    install_packages docker
    sudo systemctl enable docker
}

install_docker_compose() {
    printf "%b\n" "Installing Docker Compose..."
    install_packages docker-compose
}

install_components() {
    choose_installation

    if [ "$INSTALL_DOCKER" -eq 1 ]; then
        if ! command_exists docker; then
            install_docker
        else
            printf "%b\n" "Docker is already installed."
        fi
    fi

    if [ "$INSTALL_COMPOSE" -eq 1 ]; then
        if ! command_exists docker-compose || ! command_exists docker compose version; then
            install_docker_compose
        else
            printf "%b\n" "Docker Compose is already installed."
        fi
    fi
}

docker_permission() {
    printf "%b\n" "Adding current user to the docker group..."
    sudo usermod -aG docker "$USER"
    printf "%b\n" "To use Docker without sudo:"
    printf "%b\n" "Log out and back in, run 'newgrp docker', or restart your terminal."
    printf "%b\n" "Current user added to the docker group successfully."
}

install_components
docker_permission
