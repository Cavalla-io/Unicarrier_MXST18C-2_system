#!/bin/bash

# Installation script for auto-identification of serial devices

# Get the real path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the identification script is executable
echo "Making sure identify_serial_devices.py is executable..."
chmod +x "$SCRIPT_DIR/identify_serial_devices.py"

# Install systemd service
echo "Installing systemd service for startup identification..."
# Update the path in the service file
sed -i "s|ExecStart=.*|ExecStart=$SCRIPT_DIR/identify_serial_devices.py|" "$SCRIPT_DIR/auto_identify_serial.service"
sed -i "s|User=.*|User=$(whoami)|" "$SCRIPT_DIR/auto_identify_serial.service"

# Copy service file to systemd
sudo cp "$SCRIPT_DIR/auto_identify_serial.service" /etc/systemd/system/

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable auto_identify_serial.service
sudo systemctl start auto_identify_serial.service

# Install udev rule
echo "Installing udev rule for automatic identification on device connection..."
# Update the path in the udev rule
sed -i "s|RUN+=.*|RUN+=\"/bin/bash -c '$SCRIPT_DIR/identify_serial_devices.py'\"|" "$SCRIPT_DIR/99-auto-identify-usb-serial.rules"

# Copy udev rule
sudo cp "$SCRIPT_DIR/99-auto-identify-usb-serial.rules" /etc/udev/rules.d/

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Installation complete!"
echo "The identification script will now run at system startup and when new USB serial devices are connected." 