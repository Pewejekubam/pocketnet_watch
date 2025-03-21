#!/bin/bash
# -----------------------------------------------------------------------------
# Pocketnet Watch Script - Enhanced Version
# -----------------------------------------------------------------------------
# This script monitors the status of a Pocketnet node by displaying various
# metrics and logs in a compact, organized UI. It retrieves information about
# wallet balance, node status, blockchain details, staking info, and system
# resources.
# v0.4.1
# Timestamp: 2025-03-20 0816 CST
# Refining cache_pocketcoin_data function to reduce calls to pocketcoin-cli
# Timestamp: 202503210736 CST
# Finished cache optimization.  Tightening up label:value pairs display.
# Timestamp: 202503201113 CST
# Completed text box display optimization.
# fixed some formatting issues



# -----------------------------------------------------------------------------
# Custom arguments for pocketcoin-cli
# Note: This can be an empty string if no custom arguments are needed.
# POCKETCOIN_CLI_ARGS="-rpcport=67530 -conf=/path/to/pocketnet/pocketcoin.conf"
POCKETCOIN_CLI_ARGS=""
# Configuration options
USE_BOXED_UI=true     # Set to false for non-boxed UI
REFRESH_SECONDS=5     # Time between screen refreshes
CLEAR_CYCLES=15       # Clear screen every N cycles
DEFAULT_BOX_WIDTH=80  # Default width for UI boxes
PROBE_NODES_LOG_PATH="${HOME}/probe_nodes/probe_nodes.log" # Path to the probe_nodes.log file

# Check for jq and bc installation
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "bc could not be found. Please install bc."
    exit 1
fi

# Function to format numbers with commas
format_with_commas() {
    local number=$1
    printf "%'d" "$number"
}

# Function to parse wallet balance
parse_wallet_balance() {
    echo "$WALLET_INFO" | jq -r '.sql_balance' || echo "0"
}

# Function to calculate wallet balance
calculate_wallet_balance() {
    local sql_balance="$1"
    if [[ -z "$sql_balance" || "$sql_balance" == "null" || "$sql_balance" == "0" ]]; then
        echo "0 00000000"
    else
        local balance_integer=$(echo "$sql_balance" | cut -d'.' -f1)
        local balance_decimal=$(echo "$sql_balance" | cut -d'.' -f2)
        balance_decimal=${balance_decimal:-"00000000"} # Ensure at least 8 decimal places
        echo "$balance_integer $balance_decimal"
    fi
}

# Function to format wallet balance
format_wallet_balance() {
    local balance_integer="$1"
    local balance_decimal="$2"
    local formatted_integer=$(format_with_commas "$balance_integer")
    echo "${formatted_integer}.${balance_decimal}"
}

# Refactored function to get wallet balance
get_wallet_balance() {
    local sql_balance=$(parse_wallet_balance)
    local balance_parts=$(calculate_wallet_balance "$sql_balance")
    local balance_integer=$(echo "$balance_parts" | awk '{print $1}')
    local balance_decimal=$(echo "$balance_parts" | awk '{print $2}')
    format_wallet_balance "$balance_integer" "$balance_decimal"
}

# Function to get wallet info
get_wallet_info() {
    echo "$WALLET_INFO" | jq -r '.balance' || echo "Unknown"
}

# Function to get unconfirmed balance
get_unconfirmed_balance() {
    echo "$WALLET_INFO" | jq -r '.unconfirmed_balance' || echo "0"
}

