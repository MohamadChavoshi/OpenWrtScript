#!/bin/sh

# Get list of connected devices and their MAC addresses
connected_devices=$(nmcli -a | grep -E "^\s*device\s" | awk '{print $2}')

# Choose target device by MAC address
read -p "Enter MAC address of the device you want to limit (from the list above): " target_mac

# Validate MAC address format
if ! [[ $target_mac =~ ^[0-9a-fA-F]{2}([:-]?)[0-9a-fA-F]{2}([:-]?)[0-9a-fA-F]{2}([:-]?)[0-9a-fA-F]{2}([:-]?)[0-9a-fA-F]{2}$ ]]; then
  echo "Invalid MAC address format. Please try again."
  exit 1
fi

# Check if device exists
if [[ ! $connected_devices =~ $target_mac ]]; then
  echo "Device with the specified MAC address is not connected."
  exit 1
fi

# Read desired download and upload limits
read -p "Enter Download limit (Mbps): " down_limit
read -p "Enter Upload limit (Mbps): " up_limit

# Create a new cake class for the target device
tc class add cake dev eth1 parent root classid 1
tc qdisc add cake dev eth1 leaf cake classid 1

# Assign target MAC address to the cake class
tc filter add dev eth1 parent 1 protocol mpls u32 match u32 dst-mac 0x$target_mac flowid 1:1

# Configure cake with bandwidth limits
tc cake set dev eth1 classid 1 ce-rate ${down_limit}mbit
tc cake set dev eth1 classid 1 r2q-limit ${up_limit}mbit

# Add firewall rule to drop any new connections from the target device
iptables -A OUTPUT -m mac --mac-address $target_mac -j DROP

# Save firewall rule for persistence
iptables-save

# Restart firewall to apply the rule
/etc/init.d/firewall restart

# Display confirmation message
echo "Internet usage and speed limits applied for device with MAC address $target_mac."

# (Optional) Monitor bandwidth usage using luci-sqm
sqm-scripts -l

# (Optional) Remove bandwidth limits and firewall rule
# tc qdisc del dev eth1 classid 1
# tc filter del dev eth1 parent 1 protocol mpls u32 match u32 dst-mac 0x$target_mac flowid 1:1
# iptables -D OUTPUT -m mac --mac-address $target_mac -j DROP
# iptables-save
