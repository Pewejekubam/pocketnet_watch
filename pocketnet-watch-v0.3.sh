#!/bin/bash
# -----------------------------------------------------------------------------
# Pocketnet Watch Script - Enhanced Version
# -----------------------------------------------------------------------------
# This script monitors the status of a Pocketnet node by displaying various
# metrics and logs in a compact, organized UI. It retrieves information about
# wallet balance, node status, blockchain details, staking info, and system
# resources.
# v0.3
# Timestamp: 2025-03-19 0924 CST
# -----------------------------------------------------------------------------
# Custom arguments for pocketcoin-cli
# Note: This can be an empty string if no custom arguments are needed.
# POCKETCOIN_CLI_ARGS="-rpcport=67530 -conf=/path/to/pocketnet/pocketcoin.conf"
POCKETCOIN_CLI_ARGS=""
# Configuration options
USE_BOXED_UI=true     # Set to false for non-boxed UI
REFRESH_SECONDS=5     # Time between screen refreshes
CLEAR_CYCLES=15       # Clear screen every N cycles
# BOX_PADDING=2         # Padding inside UI boxes
DEFAULT_BOX_WIDTH=80  # Default width for UI boxes

# Check for jq installation
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq."
    exit 1
fi

# Function to get wallet balance using sql_balance
get_wallet_balance() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo 2>/dev/null)
    local sql_balance=$(echo "$info" | jq -r '.sql_balance' || echo "0")
    
    # Format balance with commas and 8 decimal places
    if [[ -n "$sql_balance" && "$sql_balance" != "0" ]]; then
        local balance_integer=$(echo "$sql_balance" | cut -d'.' -f1)
        local balance_decimal=$(echo "$sql_balance" | cut -d'.' -f2)
        local formatted_integer=$(printf "%'d" $balance_integer)
        echo "${formatted_integer}.${balance_decimal}"
    else
        echo "0.00000000"
    fi
}

# Function to get wallet info
get_wallet_info() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo | jq -r '.balance' || echo "Unknown"
}

# Function to get unconfirmed balance
get_unconfirmed_balance() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS getunconfirmedbalance 2>/dev/null || echo "0"
}

# Function to get wallet status (encrypted/locked/unlocked)
get_wallet_status() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo 2>/dev/null)
    if [[ $(echo "$info" | jq -r 'has("unlocked_until")') == "true" ]]; then
        local unlock_time=$(echo "$info" | jq -r '.unlocked_until')
        if [[ $unlock_time == "0" ]]; then
            echo "Locked"
        else
            local current_time=$(date +%s)
            if [[ $unlock_time -gt $current_time ]]; then
                local mins=$(( ($unlock_time - $current_time) / 60 ))
                echo "Unlocked ($mins min)"
            else
                echo "Unlock expired"
            fi
        fi
    else
        echo "Unencrypted"
    fi
}

# Function to get node version
get_node_version() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS -getinfo | jq -r '.version' || echo "Unknown"
}

# Function to get network type
get_network_type() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkinfo 2>/dev/null)
    echo "$info" | jq -r '.networkactive' | grep -q "true" && echo "Mainnet" || echo "Unknown"
}

# Function to get connections details
get_connections_details() {
    local peer_info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getpeerinfo 2>/dev/null)
    local total=$(echo "$peer_info" | jq -r 'length')
    local inbound=$(echo "$peer_info" | jq -r '[.[] | select(.inbound == true)] | length')
    local outbound=$((total - inbound))
    echo "$total ($inbound↓/$outbound↑)"
}

# Function to get block info
get_block_info() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS -getinfo | jq -r '.blocks' || echo "Unknown"
}

# Function to get blockchain info
get_blockchain_info() {
    local blocks=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockcount 2>/dev/null)
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockchaininfo 2>/dev/null)
    local headers=$(echo "$info" | jq -r '.headers // 0')
    echo "$blocks | $headers"
}

# Function to get sync status
get_sync_status() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockchaininfo 2>/dev/null)
    local blocks=$(echo "$info" | jq -r '.blocks // 0')
    local headers=$(echo "$info" | jq -r '.headers // 0')
    if [[ $headers -eq 0 || $blocks -eq 0 ]]; then
        echo "Unknown"
    elif [[ $blocks -lt $headers ]]; then
        local percent=$(( (blocks * 100) / headers ))
        echo "$percent%"
    else
        echo "100%"
    fi
}