# Function to calculate wallet status
calculate_wallet_status() {
    if [[ $(echo "$WALLET_INFO" | jq -r 'has("unlocked_until")') == "true" ]]; then
        local unlock_time=$(echo "$WALLET_INFO" | jq -r '.unlocked_until')
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

# Function to format wallet status
get_wallet_status() {
    local status=$(calculate_wallet_status)
    echo "$status"
}

# Function to get node version
get_node_version() {
    echo "$GETINFO" | jq -r '.version' || echo "Unknown"
}

# Function to get network type
get_network_type() {
    echo "$NETWORK_INFO" | jq -r '.networkactive' | grep -q "true" && echo "Mainnet" || echo "Unknown"
}

# Function to calculate connections details
calculate_connections_details() {
    local total=$(echo "$NETWORK_INFO" | jq -r '.connections // 0' 2>/dev/null || echo "0")
    local inbound=$(echo "$NETWORK_INFO" | jq -r '.connections_in // 0' 2>/dev/null || echo "0")
    local outbound=$(echo "$NETWORK_INFO" | jq -r '.connections_out // 0' 2>/dev/null || echo "0")
    echo "$total $inbound $outbound"
}

# Function to format connections details
format_connections_details() {
    local details="$1"
    local total=$(echo "$details" | awk '{print $1}')
    local inbound=$(echo "$details" | awk '{print $2}')
    local outbound=$(echo "$details" | awk '{print $3}')
    echo "$total ($inbound↓/$outbound↑)"
}

# Refactored function to get connections details
get_connections_details() {
    local details=$(calculate_connections_details)
    format_connections_details "$details"
}

# Function to get block info
get_block_info() {
    echo "$GETINFO" | jq -r '.blocks' || echo "Unknown"
}

# Function to get blockchain info
get_blockchain_info() {
    local blocks=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks // 0')
    local headers=$(echo "$BLOCKCHAIN_INFO" | jq -r '.headers // 0')
    echo "$blocks | $headers"
}

# Function to parse sync data
parse_sync_data() {
    local blocks=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks // 0')
    local headers=$(echo "$BLOCKCHAIN_INFO" | jq -r '.headers // 0')
    echo "$blocks $headers"
}

# Function to calculate sync percentage
calculate_sync_percentage() {
    local blocks="$1"
    local headers="$2"
    if [[ $headers -eq 0 || $blocks -eq 0 ]]; then
        echo "Unknown"
    elif [[ $blocks -lt $headers ]]; then
        echo $(( (blocks * 100) / headers ))
    else
        echo "100"
    fi
}

# Function to format sync status
format_sync_status() {
    local percentage="$1"
    if [[ "$percentage" == "Unknown" ]]; then
        echo "Unknown"
    else
        echo "$percentage%"
    fi
}

# Refactored function to get sync status
get_sync_status() {
    local sync_data=$(parse_sync_data)
    local blocks=$(echo "$sync_data" | awk '{print $1}')
    local headers=$(echo "$sync_data" | awk '{print $2}')
    local percentage=$(calculate_sync_percentage "$blocks" "$headers")
    format_sync_status "$percentage"
}

# Function to parse difficulty
parse_difficulty() {
    echo "$GETINFO" | jq -r '.difficulty' || echo "Unknown"
}

# Function to calculate difficulty
calculate_difficulty() {
    local diff="$1"
    if [[ -n "$diff" && "$diff" != "Unknown" ]]; then
        local diff_integer=$(echo "$diff" | cut -d'.' -f1)
        local diff_decimal=$(echo "$diff" | cut -d'.' -f2 | cut -c1-6)
        echo "$diff_integer $diff_decimal"
    else
        echo "Unknown"
    fi
}

# Function to format difficulty
format_difficulty() {
    local diff_integer="$1"
    local diff_decimal="$2"
    if [[ "$diff_integer" == "Unknown" ]]; then
        echo "Unknown"
    else
        local formatted_diff_integer=$(format_with_commas "$diff_integer")
        echo "${formatted_diff_integer}.${diff_decimal}"
    fi
}

# Refactored function to get difficulty
get_difficulty() {
    local diff=$(parse_difficulty)
    local diff_parts=$(calculate_difficulty "$diff")
    local diff_integer=$(echo "$diff_parts" | awk '{print $1}')
    local diff_decimal=$(echo "$diff_parts" | awk '{print $2}')
    format_difficulty "$diff_integer" "$diff_decimal"
}

# Function to parse network hashrate
parse_network_hashps() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkhashps 2>/dev/null || echo "0"
}

# Function to format network hashrate
format_network_hashps() {
    local hashps="$1"
    if [ "$(echo "$hashps > 1000000000000" | bc -l)" -eq 1 ]; then
        printf "%.2f TH/s" $(echo "$hashps/1000000000000" | bc -l)
    elif [ "$(echo "$hashps > 1000000000" | bc -l)" -eq 1 ]; then
        printf "%.2f GH/s" $(echo "$hashps/1000000000" | bc -l)
    elif [ "$(echo "$hashps > 1000000" | bc -l)" -eq 1 ]; then
        printf "%.2f MH/s" $(echo "$hashps/1000000" | bc -l)
    elif [ "$(echo "$hashps > 1000" | bc -l)" -eq 1 ]; then
        printf "%.2f KH/s" $(echo "$hashps/1000" | bc -l)
    else
        printf "%.2f H/s" $hashps
    fi
}

