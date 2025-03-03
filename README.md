# Pocketnet Watch Script

This script monitors the status of a Pocketnet node by displaying various metrics and logs. It is designed to run in a loop, updating the display every 5 seconds and clearing the screen every 15 cycles.

## Features

- Displays the current date and time.
- Shows the wallet address with the highest balance.
- Displays wallet balance, node version, and number of connections.
- Shows the current block height and difficulty.
- Displays staking information, including stake time, net stake weight, and expected time.
- Shows the staking status and a staking report.
- Displays local memory usage.
- Shows the last 10 lines of the Pocketnet debug log.
- Displays the last 4 lines of the `probe_nodes.log` file if it exists.

## Usage

To run the script, simply execute it in a terminal:

```bash
./pocketnet-watch.sh# Pocketnet Watch Script
```

A lightweight monitoring tool for Pocketnet nodes that provides real-time metrics and logs in your terminal.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

The Pocketnet Watch Script is a bash utility that continuously monitors and displays essential information about your Pocketnet node. It provides a dashboard with metrics such as wallet balance, node connections, block information, staking status, and system memory usage - all updated in real-time.

## Features

- **Real-time Monitoring**: Updates every 5 seconds with a screen refresh every 15 cycles
- **Comprehensive Metrics**:
  - Current wallet address and balance
  - Node version and connection count
  - Block height and network difficulty
  - Detailed staking information and statistics
  - System memory usage
- **Log Integration**: Displays the most recent entries from debug and probe logs
- **Lightweight**: Minimal system resource usage
- **Easy to Configure**: Simple setup with customizable parameters

## Screenshots

![Screenshot](https://github.com/Pewejekubam/pocketnet_watch/blob/main/watch-screen-shot.png)


## Prerequisites

- A running Pocketnet node
- `jq` for JSON parsing
- `pocketcoin-cli` configured and accessible in your PATH

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/pocketnet-watch.git
   cd pocketnet-watch
   ```

2. Make the script executable:
   ```bash
   chmod +x watch.sh
   ```

3. Configure the script by editing the `POCKETCOIN_CLI_ARGS` variable to match your setup.  You can leave this blank if you don't need any runtime arguments.  If you prefer, you can just argue with Snowflakecrusher:
   ```bash
   # Edit this line if needed
   POCKETCOIN_CLI_ARGS="-rpcport=67530 -conf=/path/to/pocketnet/pocketcoin.conf"
   ```

## Usage

Simply run the script from your terminal:

```bash
./watch.sh
```

To exit the monitoring, press `Ctrl+C`.

## Configuration

The script uses a single configuration variable:

- `POCKETCOIN_CLI_ARGS`: Command-line arguments passed to `pocketcoin-cli`
  - Set your custom RPC port and configuration file path here
  - Leave empty if using default values

## Functions

The script includes several functions for retrieving different types of information:

| Function | Description |
|----------|-------------|
| `get_highest_balance_address()` | Retrieves the address with the highest balance |
| `get_wallet_info()` | Gets current wallet balance |
| `get_node_version()` | Retrieves the Pocketnet node version |
| `get_connections()` | Gets the number of connections to other nodes |
| `get_block_info()` | Retrieves current block height |
| `get_difficulty()` | Gets current network difficulty |
| `get_stake_time()` | Retrieves stake time information |
| `get_staking_info()` | Gets detailed staking metrics |
| `get_staking_status()` | Checks if staking is currently active |
| `get_memory_usage()` | Displays system memory usage |
| `get_debug_log()` | Shows recent debug log entries |

## Extending the Script

You can easily extend the script to include additional metrics:

1. Create a new function to retrieve the desired information
2. Add the function call to the `display_metrics()` function
3. Format the output as needed using `printf`

Example of adding a new metric:

```bash
# Function to get new metric
get_new_metric() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS some_command | jq -r '.some_value'
}

# Then add to display_metrics()
printf "%-32s\n" "New Metric: $(get_new_metric)"
```

## Troubleshooting

If you encounter issues:

- Ensure `pocketcoin-cli` is properly installed and in your PATH
- Verify that `jq` is installed (`apt-get install jq` or `brew install jq`)
- Check the RPC port and configuration file path in `POCKETCOIN_CLI_ARGS`
- Make sure your Pocketnet node is running

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- The Pocketnet community
- Contributors to the jq project