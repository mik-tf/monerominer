#!/bin/bash

# Monero P2Pool CPU Mining Setup Script
# For Ubuntu/Debian Systems
# Sets up Monero Node, P2Pool, and XMRig CPU Miner

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
MONERO_VERSION="v0.18.3.1"
P2POOL_VERSION="v3.9"
XMRIG_VERSION="v6.21.0"

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

# Function to collect user inputs upfront
collect_user_inputs() {
    echo -e "${BLUE}===== Monero P2Pool Mining Setup =====${NC}"
    
    # Get wallet address
    while true; do
        read -p "Enter your Monero wallet address (starts with 4): " WALLET_ADDRESS
        if [[ $WALLET_ADDRESS =~ ^4[0-9A-Za-z]{94}$ ]]; then
            break
        else
            echo -e "${RED}Invalid Monero address format. Please try again.${NC}"
        fi
    done

    # P2Pool mini option
    read -p "Use P2Pool mini chain? (Recommended for hashrates < 50 kH/s) [y/n]: " USE_P2POOL_MINI
    
    # CPU threads configuration
    echo -e "${YELLOW}Detecting CPU configuration...${NC}"
    AVAILABLE_THREADS=$(nproc)
    echo "Available CPU threads: $AVAILABLE_THREADS"
    read -p "How many CPU threads to use for mining? (1-$AVAILABLE_THREADS, recommended: $(($AVAILABLE_THREADS-1))): " CPU_THREADS
    
    # Service autostart
    read -p "Start mining services after installation? [y/n]: " START_SERVICES
}

