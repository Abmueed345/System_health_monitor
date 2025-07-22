#!/bin/bash

refresh_rate=3
log_file="system_monitor_simple.log"
interface="eth0"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to log alerts
log_anomaly() {
    echo "$(date '+%F %T') - $1" >> "$log_file"
}

# Visual Bar Generator
draw_bar() {
    usage=$1
    label=$2
    bar_length=30
    fill_count=$(( usage * bar_length / 100 ))
    empty_count=$(( bar_length - fill_count ))

    if (( usage < 60 )); then
        color=$GREEN
    elif (( usage < 85 )); then
        color=$YELLOW
    else
        color=$RED
    fi

    bar=$(printf "%${fill_count}s" | tr ' ' '█')
    space=$(printf "%${empty_count}s")

    echo -e "$label: ${color}[${bar}${space}] $usage%${NC}"

    if [[ "$label" == "CPU" && $usage -ge 85 ]]; then
        log_anomaly "High CPU usage: $usage%"
    elif [[ "$label" == "MEM" && $usage -ge 85 ]]; then
        log_anomaly "High Memory usage: $usage%"
    elif [[ "$label" == "DISK" && $usage -ge 90 ]]; then
        log_anomaly "Disk almost full: $usage% used"
    fi
}

while true; do
    clear
    echo -e "${YELLOW}=== System Monitor Dashboard (every ${refresh_rate}s) ===${NC}"
    echo "Press Ctrl+C to exit"
    echo ""

    # CPU
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    cpu_usage=$((100 - cpu_idle))
    draw_bar "$cpu_usage" "CPU"

    # Memory
    mem_line=$(free | grep Mem)
    total_mem=$(echo "$mem_line" | awk '{print $2}')
    used_mem=$(echo "$mem_line" | awk '{print $3}')
    mem_usage=$((used_mem * 100 / total_mem))
    draw_bar "$mem_usage" "MEM"

    # Disk
    disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    draw_bar "$disk_usage" "DISK"

    # Network Usage
    rx1=$(cat /sys/class/net/*/statistics/rx_bytes | paste -sd+ - | bc)
    tx1=$(cat /sys/class/net/*/statistics/tx_bytes | paste -sd+ - | bc)

    if [ -d "/sys/class/net/$interface" ]; then
        eth_rx1=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        eth_tx1=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    else
        eth_rx1=0
        eth_tx1=0
    fi

    sleep 1

    rx2=$(cat /sys/class/net/*/statistics/rx_bytes | paste -sd+ - | bc)
    tx2=$(cat /sys/class/net/*/statistics/tx_bytes | paste -sd+ - | bc)
    rx_kbps=$(((rx2 - rx1)/1024))
    tx_kbps=$(((tx2 - tx1)/1024))

    eth_rx2=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
    eth_tx2=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
    eth_rx_kbps=$(((eth_rx2 - eth_rx1)/1024))
    eth_tx_kbps=$(((eth_tx2 - eth_tx1)/1024))

    echo ""
    echo -e "${GREEN}Network Total RX:${NC} ${rx_kbps} KB/s    ${GREEN}TX:${NC} ${tx_kbps} KB/s"
    echo -e "${GREEN}Home ($interface) RX:${NC} ${eth_rx_kbps} KB/s    ${GREEN}TX:${NC} ${eth_tx_kbps} KB/s"

    echo ""
    echo -e "${YELLOW}Recent Alerts:${NC}"
    if [ -f "$log_file" ]; then
        tail -n 5 "$log_file"
    else
        echo "No alerts yet."
    fi

    sleep "$refresh_rate"
done

