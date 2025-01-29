#!/bin/bash

<<<<<<< HEAD
# -----------------------------------------------------------------------------
# Pocketnet Watch Script
# -----------------------------------------------------------------------------
# This script monitors the status of a Pocketnet node by displaying various
# metrics and logs. It retrieves information such as wallet balance, node
# version, connections, block info, staking info, and memory usage. The script
# runs in a loop, updating the display every 5 seconds and clearing the screen
# every 15 cycles. It also displays the last 4 lines of the probe_nodes.log
# file if it exists.
#
# Timestamp: 2025-01-24 18:09:44
# -----------------------------------------------------------------------------


# Function to get the highest balance address
=======
# Function to get address groupings and capture the wallet address with the highest balance
>>>>>>> origin/main
get_highest_balance_address() {
    pocketcoin-cli listaddressgroupings | jq -r '.[0] | max_by(.[1]) | .[0]'
}

# Function to get wallet info
get_wallet_info() {
    pocketcoin-cli getwalletinfo | jq -r '.sql_balance'
}

<<<<<<< HEAD
# Function to get node version
get_node_version() {
    pocketcoin-cli -getinfo | jq -r '.version'
}

# Function to get connections
get_connections() {
    pocketcoin-cli -getinfo | jq -r '.connections.total'
}

# Function to get block info
get_block_info() {
    pocketcoin-cli -getinfo | jq -r '.blocks'
}

# Function to get difficulty
get_difficulty() {
    pocketcoin-cli -getinfo | jq -r '.difficulty'
=======
# Function to get general info
get_general_info() {
    pocketcoin-cli -getinfo | jq -r '"Version: \(.version) | Connections: \(.connections.total)"'
}

# Function to get block and difficulty info
get_block_difficulty_info() {
    pocketcoin-cli -getinfo | jq -r '"Blocks: \(.blocks) | Difficulty: \(.difficulty)"'
}

# Function to get staking info
get_staking_info() {
    pocketcoin-cli getstakinginfo | jq -r '"Expectedtime: \(.expectedtime) | Netstakeweight: \(.netstakeweight)"'
}

# Function to get staking status
get_staking_status() {
    pocketcoin-cli getstakinginfo | grep "staking" | grep "false"
>>>>>>> origin/main
}

# Function to get stake time
get_stake_time() {
    pocketcoin-cli getstakinginfo | jq -r '.["stake-time"]'
}

<<<<<<< HEAD
# Function to get staking info
get_staking_info() {
    pocketcoin-cli getstakinginfo | jq -r '"Netstakeweight: \(.netstakeweight)  | Expectedtime: \(.expectedtime)"'
}

# Function to get staking status
get_staking_status() {
    pocketcoin-cli getstakinginfo | jq -r '.staking'
}

=======
>>>>>>> origin/main
# Function to get last stake reward time
get_last_stake_reward() {
    pocketcoin-cli getstakereport | grep "Last stake time" | awk -F': ' '{print $2}'
}

# Function to get stake report
get_stake_report() {
    pocketcoin-cli getstakereport | head -n 7 | tail -n +2
}

# Function to get memory usage
get_memory_usage() {
    free -h
}

# Function to get debug log
get_debug_log() {
    tail -n 10 ~/.pocketcoin/debug.log
}

<<<<<<< HEAD
# Function to display the last 4 lines of the probe_nodes.log if it exists
display_probe_nodes_log() {
    if [ -f "$HOME/probe_nodes/probe_nodes.log" ]; then
        echo "--------------probe_nodes_log--------------"
        tail -n 4 "$HOME/probe_nodes/probe_nodes.log"
    fi
}

=======
>>>>>>> origin/main
# Function to display metrics
display_metrics() {
    tput civis # Hide the cursor
    trap 'tput cnorm; exit' INT TERM # Show the cursor on exit
    printf "%-32s\n" "$(date +"%a %Y-%m-%d %H:%M:%S %Z")"
    printf "%-32s\n" "Wallet Address: $(get_highest_balance_address)"
<<<<<<< HEAD
    printf "%-32s | %-32s | %-32s\n" "Wallet Balance: $(get_wallet_info)" "Version: $(get_node_version)" "Connections: $(get_connections)"
    printf "%-32s | %-32s | %-32s\n" "Blocks: $(get_block_info)" "Difficulty: $(get_difficulty)" "Stake Time: $(get_stake_time)"
    printf "%-32s | %-32s\n" "$(get_staking_info)"
    if [ "$(get_staking_status)" = "false" ]; then
=======
    printf "%-32s | %-32s | %-32s\n" "Wallet Balance: $(get_wallet_info)" "Version: $(pocketcoin-cli -getinfo | jq -r '.version')" "Connections: $(pocketcoin-cli -getinfo | jq -r '.connections.total')"
    printf "%-32s | %-32s | %-32s\n" "Blocks: $(pocketcoin-cli -getinfo | jq -r '.blocks')" "Difficulty: $(pocketcoin-cli -getinfo | jq -r '.difficulty')" "Stake Time: $(get_stake_time)"
    printf "%-32s | %-32s\n" "Netstakeweight: $(pocketcoin-cli getstakinginfo | jq -r '.netstakeweight')" "Expectedtime: $(pocketcoin-cli getstakinginfo | jq -r '.expectedtime')"
    if [ "$(get_staking_status)" ]; then
>>>>>>> origin/main
        printf "%-32s\n" "Staking Status: false"
    fi
    printf "%-32s\n" "Staking Report:"
    get_stake_report
    printf "%-32s\n" "Local Memory Usage:"
    get_memory_usage
    get_debug_log
<<<<<<< HEAD
    display_probe_nodes_log
=======

    # Display the last 4 lines of the probe_nodes.log if it exists
    if [ -f "$HOME/probe_nodes/probe_nodes.log" ]; then
        echo "--------------probe_nodes_log--------------"
        tail -n 4 "$HOME/probe_nodes/probe_nodes.log"
    fi
>>>>>>> origin/main
}

# Main loop
clear
counter=0
while true; do
    tput cup 0 0
    display_metrics
    sleep 5
    counter=$((counter + 1))
    if [ $counter -eq 15 ]; then
        clear
        counter=0
    fi
<<<<<<< HEAD
done
=======
done

>>>>>>> origin/main