# Refactored function to get network hashrate
get_network_hashps() {
    local hashps=$(parse_network_hashps)
    format_network_hashps "$hashps"
}

# Function to parse mempool info
parse_mempool_info() {
    local tx_count=$(echo "$MEMPOOL_INFO" | jq -r '.size.memory // 0' 2>/dev/null || echo "0")
    local sqlite_count=$(echo "$MEMPOOL_INFO" | jq -r '.size.sqlite // 0' 2>/dev/null || echo "0")
    local bytes=$(echo "$MEMPOOL_INFO" | jq -r '.bytes // 0' 2>/dev/null || echo "0")  # Memory size in bytes
    echo "$tx_count $sqlite_count $bytes"
}

# Function to format mempool info
format_mempool_info() {
    local tx_count="$1"
    local sqlite_count="$2"
    local bytes="$3"
    if [[ "$bytes" -eq 0 ]]; then
        local mb="0.0"
    else
        local mb=$(echo "scale=1; $bytes/1048576" | bc 2>/dev/null || echo "0.0")
    fi
    local combined_count=$((tx_count + sqlite_count))
    echo "$combined_count txs (${mb} MB)"
}

# Refactored function to get mempool info
get_mempool_info() {
    local mempool_data=$(parse_mempool_info)
    local tx_count=$(echo "$mempool_data" | awk '{print $1}')
    local sqlite_count=$(echo "$mempool_data" | awk '{print $2}')
    local bytes=$(echo "$mempool_data" | awk '{print $3}')
    format_mempool_info "$tx_count" "$sqlite_count" "$bytes"
}

# Function to get stake time
get_stake_time() {
    echo "$STAKING_INFO" | jq -r '.["stake-time"]' || echo "Unknown"
}

# Function to get staking status
get_staking_status() {
    local status=$(echo "$STAKING_INFO" | jq -r '.staking // false')
    if [[ "$status" == "true" ]]; then
        echo "TRUE"
    else
        echo "FALSE"
    fi
}

# Function to get staking weight and net weight
get_staking_weight() {
    local info="$STAKING_INFO"
    local weight=$(echo "$info" | jq -r '.weight')
    local netweight=$(echo "$info" | jq -r '.netstakeweight')

    # Convert satoshis to coins (1 coin = 100,000,000 satoshis)
    local coins_weight=$(echo "$weight / 100000000" | bc)
    local coins_netweight=$(echo "$netweight / 100000000" | bc)

    # Remove decimals for readability
    local formatted_weight=$(printf "%'d" "$coins_weight")
    local formatted_netweight=$(printf "%'d" "$coins_netweight")

    # Calculate percentage
    local percentage=0
    if (( netweight > 0 )); then
        percentage=$(echo "($weight * 100) / $netweight" | bc)
    fi

    echo "Weight: $formatted_weight/$formatted_netweight ($percentage%)"
}

# Function to get the next stake time
get_next_stake_time() {
    local expected=$(echo "$STAKING_INFO" | jq -r '.expectedtime')

    # Format expected time
    if (( expected > 86400 )); then
        local days=$(( expected / 86400 ))
        local hours=$(( (expected % 86400) / 3600 ))
        echo "~${days}d${hours}h"
    elif (( expected > 3600 )); then
        local hours=$(( expected / 3600 ))
        local minutes=$(( (expected % 3600) / 60 ))
        echo "~${hours}h${minutes}m"
    elif (( expected > 0 )); then
        local minutes=$(( expected / 60 ))
        echo "~${minutes}m"
    else
        echo "unknown"
    fi
}

# Refactored function to get staking info
get_staking_info() {
    local weight_info=$(get_staking_weight)
    local next_time=$(get_next_stake_time)
    echo "$weight_info | Next: $next_time"
}

# Function to get last stake reward time
get_last_stake_reward() {
    local last_stake_time=$(echo "$STAKE_REPORT" | jq -r '."Latest Time" // "0"')
    
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
    local netweight=$(echo "$STAKING_INFO" | jq -r '.netstakeweight // 0')
    
    # Convert satoshis to coins (1 coin = 100,000,000 satoshis)
    local coins_netweight=$(echo "scale=8; $netweight/100000000" | bc)
    
    # Format with commas left of decimal point
    # Split at decimal point
    local netweight_integer=$(echo "$coins_netweight" | cut -d'.' -f1)
    local netweight_decimal=$(echo "$coins_netweight" | cut -d'.' -f2)
    
    # Add commas to integer with printf
    local formatted_netweight_integer=$(format_with_commas $netweight_integer)
    
    # Combine back with decimal portion
    echo "${formatted_netweight_integer}.${netweight_decimal}"
}

