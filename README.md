<h1> Monero P2Pool CPU Mining Script for Ubuntu/Debian Systems </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Set Up the Miner](#set-up-the-miner)
- [Usage](#usage)
  - [Available Commands](#available-commands)
  - [Examples](#examples)
- [Service Management](#service-management)
  - [Control Services](#control-services)
- [Security](#security)
- [Important Notes](#important-notes)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [References](#references)
- [Contributing](#contributing)
- [Support](#support)

---

## Introduction

A comprehensive setup script for Monero P2Pool CPU mining on Ubuntu/Debian systems. This script automates the entire process of setting up a Monero full node, P2Pool mining node, and XMRig CPU miner.

## Features

- Full Monero node setup
- P2Pool mining node configuration
- XMRig CPU miner optimization
- Support for P2Pool Mini
- Systemd service integration
- Installation in system path for easy access
- Service management commands
- Mining statistics monitoring

## Requirements

- Monero Wallet Address
- Ubuntu/Debian based system
- Minimum 2GB RAM (4GB+ recommended)
- Multi-core CPU
- Sudo privileges
- Internet connection

To create a new Monero wallet, consult the Monero documentation:
- [GUI Wallet](https://www.getmonero.org/downloads/#gui)
- [CLI Wallet](https://www.getmonero.org/downloads/#cli)

## Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/Mik-TF/monerominer/main/monerominer.sh

# Install in system path
bash monerominer.sh install

# Clean Up
rm monerominer.sh
```

## Set Up the Miner

```bash
# Build the miner setup
monerominer build
```

## Usage

```bash
monerominer [COMMAND]
```

### Available Commands

- `install` - Install script system-wide
- `uninstall` - Remove script and clean up
- `build` - Run full installation and setup
- `start` - Start all mining services
- `stop` - Stop all mining services
- `restart` - Restart all mining services
- `status` - Show status of all services
- `stats` - Show mining statistics
- `help` - Show help message

### Examples

```bash
# Check services status
monerominer status

# View mining statistics
monerominer stats
```

## Service Management

The script creates and manages three systemd services:
1. `monerod.service` - Monero blockchain daemon
2. `p2pool.service` - P2Pool mining node
3. `xmrig.service` - CPU mining service

### Control Services

```bash
monerominer start    # Start all services
monerominer stop     # Stop all services
monerominer restart  # Restart all services
```

## Security

- Services run under user permissions
- Configuration files use appropriate permissions
- P2Pool connects to local node only
- XMRig mines to local P2Pool instance

## Important Notes

- Ensure your wallet address is correct
- Consider using P2Pool Mini for hashrates < 50 kH/s
- Keep your system updated and secured
- Initial blockchain sync may take several days
- Mining rewards go directly to your wallet
- Use at your own risk

## Troubleshooting

If you encounter issues:
1. Check service status: `monerominer status`
2. View service logs: `journalctl -u [service-name]`
3. Ensure sufficient disk space for blockchain
4. Verify CPU compatibility with RandomX
5. Check mining statistics: `monerominer stats`

## License

This work is licensed under the [Apache License 2.0](./LICENSE).

## References

For more information on Monero and P2Pool:
- [Monero Documentation](https://www.getmonero.org/resources/user-guides/)
- [P2Pool Documentation](https://github.com/SChernykh/p2pool)
- [XMRig Documentation](https://xmrig.com/docs)

We are not endorsing Monero nor are a partner of Monero. This is for educational purpose only.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or contributions, please visit:
[GitHub Repository](https://github.com/Mik-TF/monerominer)