# Function to install the script system-wide
install() {
    echo
    echo -e "${GREEN}Installing Monero P2Pool Mining Script...${NC}"
    
    # Check if running with sudo privileges
    if sudo -v; then
        # Copy script to /usr/local/bin
        sudo cp "$0" /usr/local/bin/moneropool
        sudo chown root:root /usr/local/bin/moneropool
        sudo chmod 755 /usr/local/bin/moneropool

        # Create configuration directory
        sudo mkdir -p /etc/moneropool
        
        # Create data directory
        sudo mkdir -p /var/lib/moneropool
        sudo chown -R $USER:$USER /var/lib/moneropool

        echo
        echo -e "${PURPLE}moneropool has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}moneropool${NC} command from anywhere."
        echo
        echo -e "Available commands:"
        echo -e "${BLUE}moneropool help${NC}    - Show all commands"
        echo -e "${BLUE}moneropool build${NC}   - Set up mining"
        echo -e "${BLUE}moneropool start${NC}   - Start mining"
        echo -e "${BLUE}moneropool stop${NC}    - Stop mining"
        echo -e "${BLUE}moneropool status${NC}  - Check status"
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
        sudo rm -f /usr/local/bin/moneropool
        
        # Ask user if they want to remove mining data
        read -p "Do you want to remove all mining data and configurations? (y/n): " REMOVE_DATA
        if [[ $REMOVE_DATA =~ ^[Yy]$ ]]; then
            echo "Removing all mining data..."
            sudo rm -rf /etc/moneropool
            sudo rm -rf /var/lib/moneropool
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

# Function to download and setup Monero node
setup_monero_node() {
    log "Setting up Monero node..."
    
    mkdir -p "$MONERO_DIR"
    cd "$MONERO_DIR" || error "Failed to enter Monero directory"
    
    # Download Monero CLI
    wget -q https://downloads.getmonero.org/cli/linux64 -O monero.tar.bz2 || error "Failed to download Monero"
    tar xjf monero.tar.bz2 --strip-components=1
    rm monero.tar.bz2
    
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

# Function to setup P2Pool
setup_p2pool() {
    log "Setting up P2Pool..."
    
    mkdir -p "$P2POOL_DIR"
    cd "$P2POOL_DIR" || error "Failed to enter P2Pool directory"
    
    # Download and extract P2Pool
    wget -q https://github.com/SChernykh/p2pool/releases/download/${P2POOL_VERSION}/p2pool-linux-x64-${P2POOL_VERSION}.tar.gz || error "Failed to download P2Pool"
    tar xzf p2pool-linux-x64-${P2POOL_VERSION}.tar.gz
    rm p2pool-linux-x64-${P2POOL_VERSION}.tar.gz
    
    # Create P2Pool config based on user choice
    local MINI_FLAG=""
    [[ $USE_P2POOL_MINI =~ ^[Yy]$ ]] && MINI_FLAG="--mini"
    
    cat > "$P2POOL_DIR/config.json" << EOF
{
    "wallet": "${WALLET_ADDRESS}",
    "host": "127.0.0.1",
    "zmq-port": ${MONERO_ZMQ_PORT},
    ${MINI_FLAG}
    "stratum-port": ${MINING_PORT},
    "p2p-bind-port": ${[[ $USE_P2POOL_MINI =~ ^[Yy]$ ]] && echo $P2POOL_MINI_PORT || echo $P2POOL_PORT}
}
EOF
}

# Function to setup XMRig CPU miner
setup_xmrig() {
    log "Setting up XMRig CPU miner..."
    
    mkdir -p "$XMRIG_DIR"
    cd "$XMRIG_DIR" || error "Failed to enter XMRig directory"
    
    # Download and extract XMRig
    wget -q https://github.com/xmrig/xmrig/releases/download/${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-x64.tar.gz || error "Failed to download XMRig"
    tar xzf xmrig-${XMRIG_VERSION}-linux-x64.tar.gz --strip-components=1
    rm xmrig-${XMRIG_VERSION}-linux-x64.tar.gz
    
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
}

# Function to create systemd services
create_systemd_services() {
    log "Creating systemd services..."
    
    # Monero daemon service
    sudo tee /etc/systemd/system/monerod.service > /dev/null << EOF
[Unit]
Description=Monero Full Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$MONERO_DIR/monerod --config-file=$MONERO_DIR/monerod.conf
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
User=$USER
Type=simple
ExecStart=$P2POOL_DIR/p2pool --config $P2POOL_DIR/config.json
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
User=$USER
Type=simple
ExecStart=$XMRIG_DIR/xmrig --config=$XMRIG_DIR/config.json
Restart=always
RestartSec=30
Nice=10

[Install]
WantedBy=multi-user.target
EOF

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
    echo -e "${BLUE}===== Monero P2Pool CPU Mining Script =====${NC}"
    echo -e "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo -e "${GREEN}  install${NC}   - Install script system-wide"
    echo -e "${GREEN}  uninstall${NC} - Remove script and clean up"
    echo -e "${GREEN}  build${NC}    - Run full installation and setup"
    echo -e "${GREEN}  start${NC}    - Start all mining services"
    echo -e "${GREEN}  stop${NC}     - Stop all mining services"
    echo -e "${GREEN}  restart${NC}  - Restart all mining services"
    echo -e "${GREEN}  status${NC}   - Show status of all services"
    echo -e "${GREEN}  stats${NC}    - Show mining statistics"
    echo -e "${GREEN}  help${NC}     - Show this help message"
    echo
    echo "Example:"
    echo "  $0 build     # Run full installation"
    echo "  $0 status    # Check services status"
    echo
    echo "Requirements:"
    echo "- Ubuntu/Debian based system"
    echo "- Sudo privileges"
    echo "- Internet connection"
    echo
    echo "Notes:"
    echo "- Mining data is stored in $BASE_DIR"
    echo "- Logs are available in respective service directories"
    echo "- Use 'systemctl status <service>' for detailed service status"
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
    setup_p2pool
    setup_xmrig
    create_systemd_services

    # Start services if requested
    if [[ $START_SERVICES =~ ^[Yy]$ ]]; then
        start_services
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