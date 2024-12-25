#!/bin/bash

# Monero P2Pool CPU Mining Setup Script
# For Ubuntu/Debian Systems
# Sets up Monero Node, P2Pool, and XMRig CPU Miner

# Function to get latest release version from GitHub
get_latest_p2pool_version() {
    local latest_version
    latest_version=$(curl -sL "https://api.github.com/repos/SChernykh/p2pool/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)
    if [ -n "$latest_version" ]; then
        echo "$latest_version"
    else
        error "Failed to get latest P2Pool version"
    fi
}

# Function to get latest XMRig version
get_latest_xmrig_version() {
    local latest_version
    latest_version=$(curl -sL "https://api.github.com/repos/xmrig/xmrig/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)
    if [ -n "$latest_version" ]; then
        echo "$latest_version"
    else
        error "Failed to get latest XMRig version"
    fi
}

# Function to get latest Monero version
get_latest_monero_version() {
    local latest_version
    latest_version=$(curl -sL "https://api.github.com/repos/monero-project/monero/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)
    if [ -n "$latest_version" ]; then
        echo "$latest_version"
    else
        error "Failed to get latest Monero version"
    fi
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
MONERO_VERSION=$(get_latest_monero_version)
P2POOL_VERSION=$(get_latest_p2pool_version)
XMRIG_VERSION=$(get_latest_xmrig_version)

# Directory structure
BASE_DIR="$HOME/monero-project"
MONERO_DIR="$BASE_DIR/monero"
P2POOL_DIR="$BASE_DIR/p2pool"
XMRIG_DIR="$BASE_DIR/xmrig"

# Port configurations
MONERO_P2P_PORT="18080"
MONERO_ZMQ_PORT="18083"
P2POOL_PORT="37889"
P2POOL_MINI_PORT="37888"
MINING_PORT="3333"

# User input variables
WALLET_ADDRESS=""
USE_P2POOL_MINI=""
START_SERVICES=""
CPU_THREADS=""

collect_user_inputs() {
    echo -e "${BLUE}===== Monero P2Pool Mining Setup =====${NC}"
    
    # Check for existing wallet address in environment file
    ENV_FILE="$HOME/.monero_environment"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi

    # Get wallet address
    if [ ! -z "$THIS_WALLET_ADDRESS" ]; then
        echo -e "Found existing wallet address: ${GREEN}${THIS_WALLET_ADDRESS}${NC}"
        read -p "Do you want to use this address? [y/n]: " USE_EXISTING
        if [[ $USE_EXISTING =~ ^[Yy]$ ]]; then
            WALLET_ADDRESS=$THIS_WALLET_ADDRESS
        fi
    fi

    # If no existing address or user wants a new one
    if [ -z "$WALLET_ADDRESS" ]; then
        while true; do
            read -p "Enter your Monero wallet address (starts with 4): " WALLET_ADDRESS
            if [[ $WALLET_ADDRESS =~ ^4[0-9A-Za-z]{94}$ ]]; then
                # Save the wallet address to environment file
                echo "THIS_WALLET_ADDRESS=$WALLET_ADDRESS" > "$ENV_FILE"
                break
            else
                echo -e "${RED}Invalid Monero address format. Please try again.${NC}"
            fi
        done
    fi

    # Rest of the existing collect_user_inputs function...
    read -p "Use P2Pool mini chain? (Recommended for hashrates < 50 kH/s) [y/n]: " USE_P2POOL_MINI
    
    echo -e "${YELLOW}Detecting CPU configuration...${NC}"
    AVAILABLE_THREADS=$(nproc)
    echo "Available CPU threads: $AVAILABLE_THREADS"
    read -p "How many CPU threads to use for mining? (1-$AVAILABLE_THREADS, recommended: $(($AVAILABLE_THREADS-1))): " CPU_THREADS
    
    read -p "Start mining services after installation? [y/n]: " START_SERVICES
}

# Function to install the script system-wide
install() {
    echo
    echo -e "${GREEN}Installing Monero P2Pool Mining Script...${NC}"
    
    # Check if running with sudo privileges
    if sudo -v; then
        # Copy script to /usr/local/bin
        sudo cp "$0" /usr/local/bin/monerominer
        sudo chown root:root /usr/local/bin/monerominer
        sudo chmod 755 /usr/local/bin/monerominer

        # Create configuration directory
        sudo mkdir -p /etc/monerominer
        
        # Create data directory
        sudo mkdir -p /var/lib/monerominer
        sudo chown -R $USER:$USER /var/lib/monerominer

        echo
        echo -e "${PURPLE}monerominer has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}monerominer${NC} command from anywhere."
        echo
        echo -e "Available commands:"
        echo -e "${BLUE}monerominer help${NC}    - Show all commands"
        echo -e "${BLUE}monerominer build${NC}   - Set up mining"
        echo -e "${BLUE}monerominer start${NC}   - Start mining"
        echo -e "${BLUE}monerominer stop${NC}    - Stop mining"
        echo -e "${BLUE}monerominer status${NC}  - Check status"
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script and clean up
uninstall() {
    echo
    echo -e "${YELLOW}Uninstalling Monero P2Pool Mining Script...${NC}"
    
    if sudo -v; then
        # Stop services if running
        if systemctl is-active --quiet monerod.service || \
           systemctl is-active --quiet p2pool.service || \
           systemctl is-active --quiet xmrig.service; then
            echo "Stopping mining services..."
            stop_services
        fi

        # Remove systemd services
        echo "Removing systemd services..."
        sudo systemctl disable monerod.service p2pool.service xmrig.service 2>/dev/null
        sudo rm -f /etc/systemd/system/monerod.service
        sudo rm -f /etc/systemd/system/p2pool.service
        sudo rm -f /etc/systemd/system/xmrig.service
        sudo systemctl daemon-reload

        # Remove script and directories
        echo "Removing script and configuration files..."
        sudo rm -f /usr/local/bin/monerominer
        # Remove environment file
        rm -f "$HOME/.monero_environment"

        # Ask user if they want to remove mining data
        read -p "Do you want to remove all mining data and configurations? (y/n): " REMOVE_DATA
        if [[ $REMOVE_DATA =~ ^[Yy]$ ]]; then
            echo "Removing all mining data..."
            sudo rm -rf /etc/monerominer
            sudo rm -rf /var/lib/monerominer
            rm -rf "$BASE_DIR"
        else
            echo "Mining data preserved in $BASE_DIR"
        fi

        echo -e "${GREEN}Uninstallation completed successfully.${NC}"
        echo "You may need to manually remove the mining directory if you want to remove all data:"
        echo "rm -rf $BASE_DIR"
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y \
        build-essential \
        cmake \
        pkg-config \
        libssl-dev \
        libzmq3-dev \
        libsodium-dev \
        libpgm-dev \
        libuv1-dev \
        libunbound-dev \
        libminiupnpc-dev \
        libunwind-dev \
        liblzma-dev \
        libreadline-dev \
        libldns-dev \
        libexpat1-dev \
        libgtest-dev \
        libcurl4-openssl-dev \
        git \
        wget \
        tar \
        ufw

    # Setup huge pages
    setup_huge_pages
}

# Function to setup huge pages
setup_huge_pages() {
    log "Setting up huge pages..."
    
    # Calculate huge pages (1GB per 1GB of RAM, minimum 1GB)
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    HUGE_PAGES=$((TOTAL_MEM > 0 ? TOTAL_MEM : 1))
    
    echo 'vm.nr_hugepages='$HUGE_PAGES | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$HUGE_PAGES
    
    # Add user to memlock group
    echo '*  soft  memlock  262144' | sudo tee -a /etc/security/limits.conf
    echo '*  hard  memlock  262144' | sudo tee -a /etc/security/limits.conf
}

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Handle Ctrl+C interruption to exit program.
handle_interrupt() {
    echo -e "\n${RED}Sync interrupted by user. Exiting...${NC}"
    exit 1
}

monitor_sync_status() {
    echo -e "${BLUE}===== Monitoring Blockchain Sync Status =====${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}\n"

    # Check if monerod service is running
    if ! systemctl is-active --quiet monerod.service; then
        echo -e "${RED}Monerod service is not running. Starting it now...${NC}"
        sudo systemctl start monerod.service
        sleep 5  # Give it some time to start
    fi

    # Monitor both the log file and journalctl output
    while true; do
        # Check log file
        if [ -f "$MONERO_DIR/monerod.log" ]; then
            SYNC_LINE=$(tail -n 50 "$MONERO_DIR/monerod.log" | grep -i "Synced" | tail -n 1)
        fi

        # If log file doesn't show sync status, check journalctl
        if [ -z "$SYNC_LINE" ]; then
            SYNC_LINE=$(journalctl -u monerod.service -n 50 --no-pager | grep -i "Synced" | tail -n 1)
        fi

        # Show current status
        if [ ! -z "$SYNC_LINE" ]; then
            # Clear previous line
            echo -en "\r\033[K"
            # Print sync status
            echo -en "${GREEN}$SYNC_LINE${NC}"
        else
            # If no sync information is available, show recent monerod output
            echo -e "\r\033[K${YELLOW}Waiting for sync information...${NC}"
            journalctl -u monerod.service -n 5 --no-pager | tail -n 5
        fi

        sleep 2
    done
}

setup_monero_node() {
    log "Setting up Monero node version ${MONERO_VERSION}..."
    
    mkdir -p "$MONERO_DIR"
    cd "$MONERO_DIR" || error "Failed to enter Monero directory"
    
    # Remove 'v' prefix if present
    local VERSION_NUM=${MONERO_VERSION#v}
    
    local TARFILE="monero-linux-x64-v${VERSION_NUM}.tar.bz2"
    local DOWNLOAD_URL="https://downloads.getmonero.org/cli/${TARFILE}"
    
    if [ -f "$TARFILE" ]; then
        log "Found existing Monero archive, skipping download"
    else
        log "Downloading from: ${DOWNLOAD_URL}"
        wget -q "${DOWNLOAD_URL}" -O "$TARFILE" || error "Failed to download Monero"
    fi
    
    tar xjf "$TARFILE" --strip-components=1
    #rm monero.tar.bz2
    
    # Create monero config
    cat > "$MONERO_DIR/monerod.conf" << EOF
data-dir=$MONERO_DIR/data
log-file=$MONERO_DIR/monerod.log
log-level=0
no-igd=1
zmq-pub=tcp://127.0.0.1:${MONERO_ZMQ_PORT}
out-peers=32
in-peers=64
add-priority-node=p2pmd.xmrvsbeast.com:18080
add-priority-node=nodes.hashvault.pro:18080
disable-dns-checkpoints=1
enable-dns-blocklist=1
EOF
}

check_blockchain_sync() {
    if [ -f "$MONERO_DIR/data/lmdb/data.mdb" ]; then
        # Blockchain data exists, check if synced
        if tail -n 50 "$MONERO_DIR/monerod.log" 2>/dev/null | grep -q "Synchronized OK"; then
            return 0  # Synced
        fi
    fi
    return 1  # Not synced
}

setup_p2pool() {
    log "Setting up P2Pool version ${P2POOL_VERSION}..."
    
    cd $BASE_DIR || error "Failed to enter base directory"

    # Define filenames
    local P2POOL_FILENAME="p2pool-${P2POOL_VERSION}-linux-x64"
    local TARFILE="${P2POOL_FILENAME}.tar.gz"
    local DOWNLOAD_URL="https://github.com/SChernykh/p2pool/releases/download/${P2POOL_VERSION}/${TARFILE}"
    
    # Remove any existing corrupted files
    if [ -f "$TARFILE" ]; then
        log "Removing existing P2Pool archive..."
        rm -f "$TARFILE"
    fi
    
    # Remove existing p2pool directory if it exists
    if [ -d "$P2POOL_DIR" ]; then
        log "Removing existing P2Pool directory..."
        rm -rf "$P2POOL_DIR"
    fi

    # Download fresh copy
    log "Downloading from: ${DOWNLOAD_URL}"
    wget -q "${DOWNLOAD_URL}" || error "Failed to download P2Pool"

    # Verify the download
    if [ ! -f "$TARFILE" ] || [ ! -s "$TARFILE" ]; then
        error "P2Pool download failed or file is empty"
    fi

    # Extract with error checking
    log "Extracting P2Pool..."
    if ! tar xzf "$TARFILE"; then
        rm -f "$TARFILE"
        error "Failed to extract P2Pool"
    fi

    # Rename the extracted directory to 'p2pool'
    mv "${P2POOL_FILENAME}" "p2pool" || error "Failed to rename P2Pool directory"

    # Clean up
    rm -f "$TARFILE"

    # Make p2pool executable
    chmod +x "$P2POOL_DIR/p2pool" || error "Failed to make P2Pool executable"

    # Verify installation
    if [ ! -x "$P2POOL_DIR/p2pool" ]; then
        error "P2Pool installation failed: executable not found or not executable"
    fi

    # Create a test script to verify P2Pool configuration
    cat > "$P2POOL_DIR/test_config.sh" << EOF
#!/bin/bash
$P2POOL_DIR/p2pool \
    --wallet $WALLET_ADDRESS \
    --host 127.0.0.1 \
    --rpc-port 18081 \
    --zmq-port ${MONERO_ZMQ_PORT} \
    --stratum 0.0.0.0:${MINING_PORT} \
    $(if [[ $USE_P2POOL_MINI =~ ^[Yy]$ ]]; then echo "--mini"; fi) \
    --help
EOF

    chmod +x "$P2POOL_DIR/test_config.sh" || error "Failed to make test script executable"

    # Log successful setup
    log "P2Pool setup completed successfully"
    log "Installation directory: $P2POOL_DIR"
    if [[ $USE_P2POOL_MINI =~ ^[Yy]$ ]]; then
        log "Running in mini mode (recommended for hashrates < 50 kH/s)"
    else
        log "Running in standard mode"
    fi
    log "Mining port: ${MINING_PORT}"
    log "ZMQ port: ${MONERO_ZMQ_PORT}"
}

# Function to setup XMRig CPU miner
setup_xmrig() {
    log "Setting up XMRig CPU miner version ${XMRIG_VERSION}..."
    
    mkdir -p "$XMRIG_DIR"
    cd "$XMRIG_DIR" || error "Failed to enter XMRig directory"
    
    # Download and extract XMRig
    local XMRIG_VERSION_NUM=${XMRIG_VERSION#v}  # Remove 'v' prefix from version
    local DOWNLOAD_URL="https://github.com/xmrig/xmrig/releases/download/${XMRIG_VERSION}/xmrig-${XMRIG_VERSION_NUM}-noble-x64.tar.gz"
    
    log "Downloading from: ${DOWNLOAD_URL}"
    wget -q "${DOWNLOAD_URL}" -O xmrig.tar.gz || error "Failed to download XMRig"
    tar xzf xmrig.tar.gz --strip-components=1 || error "Failed to extract XMRig"
    rm xmrig.tar.gz
    
    # Configure XMRig
    cat > "$XMRIG_DIR/config.json" << EOF
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": true,
        "priority": 5,
        "memory-pool": false,
        "yield": false,
        "max-threads-hint": ${CPU_THREADS},
        "asm": true
    },
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "127.0.0.1:${MINING_PORT}",
            "algo": "rx/0",
            "keepalive": true,
            "tls": false
        }
    ],
    "randomx": {
        "init": -1,
        "mode": "auto",
        "1gb-pages": true,
        "rdmsr": true,
        "wrmsr": true,
        "numa": true
    }
}
EOF

    # Set executable permissions
    chmod +x xmrig

    # Verify installation
    if [ ! -x "$XMRIG_DIR/xmrig" ]; then
        error "XMRig installation failed"
    fi

    log "XMRig setup completed successfully"
}

create_service_scripts() {
    log "Creating service scripts..."
    
    # Create monerod script
    sudo tee /usr/local/bin/run-monerod.sh > /dev/null << EOF
#!/bin/bash
cd ${MONERO_DIR}
./monerod --data-dir ${MONERO_DIR}/data --zmq-pub tcp://127.0.0.1:18083 --disable-dns-checkpoints --enable-dns-blocklist --non-interactive
EOF

    # Create P2Pool script
    sudo tee /usr/local/bin/run-p2pool.sh > /dev/null << EOF
#!/bin/bash
cd ${P2POOL_DIR}
./p2pool \
    --wallet ${WALLET_ADDRESS} \
    --host 127.0.0.1 \
    $(if [[ $USE_P2POOL_MINI =~ ^[Yy]$ ]]; then echo "--mini"; fi) \
    --non-interactive
EOF

    # Create XMRig script
    sudo tee /usr/local/bin/run-xmrig.sh > /dev/null << EOF
#!/bin/bash
cd ${XMRIG_DIR}
./xmrig -o 127.0.0.1:3333 -u x+50000 --randomx-1gb-pages --non-interactive
EOF

    # Make scripts executable
    sudo chmod +x /usr/local/bin/run-monerod.sh
    sudo chmod +x /usr/local/bin/run-p2pool.sh
    sudo chmod +x /usr/local/bin/run-xmrig.sh
}

create_systemd_services() {
    log "Creating systemd services..."
    
    # Create the service scripts first
    create_service_scripts

    # Monero daemon service
    sudo tee /etc/systemd/system/monerod.service > /dev/null << EOF
[Unit]
Description=Monero Full Node
After=network.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/run-monerod.sh
StandardInput=null
StandardOutput=append:/var/log/monerod.log
StandardError=append:/var/log/monerod.error.log
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # P2Pool service
    sudo tee /etc/systemd/system/p2pool.service > /dev/null << EOF
[Unit]
Description=P2Pool Monero Mining
After=monerod.service
Requires=monerod.service

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/run-p2pool.sh
StandardInput=null
StandardOutput=append:/var/log/p2pool.log
StandardError=append:/var/log/p2pool.error.log
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # XMRig service
    sudo tee /etc/systemd/system/xmrig.service > /dev/null << EOF
[Unit]
Description=XMRig CPU Miner
After=p2pool.service
Requires=p2pool.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/run-xmrig.sh
StandardInput=null
StandardOutput=append:/var/log/xmrig.log
StandardError=append:/var/log/xmrig.error.log
Restart=always
RestartSec=30
Nice=10

[Install]
WantedBy=multi-user.target
EOF

    # Create log directory and set permissions
    sudo mkdir -p /var/log
    sudo touch /var/log/{monerod,monerod.error,p2pool,p2pool.error,xmrig,xmrig.error}.log
    sudo chown -R ${USER}:${USER} /var/log/{monerod,monerod.error,p2pool,p2pool.error,xmrig,xmrig.error}.log

    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable services
    sudo systemctl enable monerod p2pool xmrig
}

# Service management functions
check_services_status() {
    echo -e "${BLUE}===== Monero Mining Services Status =====${NC}"
    for service in monerod p2pool xmrig; do
        status=$(systemctl is-active $service.service)
        if [ "$status" = "active" ]; then
            echo -e "${GREEN}● $service.service is running${NC}"
        else
            echo -e "${RED}○ $service.service is $status${NC}"
        fi
        echo "---"
        systemctl status $service.service --no-pager | grep -A 2 "Active:"
        echo
    done

    # Show mining stats if services are running
    if systemctl is-active xmrig.service >/dev/null; then
        show_mining_stats
    fi
}

start_services() {
    log "Starting mining services..."
    sudo systemctl start monerod
    sleep 10  # Wait for Monero daemon to initialize
    sudo systemctl start p2pool
    sleep 5   # Wait for P2Pool to initialize
    sudo systemctl start xmrig
    check_services_status
}

stop_services() {
    log "Stopping mining services..."
    sudo systemctl stop xmrig
    sudo systemctl stop p2pool
    sudo systemctl stop monerod
    check_services_status
}

restart_services() {
    log "Restarting mining services..."
    stop_services
    sleep 5
    start_services
}

show_mining_stats() {
    echo -e "${BLUE}===== Mining Statistics =====${NC}"
    
    # Check if Monero daemon is synced
    if [ -f "$MONERO_DIR/monerod.log" ]; then
        SYNC_STATUS=$(tail -n 50 "$MONERO_DIR/monerod.log" | grep -i "synchronized" | tail -n 1)
        echo -e "Monero Sync Status: ${GREEN}$SYNC_STATUS${NC}"
    fi
    
    # Show P2Pool stats
    if [ -f "$P2POOL_DIR/p2pool.log" ]; then
        SHARES=$(grep -i "found share" "$P2POOL_DIR/p2pool.log" | wc -l)
        echo "P2Pool Shares Found: $SHARES"
    fi
    
    # Show XMRig hashrate
    if pgrep xmrig >/dev/null; then
        echo "XMRig Hashrate:"
        curl -s http://127.0.0.1:3333/api.json | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f\"  Current: {data['hashrate']['total'][0]:.2f} H/s\")
    print(f\"  Average: {data['hashrate']['total'][1]:.2f} H/s\")
except:
    print('  Unable to fetch hashrate data')
"
    fi
}

show_help() {
    echo -e "${BLUE}===== Monero P2Pool Mining Tool=====${NC}"
    echo -e "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo -e "${GREEN}  install${NC}       - Install the script in path"
    echo -e "${GREEN}  uninstall${NC}     - Uninstall the script in path"
    echo -e "${GREEN}  help${NC}          - Show this help message"
    echo -e "${GREEN}  build${NC}         - Run full installation and setup"
    echo -e "${GREEN}  status${NC}        - Show status of all Monero services"
    echo -e "${GREEN}  start${NC}         - Start all Monero services"
    echo -e "${GREEN}  stop${NC}          - Stop all Monero services"
    echo -e "${GREEN}  restart${NC}       - Restart all Monero services"
    echo -e "${GREEN}  monitor${NC}       - Monitor blockchain sync progress"
    echo -e "${GREEN}  stats${NC}         - Show mining statistics"
    echo
    echo "Examples:"
    echo "  monerominer build     # Run full installation"
    echo "  monerominer services  # Check services status"
    echo
    echo "Requirements:"
    echo "- Ubuntu/Debian based system"
    echo "- CPU with AES-NI support"
    echo "- Sudo privileges"
    echo
    echo "Notes:"
    echo "- The build command will install all dependencies and set up mining"
    echo "- Service commands require the initial build to be completed"
    echo "- Mining data is stored in $BASE_DIR"
    echo "- Logs are available in respective service directories"
    echo
    echo "License: Apache 2.0"
    echo "Repo: https://github.com/Mik-TF/monerominer"
}

# Main installation function
main() {
    # Check if script is run as root
    if [ "$(id -u)" = "0" ]; then
        error "This script should not be run as root"
    fi

    # Create base directory
    mkdir -p "$BASE_DIR"

    # Collect user inputs
    collect_user_inputs

    # Installation steps
    install_dependencies
    setup_monero_node

    # Check if blockchain needs syncing
    if ! check_blockchain_sync; then
        echo -e "${YELLOW}The Monero blockchain is not fully synced yet.${NC}"
        read -p "Do you want to sync it before continuing? (recommended) [y/n]: " SYNC_FIRST
        
        if [[ $SYNC_FIRST =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Starting Monero daemon for initial sync...${NC}"
            echo -e "${YELLOW}This may take several hours. You can press Ctrl+C to stop syncing.${NC}"
            echo -e "${YELLOW}The sync will continue from where it left off next time.${NC}"
            
            # Set up interrupt handler
            trap handle_interrupt SIGINT
            
            # Run monerod in interactive mode for initial sync
            if ! (cd "${MONERO_DIR}" && ./monerod --config-file="${MONERO_DIR}/monerod.conf"); then
                echo -e "\n${RED}Sync was interrupted or failed. Exiting...${NC}"
                exit 1
            fi
            
            # Remove the trap handler
            trap - SIGINT
            
            # Check if sync completed successfully
            if ! check_blockchain_sync; then
                echo -e "\n${RED}Blockchain sync did not complete successfully. Please run the script again.${NC}"
                exit 1
            fi
            
            echo -e "\n${GREEN}Blockchain sync completed successfully!${NC}"
        fi
    fi

    setup_p2pool
    setup_xmrig
    create_systemd_services

    # Start services if requested
    if [[ $START_SERVICES =~ ^[Yy]$ ]]; then
        start_services
        
        # Monitor sync status
        echo -e "\n${YELLOW}Starting blockchain sync monitoring...${NC}"
        monitor_sync_status
    fi

    # Show completion message
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "Mining directory: ${BLUE}$BASE_DIR${NC}"
    echo -e "Configuration files:"
    echo -e "  Monero: ${BLUE}$MONERO_DIR/monerod.conf${NC}"
    echo -e "  P2Pool: ${BLUE}$P2POOL_DIR/config.json${NC}"
    echo -e "  XMRig:  ${BLUE}$XMRIG_DIR/config.json${NC}"
    echo
    echo -e "Use '${YELLOW}$0 status${NC}' to check service status"
    echo -e "Use '${YELLOW}$0 stats${NC}' to view mining statistics"
}

# Command line argument handling
case "$1" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    build)
        main
        ;;
    monitor)
        monitor_sync_status
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        check_services_status
        ;;
    stats)
        show_mining_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0
