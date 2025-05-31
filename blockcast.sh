#!/bin/bash

BLOCKCAST_REPO="https://github.com/pramonoutomo/blockcast"
BLOCKCAST_DIR="blockcast"
BLOCKCAST_ACCOUNT="https://app.blockcast.network?referral-code=xTCw3m"
REQUIRED_TOOLS="git jq curl docker awk"

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAGENTA='\033[0;35m'


print_banner() {
  echo -e "${C_CYAN}"
  echo "======================================================"
  echo "        WINGFO Blockcast Node Auto-Installer          "
  echo "======================================================"
  echo -e "${C_RESET}"
}

info() {
  echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

success() {
  echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

warn() {
  echo -e "${C_YELLOW}[WARN]${C_RESET} $1"
}

error_exit() {
  echo -e "${C_RED}[ERROR]${C_RESET} $1"
  exit 1
}

prompt_continue() {
  echo -e "${C_MAGENTA}"
  read -p "[PROMPT] Press [Enter] to continue after you have completed the step above..."
  echo -e "${C_RESET}"
}


check_command() {
  command -v "$1" >/dev/null 2>&1
}

install_package() {
  PACKAGE_NAME=$1
  info "Attempting to install $PACKAGE_NAME..."
  if sudo apt-get install -y "$PACKAGE_NAME" >/dev/null 2>&1; then
    success "$PACKAGE_NAME installed successfully."
  else
    error_exit "Failed to install $PACKAGE_NAME. Please install it manually and re-run the script."
  fi
}

print_banner
echo ""

info "--- Checking Prerequisites ---"
for tool in $REQUIRED_TOOLS; do
  if [[ "$tool" == "docker" ]]; then
    continue
  fi
  if ! check_command "$tool"; then
    warn "$tool is not installed."
    if [[ "$tool" == "awk" ]]; then
        warn "Essential tool $tool is missing. Attempting to install."
        install_package "$tool"
    else
        echo -e "${C_YELLOW}[PROMPT]${C_RESET} Do you want to install $tool? (y/n): \c"
        read -r INSTALL_CONFIRM
        if [[ "$INSTALL_CONFIRM" == "y" || "$INSTALL_CONFIRM" == "Y" ]]; then
          install_package "$tool"
        else
          error_exit "$tool is required. Exiting."
        fi
    fi
  else
    info "$tool is already installed."
  fi
done
success "Prerequisite tools check complete."
echo ""

info "--- Updating Packages and Installing System Dependencies ---"
info "Updating package lists..."
sudo apt-get update >/dev/null 2>&1 || warn "apt-get update encountered some issues, but proceeding."

info "Upgrading existing packages (this may take a while)..."
sudo apt-get upgrade -y >/dev/null 2>&1 || warn "apt-get upgrade encountered some issues, but proceeding."
success "Packages updated and upgraded."

info "Installing core system dependencies..."
if sudo apt install -y iptables build-essential wget lz4 make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev >/dev/null 2>&1; then
  success "Core system dependencies installed."
else
  warn "Some system dependencies might have failed to install. Check logs if issues arise."
fi
echo ""

info "--- Docker Installation & Setup ---"
DOCKER_INSTALLED=false
if check_command docker; then
  if sudo docker ps > /dev/null 2>&1; then
    success "Docker is already installed and accessible."
    DOCKER_INSTALLED=true
  else
    warn "Docker command exists but 'docker ps' failed. Attempting to start/enable service..."
    sudo systemctl start docker &>/dev/null
    sudo systemctl enable docker &>/dev/null
    if sudo docker ps > /dev/null 2>&1; then
        success "Docker service started successfully."
        DOCKER_INSTALLED=true
    else
        warn "Still unable to run 'docker ps'. Proceeding with potential re-installation."
    fi
  fi
else
  info "Docker is not installed."
fi

if [ "$DOCKER_INSTALLED" = false ]; then
  info "Installing Docker..."
  warn "Removing any old/conflicting Docker packages..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg &>/dev/null; done

  info "Setting up Docker's APT repository..."
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get install -y ca-certificates gnupg >/dev/null 2>&1
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  info "Installing Docker CE, CLI, Containerd, and Docker Compose plugin..."
  sudo apt-get update >/dev/null 2>&1
  if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
    success "Docker components installed."
  else
    error_exit "Failed to install Docker components."
  fi

  info "Testing Docker installation with hello-world..."
  if sudo docker run hello-world | grep -q "Hello from Docker!"; then # Check for specific success string
    success "Docker installed and tested successfully."
  else
    error_exit "Docker installation test failed. Please check Docker installation manually."
  fi
  sudo systemctl enable docker >/dev/null 2>&1
  sudo systemctl restart docker >/dev/null 2>&1
  success "Docker service enabled and restarted."
else
  info "Skipping Docker installation as it's already set up."
fi

if ! groups $(whoami) | grep -q '\bdocker\b'; then
  info "Adding current user $(whoami) to the docker group..."
  sudo usermod -aG docker $(whoami)
  warn "You may need to log out and log back in for this group change to take full effect for non-sudo docker commands."
fi
echo ""

info "--- Setting up Blockcast (Node Services) ---"
info "Cloning or updating Blockcast repository from $BLOCKCAST_REPO..."
if [ -d "$BLOCKCAST_DIR" ]; then
  cd "$BLOCKCAST_DIR" || error_exit "Failed to cd into existing $BLOCKCAST_DIR directory."
  if git pull >/dev/null 2>&1; then
    success "Repository updated."
  else
    warn "git pull failed, repository might be in a detached state or offline. Continuing..."
  fi
  cd ..
else
  if git clone "$BLOCKCAST_REPO" "$BLOCKCAST_DIR" >/dev/null 2>&1; then
    success "Repository cloned successfully into $BLOCKCAST_DIR."
  else
    error_exit "Failed to clone Blockcast repository. Exiting."
  fi
fi

cd "$BLOCKCAST_DIR" || error_exit "Failed to cd into $BLOCKCAST_DIR."

info "Starting Blockcast services with Docker Compose..."
warn "Ensure port 18080 is not in use. If it is, services may fail to start."

DOCKER_COMPOSE_CMD="docker compose"
if ! $DOCKER_COMPOSE_CMD ps > /dev/null 2>&1 ; then
    if sudo $DOCKER_COMPOSE_CMD ps > /dev/null 2>&1 ; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    else
        error_exit "Cannot determine how to run docker-compose. Please check Docker permissions."
    fi
fi

if $DOCKER_COMPOSE_CMD up -d; then
  success "Blockcast services initiated with 'docker compose up -d'."
  info "Services might take a few moments to be fully operational."
else
  error_exit "Failed to start Blockcast services. Check logs with '$DOCKER_COMPOSE_CMD logs'."
fi
echo ""

info "--- Blockcast Account Registration/Login (MANDATORY) ---"
echo -e "${C_YELLOW}IMPORTANT:${C_RESET} You need a Blockcast account to register your node."
echo "If you don't have an account yet, please create one first."
echo ""
echo "Use the following link to register (or login if you already have an account):"
echo -e "${C_GREEN}${BLOCKCAST_ACCOUNT}${C_RESET}"
echo ""
echo "1. Copy and open the link above in your browser."
echo "2. Create a new Blockcast account OR login to your existing account."
echo "3. Ensure you are logged into the Blockcast dashboard in your browser and connect your solana wallet before proceeding."
echo ""
prompt_continue
echo ""


info "--- Node Initialization & Registration Info ---"
info "Fetching your public IP and location information..."
LOCATION_DATA_JSON=$(curl -s https://ipinfo.io)
CITY="<your_city>"
REGION="<your_region>"
COUNTRY="<your_country_code>"
LOC="<latitude,longitude>"

if [ -n "$LOCATION_DATA_JSON" ]; then
    CITY=$(echo "$LOCATION_DATA_JSON" | jq -r '.city // "<your_city>"')
    REGION=$(echo "$LOCATION_DATA_JSON" | jq -r '.region // "<your_region>"')
    COUNTRY=$(echo "$LOCATION_DATA_JSON" | jq -r '.country // "<your_country_code>"')
    LOC=$(echo "$LOCATION_DATA_JSON" | jq -r '.loc // "<latitude,longitude>"')
    success "Location data fetched: City: $CITY, Region: $REGION, Country: $COUNTRY, Coords: $LOC"
else
    warn "Failed to fetch location data automatically. You'll need to find it manually."
fi
echo ""
info "Attempting to initialize the node and get the registration URL..."
info "Waiting for services to stabilize before running 'init' (10 seconds)..."
sleep 10

INIT_OUTPUT=$($DOCKER_COMPOSE_CMD exec blockcastd blockcastd init 2>&1)
REGISTRATION_URL=$(echo "$INIT_OUTPUT" | awk '/Register URL:/ {getline; print; exit}')
REGISTRATION_URL=$(echo "$REGISTRATION_URL" | xargs) # Trim whitespace

echo -e "${C_CYAN}======================================================${C_RESET}"
echo -e "${C_YELLOW}           ACTION REQUIRED: NODE REGISTRATION           ${C_RESET}"
echo -e "${C_CYAN}======================================================${C_RESET}"

if [ -n "$REGISTRATION_URL" ] && [[ "$REGISTRATION_URL" == http* ]]; then
  success "Registration URL successfully obtained!"
  echo ""
  echo -e "${C_GREEN}Your Node Registration URL:${C_RESET}"
  echo -e "${C_YELLOW}$REGISTRATION_URL${C_RESET}"
  echo ""
  echo -e "${C_BLUE}To complete node registration:${C_RESET}"
  echo "1. Copy the Node Registration URL above."
  echo "2. Paste it into your browser (ensure you are already logged into your Blockcast account)."
  echo "3. On the dashboard, use the following estimated location details (or more accurate data):"
  echo "   - City:         ${C_GREEN}$CITY${C_RESET}"
  echo "   - Region:       ${C_GREEN}$REGION${C_RESET}"
  echo "   - Country Code: ${C_GREEN}$COUNTRY${C_RESET}"
  echo "   - Coordinates:  ${C_GREEN}$LOC${C_RESET}"
  echo "4. Finalize the registration on the website."
else
  warn "Could not automatically extract the Node Registration URL using the precise method."
  info "Attempting generic extraction (may be less reliable)..."
  REGISTRATION_URL_GENERIC=$(echo "$INIT_OUTPUT" | grep -oE 'https?://[^[:space:]]+' | tail -n 1)
  if [ -n "$REGISTRATION_URL_GENERIC" ] && [[ "$REGISTRATION_URL_GENERIC" == http* ]]; then
    warn "Generic extraction found a possible URL:"
    echo -e "${C_YELLOW}$REGISTRATION_URL_GENERIC${C_RESET}"
    warn "Please verify if this is the correct registration URL from the full output below."
  else
    warn "Generic extraction also failed."
  fi
  echo ""
  error_exit "Please find the Node Registration URL manually from the full output below and proceed with registration.
Full output from 'blockcastd blockcastd init':
--------------------------------------------------
$INIT_OUTPUT
--------------------------------------------------"
fi
echo ""
info "After successful registration on the website, wait a few minutes for your node to appear online."
success "Blockcast installation script has completed its automated tasks."
echo -e "${C_CYAN}======================================================${C_RESET}"

cd .. >/dev/null 2>&1