#!/bin/bash

# Installation script for Robot Startup Automation
# This script performs the steps listed in the Installation section of the README

# Exit on any error
set -e

echo "Starting installation of Robot Startup Automation..."

# Step 1: Make startup script executable
echo "Making startup script executable..."
chmod +x /home/ubuntu/launch_robot/start_robot.py

# Step 2: Copy systemd service file
echo "Copying systemd service file to system directory..."
sudo cp /home/ubuntu/launch_robot/robot_startup.service /etc/systemd/system/

# Step 3: Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Step 4: Enable service to start on boot
echo "Enabling service to start on boot..."
sudo systemctl enable robot_startup.service

echo "Installation completed successfully!"
echo "The robot startup service will run automatically on next boot."
echo "To start it now without rebooting, run: sudo systemctl start robot_startup.service" 