# Function to get memory usage information (compact version)
get_memory_usage_info() {
    local mem_info=$(free -h | awk 'NR==2 {if ($2 != 0) print $3"/"$2" ("$3/$2*100"%)"; else print "0/0 (0%)"}' 2>/dev/null || echo "Memory Metrics: Unavailable")
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
        echo "Usable: ${avail_mb} MiB | Unused: ${free_mb} MiB"
    else
        echo "Memory Metrics: Unavailable"
    fi
}

# Function to get stake report
get_stake_report() {
    local report="$STAKE_REPORT"
    
    # Extract data using jq
    local last24=$(echo "$report" | jq -r '."Last 24H"' || echo "0.00")
    local last7d=$(echo "$report" | jq -r '."Last 7 Days"' || echo "0.00")
    local last30d=$(echo "$report" | jq -r '."Last 30 Days"' || echo "0.00")
    local last365d=$(echo "$report" | jq -r '."Last 365 Days"' || echo "0.00")
    local count=$(echo "$report" | jq -r '."Stake counted"' || echo "0")

    # Ensure the values are explicitly set to 0.00 if empty
    last24=${last24:-0.00}
    last7d=${last7d:-0.00}
    last30d=${last30d:-0.00}
    last365d=${last365d:-0.00}
    count=${count:-0}

    # Display the values with consistent precision
    printf "24h: %.8f | 7d: %.8f | 30d: %.8f | 365d: %.8f | Count: %d\n" \
        "$last24" "$last7d" "$last30d" "$last365d" "$count"
}

# Function to get node uptime
get_node_uptime() {
    # Use pocketcoin-cli uptime to get the uptime in seconds
    local uptime_seconds=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS uptime 2>/dev/null || echo "0")

    # Ensure uptime_seconds is a valid positive number
    if [[ "$uptime_seconds" -gt 0 ]]; then
        format_time_difference "$uptime_seconds"
    else
        echo "unknown"
    fi
}

# Function to get disk usage
parse_disk_usage() {
    local blockchain_dir="$HOME/.pocketcoin"
    if [ -d "$blockchain_dir" ]; then
        df -h "$blockchain_dir" | awk 'NR==2 {print $3, $2, $5}'
    else
        echo "Unknown"
    fi
}

# Function to format disk usage
format_disk_usage() {
    local disk_data="$1"
    if [[ "$disk_data" == "Unknown" ]]; then
        echo "Unknown"
    else
        local used=$(echo "$disk_data" | awk '{print $1}')
        local total=$(echo "$disk_data" | awk '{print $2}')
        local percent=$(echo "$disk_data" | awk '{print $3}')
        echo "$used/$total ($percent)"
    fi
}

# Refactored function to get disk usage
get_disk_usage() {
    local disk_data=$(parse_disk_usage)
    format_disk_usage $disk_data
}

# Function to parse CPU usage
parse_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' || echo "0"
}

# Function to format CPU usage
format_cpu_usage() {
    local usage="$1"
    printf "%.2f%%" "$usage"
}

# Refactored function to get CPU usage
get_cpu_usage() {
    local usage=$(parse_cpu_usage)
    format_cpu_usage "$usage"
}

# Function to parse memory usage
parse_memory_usage() {
    free -h | awk 'NR==2 {print $2, $3, $4}' || echo "0 0 0"
}

# Function to format memory usage
format_memory_usage() {
    local total="$1"
    local used="$2"
    local free="$3"
    echo "Total: $total, Used: $used, Free: $free"
}

# Refactored function to get memory usage
get_memory_usage() {
    local memory_data=$(parse_memory_usage)
    local total=$(echo "$memory_data" | awk '{print $1}')
    local used=$(echo "$memory_data" | awk '{print $2}')
    local free=$(echo "$memory_data" | awk '{print $3}')
    format_memory_usage "$total" "$used" "$free"
}

# Function to get debug log
get_debug_log() {
    local lines=${1:-5} # Default to 5 lines if no parameter is provided
    local log_file="$HOME/.pocketcoin/debug.log"
    if [ -f "$log_file" ]; then
        tail -n "$lines" "$log_file" || echo "Error reading log"
    else
        echo "Debug log file not found"
    fi
}

