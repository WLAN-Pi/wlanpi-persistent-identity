#!/bin/bash
# Update wlanpi-persistent-identity.service to depend on expand-home-partition.service
#
# This script fixes the service dependency order to ensure the home partition
# is expanded before persistent identity bind mounts are created.
#
# Usage:
#   chmod +x fix-home-expansion-deps
#   sudo ./fix-home-expansion-deps

set -e

ETC_UNIT="/etc/systemd/system/wlanpi-persistent-identity.service"
LIB_UNIT="/usr/lib/systemd/system/wlanpi-persistent-identity.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

if [ -f "$ETC_UNIT" ]; then
    SERVICE_FILE="$ETC_UNIT"
elif [ -f "$LIB_UNIT" ]; then
    SERVICE_FILE="$LIB_UNIT"
else
    echo "Error: wlanpi-persistent-identity.service not found"
    exit 1
fi

echo "Current After= line:"
CURRENT_AFTER=$(grep "^After=" "$SERVICE_FILE" || echo "")
echo "$CURRENT_AFTER"
echo

# Check if already configured
if echo "$CURRENT_AFTER" | grep -q "expand-home-partition.service"; then
    echo "Service already configured with correct dependency order."
    echo "No changes needed."
    exit 0
fi

echo "Updating $SERVICE_FILE..."
sed -i 's/^After=local-fs.target$/After=local-fs.target expand-home-partition.service/' "$SERVICE_FILE"

echo
echo "Updated After= line:"
grep "^After=" "$SERVICE_FILE"

echo
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo
echo "Done!"
echo
echo "IMPORTANT: Reboot your device for the changes to take effect:"
echo "  sudo reboot"