#!/bin/bash

# Installation script for Robot Startup Automation
# This script performs the steps listed in the Installation section of the README
# and also installs ROS2 Humble

# Exit on any error
set -e

# Get current user's home directory
USER_HOME="$HOME"
echo "Using home directory: $USER_HOME"

echo "Starting installation process..."

# Install ROS2 Humble
echo "Installing ROS2 Humble..."

# Setup sources
echo "Setting up sources for ROS2 Humble..."
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y universe
sudo apt update && sudo apt install -y curl
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update

# Install ROS2 Humble
echo "Installing ROS2 Humble packages..."
sudo apt install -y ros-humble-desktop

# Install development tools and ROS tools
echo "Installing development tools and ROS tools..."
sudo apt install -y python3-rosdep python3-colcon-common-extensions

# Initialize rosdep
echo "Initializing rosdep..."
sudo rosdep init || true  # Ignore error if already initialized
rosdep update

# Setup ROS2 environment
echo "Setting up ROS2 environment in .bashrc..."
# Check if ROS2 sourcing is already in .bashrc to avoid duplication
if ! grep -q "source /opt/ros/humble/setup.bash" ~/.bashrc; then
  echo "" >> ~/.bashrc
  echo "# ROS2 Humble environment setup" >> ~/.bashrc
  echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
  echo "# ROS2 Domain ID (uncomment and change if needed)" >> ~/.bashrc
  echo "# export ROS_DOMAIN_ID=<your_domain_id>" >> ~/.bashrc
  echo "# ROS2 middleware settings (uncomment if needed)" >> ~/.bashrc
  echo "# export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc
  echo "" >> ~/.bashrc
fi

# Source ROS2 setup for the current shell session
source /opt/ros/humble/setup.bash

echo "ROS2 Humble installation and environment setup completed."
echo

# Create required directories if they don't exist
LAUNCH_ROBOT_DIR="$USER_HOME/launch_robot"
mkdir -p "$LAUNCH_ROBOT_DIR/example-robot-docker"
echo "Created directory structure at $LAUNCH_ROBOT_DIR"

# Copy start_robot.py to the correct location
echo "Copying start_robot.py to $LAUNCH_ROBOT_DIR..."
cp start_robot.py "$LAUNCH_ROBOT_DIR/"

# Robot Startup Automation installation
echo "Starting installation of Robot Startup Automation..."

# Step 1: Make startup script executable
echo "Making startup script executable..."
chmod +x "$LAUNCH_ROBOT_DIR/start_robot.py"

# Step 2: Create and populate systemd service file
echo "Creating systemd service file..."
cat > robot_startup.service << EOL
[Unit]
Description=Robot Startup Automation
After=network.target

[Service]
ExecStart=$LAUNCH_ROBOT_DIR/start_robot.py
User=$(whoami)
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Step 3: Copy systemd service file
echo "Copying systemd service file to system directory..."
sudo cp robot_startup.service /etc/systemd/system/

# Step 4: Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Step 5: Enable service to start on boot
echo "Enabling service to start on boot..."
sudo systemctl enable robot_startup.service

# Setup Docker permissions if needed
if ! groups | grep -q "docker"; then
  echo "Adding current user to the docker group..."
  sudo usermod -aG docker $(whoami)
  echo "You'll need to log out and back in for Docker permissions to take effect"
fi

echo "Installation completed successfully!"
echo "The robot startup service will run automatically on next boot."
echo "To start it now without rebooting, run: sudo systemctl start robot_startup.service"
echo "ROS2 Humble is installed and configured." 