# Function to get difficulty
get_difficulty() {
    local diff=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS -getinfo | jq -r '.difficulty' || echo "Unknown")
    
    # Check if we got a valid number
    if [[ -n "$diff" && "$diff" != "Unknown" ]]; then
        # Split at decimal point
        local diff_integer=$(echo "$diff" | cut -d'.' -f1)
        local diff_decimal=$(echo "$diff" | cut -d'.' -f2 | cut -c1-6)  # Take first 6 decimal places
        
        # Add commas to integer part
        local formatted_diff_integer=$(printf "%'d" $diff_integer)
        
        # Combine back with decimal portion
        printf "%s.%s" "$formatted_diff_integer" "$diff_decimal"
    else
        echo "Unknown"
    fi
}

# Function to get network hashrate
get_network_hashps() {
    local hashps=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkhashps 2>/dev/null || echo "0")
    # Format hashrate based on size
    if (( $(echo "$hashps > 1000000000" | bc -l) )); then
        printf "%.2f GH/s" $(echo "$hashps/1000000000" | bc -l)
    elif (( $(echo "$hashps > 1000000" | bc -l) )); then
        printf "%.2f MH/s" $(echo "$hashps/1000000" | bc -l)
    elif (( $(echo "$hashps > 1000" | bc -l) )); then
        printf "%.2f KH/s" $(echo "$hashps/1000" | bc -l)
    else
        printf "%.2f H/s" $hashps
    fi
}

# Function to get mempool info
get_mempool_info() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getmempoolinfo 2>/dev/null)
    local tx_count=$(echo "$info" | jq -r '.size.memory // 0')
    local bytes=$(echo "$info" | jq -r '.bytes // 0')
    local mb=$(echo "scale=1; $bytes/1048576" | bc)
    echo "$tx_count txs ($mb MB)"
}
# Function to get stake time
get_stake_time() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakinginfo | jq -r '.["stake-time"]' || echo "Unknown"
}

# Function to get staking info
get_staking_info() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakinginfo 2>/dev/null)
    local status=$(echo "$info" | jq -r '.staking')
    local weight=$(echo "$info" | jq -r '.weight')
    local netweight=$(echo "$info" | jq -r '.netstakeweight')
    local expected=$(echo "$info" | jq -r '.expectedtime')
    
    # Convert satoshis to coins (1 coin = 100,000,000 satoshis)
    local coins_weight=$(echo "scale=8; $weight/100000000" | bc)
    local coins_netweight=$(echo "scale=8; $netweight/100000000" | bc)
    
    # Format with commas left of decimal point
    # First, split at decimal point
    local weight_integer=$(echo "$coins_weight" | cut -d'.' -f1)
    local weight_decimal=$(echo "$coins_weight" | cut -d'.' -f2)
    local netweight_integer=$(echo "$coins_netweight" | cut -d'.' -f1)
    local netweight_decimal=$(echo "$coins_netweight" | cut -d'.' -f2)
    
    # Add commas to integers with printf
    local formatted_weight_integer=$(printf "%'d" $weight_integer)
    local formatted_netweight_integer=$(printf "%'d" $netweight_integer)
    
    # Combine back with decimal portion
    local formatted_weight="${formatted_weight_integer}.${weight_decimal}"
    local formatted_netweight="${formatted_netweight_integer}.${netweight_decimal}"
    
    # Calculate percentage
    local percentage=0
    if (( $(echo "$netweight > 0" | bc -l) )); then
        percentage=$(echo "scale=2; ($weight * 100) / $netweight" | bc)
    fi
    
    # Format status
    if [[ "$status" == "true" ]]; then
        status="ACTIVE"
    else
        status="INACTIVE"
    fi
    
    # Format expected time
    local formatted_expected
    if (( expected > 86400 )); then
        local days=$(( expected / 86400 ))
        local hours=$(( (expected % 86400) / 3600 ))
        formatted_expected="${days}d${hours}h"
    elif (( expected > 3600 )); then
        local hours=$(( expected / 3600 ))
        local minutes=$(( (expected % 3600) / 60 ))
        formatted_expected="${hours}h${minutes}m"
    elif (( expected > 0 )); then
        local minutes=$(( expected / 60 ))
        formatted_expected="${minutes}m"
    else
        formatted_expected="unknown"
    fi
    
    echo "$status | Weight: $formatted_weight/$formatted_netweight ($percentage%) | Next: ~$formatted_expected"
}
# Function to get last stake reward time
get_last_stake_reward() {
    local last_stake_time=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null | grep "Latest Time" | awk -F': ' '{print $2}' | tr -d '",' )
    
    if [[ -z "$last_stake_time" || "$last_stake_time" == "0" ]]; then
        echo "Never"
        return
    fi
    
    # Convert ISO 8601 date format to Unix timestamp
    local last_stake_ts=$(date -d "$last_stake_time" +%s)
    local now=$(date +%s)
    local diff=$((now - last_stake_ts))
    format_time_difference $diff
}

