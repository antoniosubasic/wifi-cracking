#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# define print function
function print() {
    local error=$1
    local message=$2
    local carriage_return=${3:-false}

    local prefix="["
    if [ "$carriage_return" = true ]; then
        prefix="\r\033[K["
    fi

    if [ "$error" -eq 0 ]; then
        echo -e "$prefix${GREEN}OK${NC}] $message"
    else
        echo -e "$prefix${RED}ER${NC}] $message"
        exit 1
    fi
}


# check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "must be run as root"
    exit 1
fi

# check if target was specified
if [ -z "$1" ]; then
    echo "no target specified"
    exit 1
fi

# set target
target=$1

# set interface -> default: wlan0
interface="${2:-wlan0}"


# check if networkcard is available
iwconfig 2>/dev/null | grep -q "$interface"
print $? "network card"

# check if monitor mode is enabled
iwconfig "$interface" 2>/dev/null | grep -q "Mode:Monitor"
if [ $? -ne 0 ]; then
    printf "==> enabling monitor mode..."
    airmon-ng check kill >/dev/null
    airmon-ng start "$interface" >/dev/null
fi

print $? "monitor mode" true


# set and create directories
dump_dir="/tmp/${interface}.networkdump"
handshake_dir="/tmp/${interface}.handshake"
for dir in "$dump_dir" "$handshake_dir"; do
    [ ! -d "$dir" ] && mkdir -p "$dir"
    sudo rm -rf "$dir"/*
done

# scan for target network 3 times for 5 seconds
printf "==> scanning for '$target'..."
scan_status=1
for i in {1..3}; do
    sudo airodump-ng "$interface" --essid "$target" --write "$dump_dir/dump" >/dev/null 2>&1 &
    airodump_pid=$!
    sleep 5
    kill $airodump_pid
    if grep -q "$target" "$dump_dir/dump-0$i.csv"; then
        scan_status=0
        break
    fi
done

print $scan_status "target network found" true

network_data=$(grep "$target" "$dump_dir/dump-0$i.csv")
bssid=$(echo "$network_data" | awk -F, '{print $1}')
channel=$(echo "$network_data" | awk -F, '{gsub(/^ *| *$/, "", $4); print $4}')

print 0 "network dump ($bssid -> $channel)"
sleep 3

airodump-ng -d "$bssid" -c "$channel" -w "$handshake_dir" "$interface"
