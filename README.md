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
./pocketnet-watch.sh