# Function to display the last N lines of the probe_nodes.log if it exists
display_probe_nodes_log() {
    local lines=${1:-5} # Default to 5 lines if no parameter is provided
    local log_file="$PROBE_NODES_LOG_PATH"
    if [ -f "$log_file" ]; then
        log_entries=()
        while read -r line; do
            log_entries+=("$line")
        done < <(tail -n "$lines" "$log_file")
        create_boxed_section "Probe Nodes Log" "${log_entries[@]}"
    else
        echo "Probe Nodes Log: Not Found"
    fi
}

# Function to get the highest balance wallet address
get_highest_balance_address() {
    local highest_entry=$(echo "$LISTADDRESSGROUPINGS" | jq -c '[.[][]] | max_by(.[1]) // null')

    if [[ "$highest_entry" != "null" ]]; then
        local highest_address=$(echo "$highest_entry" | jq -r '.[0]')
        echo "$highest_address"
    else
        echo "Unknown"
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

# Function to get swap memory usage
parse_swap_memory() {
    free -h | awk 'NR==3 {print $3"/"$2" ("$3/$2*100"%)";}'
}

# Function to format swap memory
format_swap_memory() {
    local swap_memory="$1"
    echo "$swap_memory"
}

# Refactored function to get swap memory
get_swap_memory() {
    local swap_memory=$(parse_swap_memory)
    format_swap_memory "$swap_memory"
}

# Function to get system uptime
parse_system_uptime() {
    uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1, $2}' | sed 's/^ *//;s/ *$//'
}

# Refactored function to get system uptime
get_system_uptime() {
    local uptime=$(parse_system_uptime)
    format_system_uptime "$uptime"
}

# Function to get system load averages
parse_load_averages() {
    uptime | awk -F'load average: ' '{print $2}'
}

# Function to format load averages
format_load_averages() {
    local load_averages="$1"
    echo "$load_averages"
}

# Refactored function to get load averages
get_load_averages() {
    local load_averages=$(parse_load_averages)
    format_load_averages "$load_averages"
}

# Function to parse UTC time
parse_utc_time() {
    date -u +"%Y-%m-%d %H:%M:%S"
}

# Function to format UTC time
format_utc_time() {
    local time="$1"
    echo "${time} UTC"
}

# Refactored function to get UTC time
get_utc_time() {
    local time=$(parse_utc_time)
    format_utc_time "$time"
}

# Function to display boxed UI
display_boxed_ui() {
    # Node Status Box
    node_status=$(printf "Node: v%-8s | Net: %-8s | Connections: %-14s | Sync: %-6s | Uptime: %-8s | UTC: %-20s" \
           "$(get_node_version)" "$(get_network_type)" "$(get_connections_details)" \
           "$(get_sync_status)" "$(get_node_uptime)" "$(get_utc_time)")
    create_boxed_section "Node Status" "$node_status"
    
    # Blockchain Box
    blockchain_line1=$(printf "Blocks: %-8s | Difficulty: %-14s | Hash: %-12s" \
           "$(get_block_info)" "$(get_difficulty)" "$(get_network_hashps)")
    blockchain_line2=$(printf "Mempool: %-20s | NetStakeWeight: %-22s" \
           "$(get_mempool_info)" "$(get_net_stake_weight)")
    create_boxed_section "Blockchain" "$blockchain_line1" "$blockchain_line2"
    
    # Wallet Box
    local balance=$(get_wallet_balance)
    local highest_address=$(get_highest_balance_address)
    local stake_count=$(get_stake_count)
    wallet_status=$(printf "Addr: %-34s | Status: %-20s | Unconf: %-10s" \
           "$highest_address" "$(get_wallet_status)" "$(get_unconfirmed_balance)")
    wallet_status2=$(printf "Balance: %-17s | Stake Wins: %-10s" \
           "$balance" "$stake_count")
    create_boxed_section "Wallet" "$wallet_status" "$wallet_status2"
    
    # Staking Box - show values even if zero
    staking_line1=$(printf "Staking Status: %-8s | %-60s | Last: %-8s" \
           "$(get_staking_status)" "$(get_staking_info || echo '0')" "$(get_last_stake_reward || echo '0')")
    staking_line2=$(printf "%-60s" \
           "$(get_stake_report | sed 's/| Count:.*//')")
    create_boxed_section "Staking" "$staking_line1" "$staking_line2"
    
    # System Resources Box - show values even if zero
    local disk_usage=$(get_disk_usage)
    local cpu_usage=$(get_cpu_usage)
    local memory_info=$(get_memory_usage_info)
    local swap_memory=$(get_swap_memory)
    local uptime=$(get_system_uptime)
    local load_averages=$(get_load_averages)

    system_resources=$(printf "Disk: %-18s | CPU: %-8s" "$disk_usage" "$cpu_usage")
    system_resources2=$(printf "Mem: %-20s | Swap: %-20s" "$memory_info" "$swap_memory")
    system_resources3=$(printf "Uptime: %-12s | Load: %-18s" "$uptime" "$load_averages")
    create_boxed_section "System Resources" "$system_resources" "$system_resources2" "$system_resources3"
    
    # Log Entries Box
    log_entries=()
    while read -r line; do
        log_entries+=("$line")
    done < <(get_debug_log)
    create_boxed_section "Log Entries" "${log_entries[@]}"
    
    # Probe Nodes Log Box
    display_probe_nodes_log 5
}

