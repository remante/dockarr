#!/usr/bin/env bash

# ── Colour definitions ─────────────────────────────────────
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# ── Helper functions ───────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; }

# ── Distribution‑specific installers ────────────────────────
install_debian_ubuntu() {
    info "Updating package index..."
    sudo apt-get update -y

    info "Installing prerequisite packages..."
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    info "Adding Docker’s official GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${DISTRO}/gpg |
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    info "Setting up the stable Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/${DISTRO} \
      $(lsb_release -cs) stable" |
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

install_fedora() {
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager \
        --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
}

install_opensuse() {
    sudo zypper refresh
    sudo zypper install -y docker docker-compose
    sudo systemctl enable --now docker
}

install_arch() {
    sudo pacman -Sy --noconfirm docker docker-compose
    sudo systemctl enable --now docker
}

# ── Pre‑flight: Docker & Docker‑Compose check ─────────────────
check_prereqs() {
    local missing=0

    # Docker binary
    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker engine is not installed."
        missing=$((missing+1))
    else
        info "Docker engine found: $(docker --version | head -n1)"
    fi

    # Docker Compose (v2 plugin, invoked as 'docker compose')
    if ! docker compose version >/dev/null 2>&1; then
        warn "Docker Compose (v2) is not installed."
        missing=$((missing+1))
    else
        info "Docker Compose found: $(docker compose version | head -n1)"
    fi

    if (( missing > 0 )); then
        echo ""
        read -rp "$(printf "${YELLOW}Do you want to install the missing component(s) now? (y/N) ${RESET}")" INSTALL_NOW
        if [[ ! "$INSTALL_NOW" =~ ^[Yy]$ ]]; then
            error "Missing dependencies – aborting installation."
            exit 1
        fi

        # ── Choose distribution ─────────────────────────────────────
        echo ""
        echo "Select your Linux distribution (enter the number):"
        echo "  1) Debian"
        echo "  2) Ubuntu"
        echo "  3) Fedora"
        echo "  4) openSUSE"
        echo "  5) Arch Linux"
        read -rp "$(printf "${BLUE}Your choice: ${RESET}")" DISTRO_CHOICE

        case "$DISTRO_CHOICE" in
            1) DISTRO="debian";  install_debian_ubuntu ;;
            2) DISTRO="ubuntu";  install_debian_ubuntu ;;
            3) DISTRO="fedora";  install_fedora ;;
            4) DISTRO="opensuse";install_opensuse ;;
            5) DISTRO="arch";    install_arch ;;
            *) error "Invalid selection – aborting."; exit 1 ;;
        esac

        # Verify installation succeeded
        if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
            success "All prerequisites are now installed."
        else
            error "Installation failed – please check the output above."
            exit 1
        fi
    fi

    # ── ALWAYS add the current user to the docker group ─────────────
    if groups "$USER" | grep -qw docker; then
        info "User '$USER' is already a member of the 'docker' group."
    else
        info "Adding user '$USER' to the 'docker' group..."
        sudo usermod -aG docker "$USER"
        if [[ $? -eq 0 ]]; then
            success "User added to the 'docker' group."
        else
            warn "Failed to add user to the 'docker' group. You may need to run the command manually."
        fi
    fi

    # Apply the new group membership for the *current* session.
    # We only re‑exec once – the environment variable prevents an infinite loop.
    if [[ -z "$LUMO_REEXECED" ]]; then
        info "Activating new group membership (newgrp docker)..."
        export LUMO_REEXECED=1
        exec newgrp docker "$0" "$@"
        # The script restarts here inside the new group; the lines below
        # are never executed in the original process.
    else
        success "Current session now has the 'docker' group membership."
    fi
}
# ----------------------------------------------------------------

# Run the pre‑flight check before anything else
check_prereqs "$@"