# Function to get net stake weight
get_net_stake_weight() {
    local info=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakinginfo 2>/dev/null)
    local netweight=$(echo "$info" | jq -r '.netstakeweight')
    
    # Convert satoshis to coins (1 coin = 100,000,000 satoshis)
    local coins_netweight=$(echo "scale=8; $netweight/100000000" | bc)
    
    # Format with commas left of decimal point
    # Split at decimal point
    local netweight_integer=$(echo "$coins_netweight" | cut -d'.' -f1)
    local netweight_decimal=$(echo "$coins_netweight" | cut -d'.' -f2)
    
    # Add commas to integer with printf
    local formatted_netweight_integer=$(printf "%'d" $netweight_integer)
    
    # Combine back with decimal portion
    echo "${formatted_netweight_integer}.${netweight_decimal}"
}

# Function to get memory usage information (compact version)
get_memory_usage_info() {
    local mem_info=$(free -h | awk 'NR==2 {print $3"/"$2" ("$3/$2*100"%)";}' | sed 's/%)/%)/')
    echo "$mem_info"
}

# Function to get page size
get_page_size() {
    local page_size=$(getconf PAGE_SIZE 2>/dev/null || echo "Unknown")
    # Format page size in KiB
    if [ "$page_size" != "Unknown" ]; then
        printf "%.2f KiB" $(echo "$page_size/1024" | bc -l)
    else
        echo "Unknown"
    fi
}

# Function to get free memory details
get_free_memory() {
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    
    # Format in MiB
    if [ -n "$mem_available" ] && [ -n "$mem_free" ]; then
        local avail_mb=$(echo "scale=2; $mem_available/1024" | bc)
        local free_mb=$(echo "scale=2; $mem_free/1024" | bc)
        echo "Avail: ${avail_mb} MiB, Free: ${free_mb} MiB"
    else
        echo "Unknown"
    fi
}

# Function to get stake report
get_stake_report() {
    local report=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null)
    
    # Extract data using jq instead of grep since we're working with JSON
    local last24=$(echo "$report" | jq -r '."Last 24H"' || echo "0")
    local last7d=$(echo "$report" | jq -r '."Last 7 Days"' || echo "0")
    local last30d=$(echo "$report" | jq -r '."Last 30 Days"' || echo "0")
    local last365d=$(echo "$report" | jq -r '."Last 365 Days"' || echo "0")
    local count=$(echo "$report" | jq -r '."Stake counted"' || echo "0")

    # Ensure the values are explicitly set to 0 if empty
    last24=${last24:-0}
    last7d=${last7d:-0}
    last30d=${last30d:-0}
    last365d=${last365d:-0}
    count=${count:-0}

    echo "24h: $last24 | 7d: $last7d | 30d: $last30d | 365d: $last365d | Count: $count"
}
# Function to get node uptime
get_node_uptime() {
    local uptime_seconds=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS uptime 2>/dev/null || echo "0")
    format_time_difference $uptime_seconds
}

# Function to get disk usage
get_disk_usage() {
    local blockchain_dir="$HOME/.pocketcoin"
    if [ -d "$blockchain_dir" ]; then
        local usage=$(du -sh "$blockchain_dir" 2>/dev/null | cut -f1)
        local avail=$(df -h "$blockchain_dir" | awk 'NR==2 {print $4}')
        local used=$(df -h "$blockchain_dir" | awk 'NR==2 {print $3}')
        local total=$(df -h "$blockchain_dir" | awk 'NR==2 {print $2}')
        local percent=$(df -h "$blockchain_dir" | awk 'NR==2 {print $5}')
        echo "$used/$total ($percent)"
    else
        echo "Unknown"
    fi
}