# Function to display compact UI (no boxes)
display_compact_ui() {
    # Date and basic info
    printf "%-20s | %-12s | %-20s | %-12s | %-12s\n" \
           "Node: v$(get_node_version)" "Net: $(get_network_type)" \
           "Connections: $(get_connections_details)" "Sync: $(get_sync_status)" "Up: $(get_node_uptime)"
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
    echo ""
    echo "Configuration:"
    echo "  The 'POCKETCOIN_CLI_ARGS' variable can be edited directly in the script"
    echo "  to pass custom arguments to the 'pocketcoin-cli' command. For example:"
    echo "      POCKETCOIN_CLI_ARGS=\"-rpcport=67530 -conf=/path/to/pocketcoin.conf\""
    echo ""
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

# Function to format system uptime
format_system_uptime() {
    local uptime="$1"
    echo "$uptime"
}

# Function to cache pocketcoin-cli data
cache_pocketcoin_data() {
    GETINFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS -getinfo 2>/dev/null || echo "{}")
    BLOCKCHAIN_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockchaininfo 2>/dev/null || echo "{}")
    NETWORK_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkinfo 2>/dev/null || echo "{}")
    MEMPOOL_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getmempoolinfo 2>/dev/null || echo "{}")
    # Less frequent commands
    if (( counter % 3 == 0 )); then
        WALLET_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo 2>/dev/null || echo "{}")
        STAKING_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakinginfo 2>/dev/null || echo "{}")
        STAKE_REPORT=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null || echo "{}")
        LISTADDRESSGROUPINGS=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS listaddressgroupings 2>/dev/null || echo "[]")
    fi
}

# Function to parse stake count
parse_stake_count() {
    echo "$STAKE_REPORT" | jq -r '."Stake counted"' || echo "0"
}

# Function to format stake count
format_stake_count() {
    local count="$1"
    echo "$count"
}

# Refactored function to get stake count
get_stake_count() {
    local count=$(parse_stake_count)
    format_stake_count "$count"
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) display_help ;;
        -b|--boxed) USE_BOXED_UI=true ;;
        -c|--compact) USE_BOXED_UI=false ;;
        -r|--refresh) REFRESH_SECONDS="$2"; shift ;;
        --clear) CLEAR_CYCLES="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Main loop
clear
echo "Initializing Pocketnet Watch Script... Please wait."
echo ""
echo "Running initial checks and commands:"
echo " - Checking jq installation... OK"
echo " - Running pocketcoin-cli getstakereport..."
STAKE_REPORT=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getblockchaininfo..."
BLOCKCHAIN_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockchaininfo 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getnetworkinfo..."
NETWORK_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkinfo 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getwalletinfo..."
WALLET_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo 2>/dev/null || echo "{}")
echo ""
echo "Initialization complete. Starting the script..."


counter=0
tput civis # Hide the cursor
trap 'tput cnorm; echo ""; echo "Exiting..."; exit 0' INT TERM EXIT

clear_screen() {
    clear
    counter=0
    echo "Screen cleared."
}

while true; do
    cache_pocketcoin_data
    tput cup 0 0
    display_metrics
    sleep $REFRESH_SECONDS
    counter=$((counter + 1))
    if [ $counter -eq $CLEAR_CYCLES ]; then
        clear_screen
    fi
done