# ── Welcome banner ─────────────────────────────────────────
cat <<'EOF'
______           _                   
|  _  \         | |                  
| | | |___   ___| | ____ _ _ __ _ __ 
| | | / _ \ / __| |/ / _` | '__| '__|
| |/ / (_) | (__|   < (_| | |  | |   
|___/ \___/ \___|_|\_\__,_|_|  |_|   
                                        
EOF
echo -e "${MAGENTA}Welcome to the ARR‑suite Docker installer!${RESET}"
echo ""

# ── Gather user input ─────────────────────────────────────
read -rp "$(printf "${BLUE}Enter path for Radarr data${RESET} (e.g. /srv/media/radarr): ")" RADARR_PATH
read -rp "$(printf "${BLUE}Enter path for Sonarr data${RESET} (e.g. /srv/media/sonarr): ")" SONARR_PATH
read -rp "$(printf "${BLUE}Enter path for Bazarr data${RESET} (e.g. /srv/media/bazarr): ")" BAZARR_PATH
read -rp "$(printf "${BLUE}Enter path for Sabnzbd data${RESET} (e.g. /srv/media/sabnzbd): ")" SABNZBD_PATH
read -rp "$(printf "${BLUE}Enter path for qBittorrent data${RESET} (e.g. /srv/media/qbittorrent): ")" QB_PATH

echo ""
read -rp "$(printf "${MAGENTA}Enter your Tailscale auth‑key${RESET} (tskey‑auth‑…): ")" TS_AUTHKEY
read -rp "$(printf "${MAGENTA}Enter the IP of the Tailscale exit node${RESET} you wish to use: ")" TS_EXIT_NODE

# ── Confirm everything looks good ────────────────────────
echo ""
info "Please review the configuration:"
printf "  ${CYAN}Radarr   :${RESET} %s\n" "$RADARR_PATH"
printf "  ${CYAN}Sonarr   :${RESET} %s\n" "$SONARR_PATH"
printf "  ${CYAN}Bazarr   :${RESET} %s\n" "$BAZARR_PATH"
printf "  ${CYAN}Sabnzbd  :${RESET} %s\n" "$SABNZBD_PATH"
printf "  ${CYAN}qBittorrent:${RESET} %s\n" "$QB_PATH"
printf "  ${CYAN}Tailscale Auth Key:${RESET} %s\n" "$TS_AUTHKEY"
printf "  ${CYAN}Tailscale Exit Node IP:${RESET} %s\n" "$TS_EXIT_NODE"
echo ""

read -rp "$(printf "${YELLOW}Proceed with these settings? (y/N) ${RESET}")" PROCEED
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    error "Installation aborted by user."
    exit 1
fi

# ── Create required directories (needs sudo) ─────────────────
info "Creating directories (you may be asked for your sudo password)…"
declare -a DIRS=(
    "$RADARR_PATH"
    "$SONARR_PATH"
    "$BAZARR_PATH"
    "$SABNZBD_PATH"
    "$QB_PATH"
)

for d in "${DIRS[@]}"; do
    sudo mkdir -p "$d"
    sudo chown "$(id -u):$(id -g)" "$d"
done
success "All directories created."

# ── Write docker‑compose.yml ------------------------------------
COMPOSE_FILE="docker-compose.yml"
info "Generating ${COMPOSE_FILE} …"

cat > "$COMPOSE_FILE" <<EOF
services:
  radarr:
    container_name: radarr
    hostname: radarr.internal
    image: ghcr.io/hotio/radarr:latest
    restart: unless-stopped
    logging:
      driver: json-file
    ports:
      - 7878:7878
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Stockholm
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /docker/appdata/radarr:/config
      - ${RADARR_PATH}:/data

  sonarr:
    container_name: sonarr
    hostname: sonarr.internal
    image: ghcr.io/hotio/sonarr:latest
    restart: unless-stopped
    logging:
      driver: json-file
    ports:
      - 8989:8989
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Stockholm
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /docker/appdata/sonarr:/config
      - ${SONARR_PATH}:/data

  bazarr:
    container_name: bazarr
    hostname: bazarr.internal
    image: ghcr.io/hotio/bazarr:latest
    restart: unless-stopped
    logging:
      driver: json-file
    ports:
      - 6767:6767
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Stockholm
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /docker/appdata/bazarr:/config
      - ${BAZARR_PATH}/media:/data/media

  sabnzbd:
    container_name: sabnzbd
    hostname: sabnzbd.internal
    image: ghcr.io/hotio/sabnzbd:latest
    restart: unless-stopped
    logging:
      driver: json-file
    ports:
      - 8080:8080
      - 9090:9090
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Stockholm
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /docker/appdata/sabnzbd:/config
      - ${SABNZBD_PATH}/usenet:/data/usenet:rw

  prowlarr:
    container_name: prowlarr
    image: ghcr.io/hotio/prowlarr
    ports:
      - "9696:9696"
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=002
      - TZ=Europe/Stockholm
    volumes:
      - /config:/config

  qbittorrent:
    container_name: qbittorrent
    image: ghcr.io/hotio/qbittorrent
    network_mode: "service:tailscale"
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=002
      - TZ=Europe/Stockholm
      - WEBUI_PORTS=8585/tcp,8585/udp
      - LIBTORRENT=v1
    volumes:
      - /config:/config
      - ${QB_PATH}:/data
      - ${QB_PATH}/torrents:/data/torrents:rw

  tailscale:
    container_name: tailscale
    image: tailscale/tailscale:stable
    hostname: arr-suit-tail
    ports:
      - 8585:8585
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_USERSPACE=false
      - TS_ACCEPT_DNS=false
      - TS_EXTRA_ARGS=--accept-routes --exit-node="${TS_EXIT_NODE}" --advertise-tags=tag:container --exit-node-allow-lan-access=true --reset
      - TS_STATE_DIR=/var/lib/tailscale
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Stockholm
    volumes:
      - /tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - net_admin
      - sys_module
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=\${LOG_LEVEL:-info}
      - LOG_HTML=\${LOG_HTML:-false}
      - CAPTCHA_SOLVER=\${CAPTCHA_SOLVER:-none}
      - TZ=Europe/Stockholm
    ports:
      - "\${PORT:-8191}:8191"
    restart: unless-stopped
EOF

success "${COMPOSE_FILE} written."

# ── Final instructions -----------------------------------------
echo ""
info "Next steps:"
cat <<EOT
  1. Ensure Docker is running (e.g. \`sudo systemctl status docker\`).
  2. From the directory containing ${COMPOSE_FILE}, run:
        ${GREEN}docker compose up -d${RESET}
  3. Access the web UIs:
        • Radarr   – http://localhost:7878
        • Sonarr   – http://localhost:8989
        • Bazarr   – http://localhost:6767
        • Sabnzbd  – http://localhost:8080
        • qBittorrent – http://localhost:8585
        • Prowlarr – http://localhost:9696
        • FlareSolverr – http://localhost:8191
EOT

read -rp "$(printf "${YELLOW}Do you want me to start the stack now? (y/N) ${RESET}")" START_NOW
if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    info "Starting containers…"
    docker compose up -d
    if [[ $? -eq 0 ]]; then
        success "All services are up!"
    else
        error "Docker compose reported an error. Please check the output above."
    fi
else
    echo "You can start it later with: ${GREEN}docker compose up -d${RESET}"
fi

echo ""
success "${BOLD}Installation script finished.${RESET}"
