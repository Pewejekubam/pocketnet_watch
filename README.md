# Pocketnet Watch Script

This script monitors the status of a Pocketnet node by displaying various metrics and logs. It is designed to run in a loop, updating the display every 5 seconds and clearing the screen every 15 cycles.

## Features

- **Enhanced Metrics**:
  - Wallet balance, unconfirmed balance, and staking details.
  - Node version, network type, and connection details (inbound/outbound).
  - Blockchain sync status, block height, headers, and difficulty.
  - Network hashrate and mempool information.
  - System resource usage (CPU, memory, disk, and swap).
  - Stake reports (last 24h, 7d, 30d, 365d) and staking weight percentages.
- **Improved UI**:
  - Boxed UI for better readability (optional compact mode available).
  - Dynamic formatting with commas and decimal precision for numbers.
  - Clear screen every configurable number of cycles.
- **Log Integration**:
  - Displays the last 5 lines of the debug log.
  - Includes the last 3 lines of `probe_nodes.log` if available.
- **Additional Features**:
  - Displays the highest balance wallet address.
  - Shows node uptime and system load averages.
  - Provides formatted time differences for staking and uptime metrics.
  - Retrieves staking info, including expected time for the next reward.

## Prerequisites

- A running Pocketnet node.
- `jq` for JSON parsing.
- `pocketcoin-cli` configured and accessible in your PATH.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/pocketnet-watch.git
   cd pocketnet-watch
   ```

2. Make the script executable:
   ```bash
   chmod +x pocketnet-watch.sh
   ```

3. Configure the script by editing the `POCKETCOIN_CLI_ARGS` variable to match your setup:
   ```bash
   # Edit this line if needed
   POCKETCOIN_CLI_ARGS="-rpcport=67530 -conf=/path/to/pocketcoin.conf"
   ```
   If no custom arguments are required, you can leave this variable empty (`""`), which is the default setting.

## Usage

Run the script from your terminal:

```bash
./pocketnet-watch.sh
```

### Command-Line Options

- `-h, --help`: Display help message.
- `-b, --boxed`: Use boxed UI (default).
- `-c, --compact`: Use compact UI without boxes.
- `-r, --refresh N`: Set refresh interval to N seconds (default: 5).
- `--clear N`: Clear screen every N cycles (default: 15).

To exit the monitoring, press `Ctrl+C`.

## Configuration

The script uses the following configuration variables:

- `POCKETCOIN_CLI_ARGS`: Command-line arguments passed to `pocketcoin-cli`.
- `USE_BOXED_UI`: Set to `true` for boxed UI or `false` for compact UI.
- `REFRESH_SECONDS`: Time between screen refreshes (default: 5 seconds).
- `CLEAR_CYCLES`: Number of cycles before clearing the screen (default: 15).

## Functions

The script includes several functions for retrieving and displaying metrics:

| Function | Description |
|----------|-------------|
| `get_wallet_balance()` | Retrieves wallet balance with formatting. |
| `get_node_version()` | Retrieves the Pocketnet node version. |
| `get_connections_details()` | Displays total, inbound, and outbound connections. |
| `get_sync_status()` | Shows blockchain sync percentage. |
| `get_staking_info()` | Provides detailed staking metrics. |
| `get_debug_log()` | Displays the last 5 lines of the debug log. |
| `get_system_uptime()` | Retrieves system uptime. |
| `get_disk_usage()` | Displays disk usage for the blockchain directory. |

## Screenshots

![Screenshot](https://github.com/Pewejekubam/pocketnet_watch/blob/main/watch-screen-shot.png)

## Extending the Script

You can easily extend the script to include additional metrics:

1. Create a new function to retrieve the desired information.
2. Add the function call to the `display_metrics()` function.
3. Format the output as needed using `printf`.

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

- Ensure `pocketcoin-cli` is properly installed and in your PATH.
- Verify that `jq` is installed (`apt-get install jq` or `brew install jq`).
- Check the RPC port and configuration file path in `POCKETCOIN_CLI_ARGS`.
- Make sure your Pocketnet node is running.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add some amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- The Pocketnet community.
- Contributors to the jq project.