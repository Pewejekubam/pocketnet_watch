#!/bin/bash
# -----------------------------------------------------------------------------
# Pocketnet Watch Script - Enhanced Version
# -----------------------------------------------------------------------------
# This script monitors the status of a Pocketnet node by displaying various
# metrics and logs in a compact, organized UI. It retrieves information about
# wallet balance, node status, blockchain details, staking info, and system
# resources.
# v0.5.0
# 202503251140CST


# Default JSON configuration for UI_SECTIONS
DEFAULT_UI_SECTIONS_JSON=$(cat <<'EOF'
{
    "Node_Status": {
        "layout": [
            {
                "row": [
                    {
                        "metric": "node_version",
                        "label": "Node Version",
                        "width": 32
                    },
                    {
                        "metric": "node_time",
                        "label": "Node Time",
                        "width": 34
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "connections_details",
                        "label": "Connections",
                        "width": 32
                    },
                    {
                        "metric": "sync_status",
                        "label": "Sync Status",
                        "width": 20
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "node_uptime",
                        "label": "Uptime",
                        "width": 32
                    },
                    {
                        "metric": "network_status",
                        "label": "Network Status",
                        "width": 25
                    }
                ]
            }
        ]
    },
    "Blockchain": {
        "layout": [
            {
                "row": [
                    {
                        "metric": "blockchain_blocks",
                        "label": "Block Height",
                        "width": 32
                    },
                    {
                        "metric": "difficulty",
                        "label": "Difficulty",
                        "width": 32
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "network_hashps",
                        "label": "Hash Rate",
                        "width": 32
                    },
                    {
                        "metric": "mempool_info",
                        "label": "Memory Pool",
                        "width": 32
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "net_stake_weight",
                        "label": "Net Stake Weight",
                        "width": 60
                    }
                ]
            }
        ]
    },
    "Wallet": {
        "layout": [
            {
                "row": [
                    {
                        "metric": "wallet_balance",
                        "label": "Balance",
                        "width": 32
                    },
                    {
                        "metric": "wallet_status",
                        "label": "Status",
                        "width": 32
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "unconfirmed_balance",
                        "label": "Unconfirmed Balance",
                        "width": 32
                    },
                    {
                        "metric": "highest_balance_address",
                        "label": "Address",
                        "width": 43
                    }
                ]
            }
        ]
    },
    "Staking": {
        "layout": [
            {
                "row": [
                    {
                        "metric": "staking_status",
                        "label": "Status",
                        "width": 32
                    },
                    {
                        "metric": "staking_info",
                        "label": "Weight Ratio",
                        "width": 40
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "last_stake_reward",
                        "label": "Last Reward",
                        "width": 32
                    },
                    {
                        "metric": "expected_time",
                        "label": "Expected Time",
                        "width": 32
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "stake_report",
                        "label": "Stake Report",
                        "width": 60
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "stake_wins",
                        "label": "Stake Wins",
                        "width": 32
                    }
                ]
            }
        ]
    },
    "System_Resources": {
        "layout": [
            {
                "row": [
                    {
                        "metric": "disk_usage",
                        "label": "Disk",
                        "width": 32
                    },
                    {
                        "metric": "cpu_usage",
                        "label": "CPU",
                        "width": 25
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "memory_usage",
                        "label": "RAM",
                        "width": 48
                    },
                    {
                        "metric": "swap_memory",
                        "label": "Swap",
                        "width": 32
                    }
                ]
            },
            {
                "row": [
                    {
                        "metric": "system_uptime",
                        "label": "Uptime",
                        "width": 32
                    },
                    {
                        "metric": "load_averages",
                        "label": "Load Avg",
                        "width": 32
                    }
                ]
            }
        ]
    },
    "Debug_Log": {
        "file": {
            "path": "${HOME}/.pocketcoin/debug.log",
            "lines": 5
        }
    },
    "Probe_Nodes_Log": {
        "file": {
            "path": "${HOME}/probe_nodes/probe_nodes.log",
            "lines": 5
        }
    }
}
EOF
)

