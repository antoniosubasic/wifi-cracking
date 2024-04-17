#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# define print function
function print() {
    local error=$1
    shift

    if [ "$error" -eq 0 ]; then
        echo -e "[${GREEN}OK${NC}] $@"
    else
        echo -e "[${RED}OK${NC}] $@"
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
    airmon-ng check kill >/dev/null
    airmon-ng start "$interface" >/dev/null
fi

print $? "monitor mode"


# set and create empty dump directory
dump_dir="/tmp/${interface}.networkdump"
mkdir -p "$dump_dir"
rm -rf "$dump_dir/*"

# scan for target network for 15 seconds
sudo airodump-ng "$interface" --essid "$target" --write "$dump_dir/dump" >/dev/null 2>&1 &
airodump_pid=$!
sleep 15
kill $airodump_pid

# evaluate scan and start handshake sniff
if [ $? -eq 0 ]; then
    network_data=$(grep "$target" "$dump_dir/dump-01.csv")
    bssid=$(echo "$network_data" | awk -F, '{print $1}')
    channel=$(echo "$network_data" | awk -F, '{gsub(/^ *| *$/, "", $4); print $4}')

    print 0 "network dump ($bssid -> $channel)"
    sleep 3

    airodump-ng -d "$bssid" -c "$channel" -w handshake "$interface"
else
    print 1 "network dump"
fi