# Function to get CPU usage
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}'
}

# Function to get memory usage
get_memory_usage() {
    free -h | awk 'NR==2 {print "Total: " $2 ", Used: " $3 ", Free: " $4}'
}

# Function to get debug log
get_debug_log() {
    local log_file="$HOME/.pocketcoin/debug.log"
    if [ -f "$log_file" ]; then
        tail -n 5 "$log_file" | while read -r line; do
            local timestamp=$(echo "$line" | awk '{print $1 " " $2}')
            local content=$(echo "$line" | cut -d' ' -f3-)
            echo "$timestamp $content"
        done
    else
        echo "Debug log file not found"
    fi
}

# Function to display the last 5 lines of the probe_nodes.log if it exists
display_probe_nodes_log() {
    local log_file="$HOME/probe_nodes/probe_nodes.log"
    if [ -f "$log_file" ]; then
        echo "── probe_nodes.log ──"
        tail -n 3 "$log_file" | while read -r line; do
            local timestamp=$(echo "$line" | awk '{print $1 " " $2}')
            local content=$(echo "$line" | cut -d' ' -f3-)
            echo "$timestamp $content"
        done
    fi
}

# Helper function to create a boxed section
create_boxed_section() {
    local title="$1"
    shift
    local content=("$@")
    
    # Calculate the maximum content width
    local max_content_width=0
    for line in "${content[@]}"; do
        if [ ${#line} -gt $max_content_width ]; then
            max_content_width=${#line}
        fi
    done
    
    # Calculate content line width including borders
    local full_line_width=$((max_content_width + 4)) # +4 for "│ " and " │"
    
    # Calculate internal width (without the border characters)
    local internal_width=$((full_line_width - 2))
    
    # Create the title part
    local title_part="─ $title "
    
    # Calculate remaining dashes needed after title
    local remaining_dashes=$((internal_width - ${#title_part}))
    
    # Top border with title
    printf "┌%s%s┐\n" "$title_part" "$(printf '─%.0s' $(seq 1 $remaining_dashes))"
    
    # Content lines
    for line in "${content[@]}"; do
        printf "│ %-${max_content_width}s │\n" "$line"
    done
    
    # Bottom border - exactly matching the top border width
    printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $internal_width))"
}
# Function to display boxed UI
display_boxed_ui() {
    # Node Status Box
    node_status=$(printf "Node: v%-8s | Net: %-8s | Conns: %-14s | Sync: %-6s | Uptime: %-8s" \
           "$(get_node_version)" "$(get_network_type)" "$(get_connections_details)" \
           "$(get_sync_status)" "$(get_node_uptime)")
    create_boxed_section "Node Status" "$node_status"
    
    # Blockchain Box
    blockchain_line1=$(printf "Blocks: %-10s | Difficulty: %-10s | Hash: %-20s" \
           "$(get_block_info)" "$(get_difficulty)" "$(get_network_hashps)")
    blockchain_line2=$(printf "Mempool: %-30s | NetStakeWeight: %-28s" \
           "$(get_mempool_info)" "$(get_net_stake_weight)")
    create_boxed_section "Blockchain" "$blockchain_line1" "$blockchain_line2"
    
    # Wallet Box
    local addr=$(get_highest_balance_address)
    # Show full address instead of truncating
    wallet_status=$(printf "Addr: %-42s | Balance: %-12s | Unconf: %-10s" \
           "$addr" "$(get_wallet_info)" "$(get_unconfirmed_balance)")
    wallet_status2=$(printf "Status: %-72s" \
           "$(get_wallet_status)")
    create_boxed_section "Wallet" "$wallet_status" "$wallet_status2"
    
    # Staking Box - show values even if zero
    staking_line1=$(printf "%-56s | Last: %-8s" \
           "$(get_staking_info || echo '0')" "$(get_last_stake_reward || echo '0')")
    staking_line2=$(printf "%-72s" \
           "$(get_stake_report || echo '0')")
    create_boxed_section "Staking" "$staking_line1" "$staking_line2"
    
    # System Resources Box - added memory info
    memory_info=$(get_memory_usage_info)
    system_resources=$(printf "Disk: %-20s | CPU: %-10s | Mem: %-20s" \
           "$(get_disk_usage)" "$(get_cpu_usage)" "$memory_info")
    system_resources2=$(printf "Page Size: %-20s | Free Mem: %-30s" \
           "$(get_page_size)" "$(get_free_memory)")
    create_boxed_section "System Resources" "$system_resources" "$system_resources2"
    
    # Log Entries Box
    log_entries=()
    while read -r line; do
        log_entries+=("$line")
    done < <(get_debug_log)
    create_boxed_section "Log Entries" "${log_entries[@]}"
    
    # Probe nodes log if exists
    display_probe_nodes_log
}

# Function to display compact UI (no boxes)
display_compact_ui() {
    # Date and basic info
    printf "%-20s | %-12s | %-20s | %-12s | %-12s\n" \
           "Node: v$(get_node_version)" "Net: $(get_network_type)" \
           "Conns: $(get_connections_details)" "Sync: $(get_sync_status)" "Up: $(get_node_uptime)"
    # Blockchain info
    printf "%-20s | %-18s | %-21s | %s\n" \
           "Blocks: $(get_block_info)" "Difficulty: $(get_difficulty)" \
           "Hash: $(get_network_hashps)" "Mempool: $(get_mempool_info)"
    # Wallet info
    local addr=$(get_highest_balance_address)
    local short_addr="${addr:0:6}...${addr: -6}"
    printf "%-20s | %-16s | %-16s | %s\n" \
           "Addr: $short_addr" "Balance: $(get_wallet_info)" \
           "Unconf: $(get_unconfirmed_balance)" "Status: $(get_wallet_status)"
    # Staking info
    printf "%s | Last: %s\n" \
           "$(get_staking_info)" "$(get_last_stake_reward)"
    printf "%s\n" "$(get_stake_report)"
    # System resources
    printf "%-20s | %-12s\n" \
           "Disk: $(get_disk_usage)" "CPU: $(get_cpu_usage)"
    # Memory usage
    get_memory_usage
    # Debug log
    echo "-- Last log entries --"
    get_debug_log
    # Probe nodes log
    display_probe_nodes_log
}

# Function to display metrics
display_metrics() {
    if [ "$USE_BOXED_UI" = true ]; then
        display_boxed_ui
    else
        display_compact_ui
    fi
}

# Function to display help
display_help() {
    echo "Pocketnet Watch Script - Enhanced Version"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Display this help message"
    echo "  -b, --boxed       Use boxed UI (default: enabled)"
    echo "  -c, --compact     Use compact UI without boxes"
    echo "  -r, --refresh N   Set refresh interval to N seconds (default: 5)"
    echo "  --clear N         Clear screen every N cycles (default: 15)"
    echo "  --box-width N     Set default width for UI boxes (default: 80)"
    echo ""
    echo "Press Ctrl+C to exit"
    exit 0
}

# Function to format time difference
format_time_difference() {
    local diff=$1
    if (( diff > 86400 )); then
        local days=$(( diff / 86400 ))
        local hours=$(( (diff % 86400) / 3600 ))
        echo "${days}d${hours}h"
    elif (( diff > 3600 )); then
        local hours=$(( diff / 3600 ))
        local minutes=$(( (diff % 3600) / 60 ))
        echo "${hours}h${minutes}m"
    elif (( diff > 0 )); then
        local minutes=$(( diff / 60 ))
        echo "${minutes}m"
    else
        echo "unknown"
    fi
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) display_help ;;
        -b|--boxed) USE_BOXED_UI=true ;;
        -c|--compact) USE_BOXED_UI=false ;;
        -r|--refresh) REFRESH_SECONDS="$2"; shift ;;
        --clear) CLEAR_CYCLES="$2"; shift ;;
        --box-width) DEFAULT_BOX_WIDTH="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Main loop
clear
counter=0
tput civis # Hide the cursor
trap 'tput cnorm; echo ""; echo "Exiting..."; exit 0' INT TERM EXIT

clear_screen() {
    clear
    counter=0
    echo "Screen cleared."
}

while true; do
    tput cup 0 0
    display_metrics
    sleep $REFRESH_SECONDS
    counter=$((counter + 1))
    if [ $counter -eq $CLEAR_CYCLES ]; then
        clear_screen
    fi
done