# -----------------------------------------------------------------------------
# Custom arguments for pocketcoin-cli
# Note: This argument can be an empty string if none are needed.
# POCKETCOIN_CLI_ARGS="-rpcport=67530 -conf=/path/to/pocketnet/pocketcoin.conf"
POCKETCOIN_CLI_ARGS=""
# Configuration options
USE_BOXED_UI=true     # Set to false for non-boxed UI
REFRESH_SECONDS=5     # Time between screen refreshes
CLEAR_CYCLES=15       # Clear screen every N cycles

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

# Function to format numeric values with commas and up to 8 decimal places
format_number_with_commas() {
    local value="$1"
    local integer_part=$(echo "$value" | cut -d'.' -f1)
    local decimal_part=$(echo "$value" | cut -d'.' -f2 | cut -c1-8) # Limit to 8 decimal places
    decimal_part=${decimal_part:-"00000000"} # Ensure at least 8 decimal places
    local formatted_integer=$(format_with_commas "$integer_part")
    echo "${formatted_integer}.${decimal_part}"
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
    echo "$(format_number_with_commas "$sql_balance")"
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

# Refactored function to parse node version
parse_node_version() {
    echo "$GETINFO" | jq -r '.version // "Unknown"' 2>/dev/null || echo "Unknown"
}

# Refactored function to format node version
format_node_version() {
    local version="$1"
    if [[ "$version" != "Unknown" ]]; then
        printf "v%s" "$version"
    else
        echo "$version"
    fi
}

# Refactored function to get node version
get_node_version() {
    local raw_version=$(parse_node_version)
    format_node_version "$raw_version"
}

# Refactored function to parse network status
parse_network_status() {
    echo "$NETWORK_INFO" | jq -r '.networkactive // "Unknown"' 2>/dev/null || echo "Unknown"
}

# Refactored function to format network status
format_network_status() {
    local active="$1"
    if [[ "$active" == "true" ]]; then
        echo "Active"
    elif [[ "$active" == "false" ]]; then
        echo "Inactive"
    else
        echo "Unknown"
    fi
}

# Refactored function to get network status
get_network_status() {
    local raw_status=$(parse_network_status)
    format_network_status "$raw_status"
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
    echo "$total (In:$inbound/Out:$outbound)"
}

# Refactored function to get connections details
get_connections_details() {
    local details=$(calculate_connections_details)
    format_connections_details "$details"
}

# Function to get block info
get_block_info() {
    local blocks=$(parse_block_info)
    format_block_info "$blocks"
}

# Function to get blockchain blocks
get_blockchain_blocks() {
    local blocks=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks // 0') # Correctly retrieves blocks
    echo "$blocks"
}

# Refactored function to parse sync data
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

# Refactored function to format sync status
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

# Function to get difficulty
get_difficulty() {
    local diff=$(echo "$STAKING_INFO" | jq -r '.difficulty // "Unknown"' 2>/dev/null || echo "Unknown")
    if [[ "$diff" != "Unknown" ]]; then
        echo "$(format_number_with_commas "$diff")"
    else
        echo "Unknown"
    fi
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

# Refactored function to parse staking status
parse_staking_status() {
    echo "$STAKING_INFO" | jq -r '.staking // false' 2>/dev/null || echo "false"
}

# Refactored function to format staking status
format_staking_status() {
    local status="$1"
    if [[ "$status" == "true" ]]; then
        echo "TRUE"
    else
        echo "FALSE"
    fi
}

# Refactored function to get staking status
get_staking_status() {
    local raw_status=$(parse_staking_status)
    format_staking_status "$raw_status"
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

    echo "$formatted_weight/$formatted_netweight ($percentage%)"
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
    echo "$weight_info"
}

# Function to get last stake reward time
get_last_stake_reward() {
    local last_stake_time=$(echo "$stake_wins" | jq -r '."Latest Time" // "0"')
    
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
    local netweight=$(echo "$STAKING_INFO" | jq -r '.netstakeweight // 0' 2>/dev/null || echo "0")
    if [[ "$netweight" -gt 0 ]]; then
        local coins=$(echo "scale=8; $netweight / 100000000" | bc)
        echo "$(format_number_with_commas "$coins")"
    else
        echo "Unknown"
    fi
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
get_stake_wins() {
    local wins=$(echo "$STAKE_REPORT" | jq -r '."Stake counted" // "Unknown"' 2>/dev/null || echo "Unknown")
    if [[ "$wins" != "Unknown" ]]; then
        echo "$(format_with_commas "$wins")"
    else
        echo "Unknown"
    fi
}

# Function to get node uptime
get_node_uptime() {
    local uptime_seconds=$(parse_node_uptime)
    format_node_uptime "$uptime_seconds"
}

# Function to get disk usage
get_disk_usage() {
    local blockchain_dir="$HOME/.pocketcoin"
    if [ -d "$blockchain_dir" ]; then
        local disk_data=$(df -h "$blockchain_dir" | awk 'NR==2 {print $3, $2, $5}')
        local used=$(echo "$disk_data" | awk '{print $1}')
        local total=$(echo "$disk_data" | awk '{print $2}')
        local percent=$(echo "$disk_data" | awk '{print $3}')
        echo "$used/$total ($percent)"
    else
        echo "Unknown"
    fi
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

# Function to get the highest balance wallet address
get_highest_balance_address() {
    local highest_entry=$(echo "$LISTADDRESSGROUPINGS" | jq -r '.[0][] | select(.[1] != null) | .[0] as $address | .[1] as $balance | [$address, $balance] | @csv' 2>/dev/null | sort -t, -k2 -nr | head -n 1)
    if [[ -z "$highest_entry" ]]; then
        echo "Unknown"
    else
        local address=$(echo "$highest_entry" | awk -F',' '{print $1}' | tr -d '"')
        echo "$address"
    fi
}

# Helper function to format label:value pairs with width enforcement and custom labels
format_label_value() {
    local label="$1"
    local value="$2"
    local width="$3"
    local pair="${label}: ${value}"

    # Truncate or pad the pair to fit within the specified width
    if [ ${#pair} -gt "$width" ]; then
        echo "${pair:0:$width}" # Truncate if too long
    else
        printf "%-${width}s" "$pair" # Pad with spaces if too short
    fi
}

# Updated function to create a boxed section with proper width enforcement
create_boxed_section() {
    local title="$1"
    shift
    local content=("$@")
    
    # Calculate the maximum content width
    local max_content_width=0
    for line in "${content[@]}"; do
        local line_width=$(echo -n "$line" | wc -m)
        if [ $line_width -gt $max_content_width ]; then
            max_content_width=$line_width
        fi
    done
    
    # Calculate content line width including borders
    local full_line_width=$((max_content_width + 4)) # +4 for "│ " and " │"
    local internal_width=$((full_line_width - 2))
    
    # Create the title part
    local title_part="─ $title "
    local remaining_dashes=$((internal_width - ${#title_part}))
    
    # Top border with title
    printf "┌%s%s┐\n" "$title_part" "$(printf '─%.0s' $(seq 1 $remaining_dashes))"
    
    # Content lines
    for line in "${content[@]}"; do
        printf "│ %-${max_content_width}s │\n" "$line"
    done
    
    # Bottom border
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

# Function to parse node time (updated from parse_utc_time)
parse_node_time() {
    date -u +"%Y-%m-%d %H:%M:%S"
}

# Function to format node time (updated from format_utc_time)
format_node_time() {
    local time="$1"
    echo "${time} UTC"
}

# Refactored function to get node time (updated from get_utc_time)
get_node_time() {
    local time=$(parse_node_time)
    format_node_time "$time"
}

# Updated render_section to handle row-column layout
render_section() {
    local section_name="$1"
    parse_ui_sections "$section_name"
}

# Generic function to display file content
display_file_content() {
    local file_path="$1"
    local lines="${2:-5}" # Default to 5 lines if not specified

    file_path=$(eval echo "$file_path")  # Expand ${HOME} or other variables
    if [ -f "$file_path" ]; then
        tail -n "$lines" "$file_path" || echo "Error reading file: $file_path"
    else
        echo "File not found: $file_path"
    fi
}

# Updated function to display compact UI with proper width enforcement
display_compact_ui() {
    local sections=$(echo "$UI_SECTIONS_JSON" | jq -r 'keys_unsorted[]') # Preserve JSON order
    while IFS= read -r section; do
        echo "-- $section --"
        local metrics=$(echo "$UI_SECTIONS_JSON" | jq -r --arg section "$section" '.[$section]')
        if echo "$metrics" | jq -e 'has("layout")' >/dev/null; then
            # Handle layout sections
            local rows=$(echo "$metrics" | jq -c '.layout[]')
            while IFS= read -r row; do
                local row_content=""
                local metrics=$(echo "$row" | jq -c '.row[]')
                while IFS= read -r metric; do
                    local key=$(echo "$metric" | jq -r '.metric')
                    local label=$(echo "$metric" | jq -r '.label // .metric') # Use label if provided, fallback to metric
                    local width=$(echo "$metric" | jq -r '.width')
                    local value=$(get_${key} 2>/dev/null || echo "N/A")
                    row_content+=$(format_label_value "$label" "$value" "$width")"  "
                done <<< "$metrics"
                echo "$row_content"
            done <<< "$rows"
        elif echo "$metrics" | jq -e 'has("file")' >/dev/null; then
            # Handle file sections
            local file_path=$(echo "$metrics" | jq -r '.file.path')
            local lines=$(echo "$metrics" | jq -r '.file.lines')
            file_path=$(eval echo "$file_path")  # Expand ${HOME} or other variables
            display_file_content "$file_path" "$lines"
        else
            # Handle simple metrics
            local simple_metrics=$(echo "$metrics" | jq -r 'keys[]')
            for metric in $simple_metrics; do
                local value=$(get_${metric} 2>/dev/null || echo "N/A")
                printf "%-20s: %s\n" "$metric" "$value"
            done
        fi
        echo ""
    done <<< "$sections"
}

# Main UI renderer
render_ui() {
    local sections=$(echo "$UI_SECTIONS_JSON" | jq -r 'keys_unsorted[]') # Dynamically fetch section names
    while IFS= read -r section; do
        render_section "$section" # Ensure section name is quoted
    done <<< "$sections" | while read -r line; do echo "$line"; done
}

# Function to display metrics
display_metrics() {
    if [ "$USE_BOXED_UI" = true ]; then
        render_ui
    else
        display_compact_ui
    fi
}

# Function to display help
display_help() {
    echo "Pocketnet Watch Script - Enhanced Version"
    echo ""
    echo "This script monitors the status of a Pocketnet node and displays various"
    echo "metrics in a user-friendly UI. It retrieves information about wallet balance,"
    echo "node status, blockchain details, staking info, and system resources."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Display this help message and exit."
    echo "  -b, --boxed       Use boxed UI with borders (default: enabled)."
    echo "  -c, --compact     Use compact UI without borders (overrides --boxed)."
    echo "  -r, --refresh N   Set the refresh interval to N seconds (default: 5)."
    echo "  --clear N         Clear the screen every N refresh cycles (default: 15)."
    echo ""
    echo "Configuration:"
    echo "  The 'POCKETCOIN_CLI_ARGS' variable can be edited directly in the script"
    echo "  to pass custom arguments to the 'pocketcoin-cli' command. For example:"
    echo "      POCKETCOIN_CLI_ARGS=\"-rpcport=67530 -conf=/path/to/pocketcoin.conf\""
    echo ""
    echo "Dependencies:"
    echo "  - jq: JSON processor (required)."
    echo "  - bc: Command-line calculator (required)."
    echo ""
    echo "Examples:"
    echo "  Run with default settings:"
    echo "      $0"
    echo ""
    echo "  Run with compact UI and a 10-second refresh interval:"
    echo "      $0 --compact --refresh 10"
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
        STAKE_REPORT=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null || echo "{}") # Fix variable name
        LISTADDRESSGROUPINGS=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS listaddressgroupings 2>/dev/null || echo "[]")
    fi
}

# Function to parse stake count
parse_stake_count() {
    echo "$stake_wins" | jq -r '."Stake counted"' || echo "0"
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

# Function to parse node uptime
parse_node_uptime() {
    pocketcoin-cli $POCKETCOIN_CLI_ARGS uptime 2>/dev/null || echo "0"
}

# Function to format node uptime
format_node_uptime() {
    local uptime_seconds="$1"
    if [[ "$uptime_seconds" -eq 0 ]]; then
        echo "N/A"
    else
        local days=$((uptime_seconds / 86400))
        local hours=$(( (uptime_seconds % 86400) / 3600 ))
        local minutes=$(( (uptime_seconds % 3600) / 60 ))
        echo "${days}d ${hours}h ${minutes}m"
    fi
}

# Refactored function to get node uptime
get_node_uptime() {
    local uptime_seconds=$(parse_node_uptime)
    format_node_uptime "$uptime_seconds"
}

# Function to parse expected time
parse_expected_time() {
    echo "$STAKING_INFO" | jq -r '.expectedtime // 0' 2>/dev/null || echo "0"
}

# Function to format expected time
format_expected_time() {
    local expected_seconds="$1"
    if [[ "$expected_seconds" -eq 0 ]]; then
        echo "N/A"
    else
        if (( expected_seconds > 86400 )); then
            local days=$(( expected_seconds / 86400 ))
            local hours=$(( (expected_seconds % 86400) / 3600 ))
            echo "~${days}d${hours}h"
        elif (( expected_seconds > 3600 )); then
            local hours=$(( expected_seconds / 3600 ))
            local minutes=$(( (expected_seconds % 3600) / 60 ))
            echo "~${hours}h${minutes}m"
        elif (( expected_seconds > 0 )); then
            local minutes=$(( expected_seconds / 60 ))
            echo "~${minutes}m"
        else
            echo "unknown"
        fi
    fi
}

# Refactored function to get expected time
get_expected_time() {
    local expected_seconds=$(parse_expected_time)
    format_expected_time "$expected_seconds"
}

# Function to format staking report
format_stake_report() {
    local report="$1"
    local last_24h=$(echo "$report" | jq -r '."Last 24H" // null')
    local last_7d=$(echo "$report" | jq -r '."Last 7 Days" // null')
    local last_30d=$(echo "$report" | jq -r '."Last 30 Days" // null')
    local last_365d=$(echo "$report" | jq -r '."Last 365 Days" // null')

    # Format each value to two decimal places with commas if it exists
    local formatted_report=""
    [[ "$last_24h" != "null" ]] && formatted_report+="1D: $(printf "%'.2f" "$last_24h")"
    [[ "$last_7d" != "null" ]] && formatted_report+=" | 7D: $(printf "%'.2f" "$last_7d")"
    [[ "$last_30d" != "null" ]] && formatted_report+=" | 30D: $(printf "%'.2f" "$last_30d")"
    [[ "$last_365d" != "null" ]] && formatted_report+=" | 1Y: $(printf "%'.2f" "$last_365d")"

    echo "$formatted_report"
}

# Refactored function to get stake report
get_stake_report() {
    local report=$(echo "$STAKE_REPORT" | jq -r '.' 2>/dev/null || echo "{}")
    format_stake_report "$report"
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

# Function to load UI_SECTIONS configuration
load_ui_sections_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        # Validate and load external JSON configuration
        if jq empty "$config_file" 2>/dev/null; then
            UI_SECTIONS_JSON=$(cat "$config_file")
        else
            echo "Invalid JSON in $config_file. Falling back to default configuration."
            UI_SECTIONS_JSON="$DEFAULT_UI_SECTIONS_JSON"
        fi
    else
        # Use default embedded configuration
        UI_SECTIONS_JSON="$DEFAULT_UI_SECTIONS_JSON"
    fi
}

# Function to validate JSON structure
validate_ui_sections_json() {
    local json="$1"
    if ! echo "$json" | jq -e '.' >/dev/null 2>&1; then
        echo "Invalid JSON structure."
        return 1
    fi
    return 0
}

# Updated function to parse and render UI_SECTIONS with optional labels
parse_ui_sections() {
    local section_name="$1"
    local section_json=$(echo "$UI_SECTIONS_JSON" | jq -r --arg name "$section_name" '.[$name]')
    if [[ -z "$section_json" || "$section_json" == "null" ]]; then
        echo "Section '$section_name' not found in configuration."
        return
    fi

    if echo "$section_json" | jq -e 'has("layout")' >/dev/null; then
        # Handle layout sections
        local rows=$(echo "$section_json" | jq -c '.layout[]')
        local content_lines=()
        while IFS= read -r row; do
            local row_content=""
            local metrics=$(echo "$row" | jq -c '.row[]')
            while IFS= read -r metric; do
                local key=$(echo "$metric" | jq -r '.metric')
                local label=$(echo "$metric" | jq -r '.label // .metric') # Use label if provided, fallback to metric
                local width=$(echo "$metric" | jq -r '.width')
                local value=$(get_${key} 2>/dev/null || echo "N/A")
                row_content+=$(format_label_value "$label" "$value" "$width")
            done <<< "$metrics"
            content_lines+=("$row_content")
        done <<< "$rows"
        create_boxed_section "$section_name" "${content_lines[@]}"
    elif echo "$section_json" | jq -e 'has("file")' >/dev/null; then
        # Handle file sections``
        local file_path=$(echo "$section_json" | jq -r '.file.path')
        local lines=$(echo "$section_json" | jq -r '.file.lines')
        file_path=$(eval echo "$file_path")  # Expand ${HOME} or other variables
        local content_lines=()
        while IFS= read -r line; do
            content_lines+=("$line")
        done < <(display_file_content "$file_path" "$lines")
        create_boxed_section "$section_name" "${content_lines[@]}"
    fi
}

# Update render_section to use JSON-based configuration
render_section() {
    local section_name="$1"
    parse_ui_sections "$section_name"
}

# Main script initialization
CONFIG_FILE="${HOME}/.pocketnet_watch_config.json"
load_ui_sections_config "$CONFIG_FILE" # Fix syntax by removing parentheses

# Validate loaded configuration
if ! validate_ui_sections_json "$UI_SECTIONS_JSON"; then
    echo "Error: Invalid UI_SECTIONS configuration. Exiting."
    exit 1
fi

# Main loop
clear
echo "Initializing Pocketnet Watch Script... Please wait."
echo ""
echo "Running initial checks and commands:"
echo " - Checking jq installation... OK"
echo " - Running pocketcoin-cli getstakereport..."
stake_wins=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getstakereport 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getblockchaininfo..."
BLOCKCHAIN_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getblockchaininfo 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getnetworkinfo..."
NETWORK_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getnetworkinfo 2>/dev/null || echo "{}")
echo " - Running pocketcoin-cli getwalletinfo..."
WALLET_INFO=$(pocketcoin-cli $POCKETCOIN_CLI_ARGS getwalletinfo 2>/dev/null || echo "{}")
echo ""
echo "Initialization complete. Starting the script..."
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
    cache_pocketcoin_data
    tput cup 0 0
    display_metrics
    sleep $REFRESH_SECONDS
    counter=$((counter + 1))
    if [ $counter -eq $CLEAR_CYCLES ]; then
        clear_screen
    fi
done