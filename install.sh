#!/bin/bash

# Installation script for Robot Startup Automation
# This script performs the steps listed in the Installation section of the README
# and also installs ROS2 Humble if not already installed

# Exit on any error
set -e

# Get the real user's home directory even when run with sudo
if [ "$SUDO_USER" ]; then
  REAL_USER="$SUDO_USER"
  REAL_HOME=$(eval echo ~$SUDO_USER)
else
  REAL_USER="$(whoami)"
  REAL_HOME="$HOME"
fi

echo "Installation will be performed for user: $REAL_USER"
echo "Using home directory: $REAL_HOME"

echo "Starting installation process..."

# Check if ROS2 is already installed
ROS2_INSTALLED=false
if command -v ros2 &> /dev/null; then
  echo "ROS2 command found in path. Checking version..."
  ROS2_VERSION=$(ros2 --version 2>/dev/null)
  if [[ "$ROS2_VERSION" == *"humble"* ]]; then
    echo "ROS2 Humble is already installed. Skipping ROS2 installation steps."
    ROS2_INSTALLED=true
  else
    echo "ROS2 is installed but may not be Humble version. Checking packages..."
  fi
fi

# Double check for ROS2 Humble packages if command check didn't confirm
if [ "$ROS2_INSTALLED" = false ] && dpkg -l | grep -q "ros-humble-desktop"; then
  echo "ROS2 Humble packages are installed. Skipping ROS2 installation steps."
  ROS2_INSTALLED=true
fi

# Install ROS2 Humble if not already installed
if [ "$ROS2_INSTALLED" = false ]; then
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
  
  echo "ROS2 Humble installation completed."
else
  # Even if ROS2 is installed, make sure the development tools are available
  echo "Ensuring ROS2 development tools are installed..."
  which rosdep &> /dev/null || sudo apt install -y python3-rosdep
  which colcon &> /dev/null || sudo apt install -y python3-colcon-common-extensions
fi

# Setup ROS2 environment in the real user's .bashrc
echo "Setting up ROS2 environment in $REAL_USER's .bashrc..."
BASHRC_FILE="$REAL_HOME/.bashrc"

# Check if ROS2 sourcing is already in .bashrc to avoid duplication
if ! grep -q "source /opt/ros/humble/setup.bash" "$BASHRC_FILE"; then
  echo -e "\n# ROS2 Humble environment setup" >> "$BASHRC_FILE"
  echo "source /opt/ros/humble/setup.bash" >> "$BASHRC_FILE"
  echo "# ROS2 Domain ID (uncomment and change if needed)" >> "$BASHRC_FILE"
  echo "# export ROS_DOMAIN_ID=<your_domain_id>" >> "$BASHRC_FILE"
  echo "# ROS2 middleware settings (uncomment if needed)" >> "$BASHRC_FILE"
  echo "# export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> "$BASHRC_FILE"
  echo -e "\n" >> "$BASHRC_FILE"
  echo "Added ROS2 Humble environment setup to $BASHRC_FILE"
  # Fix file ownership if run with sudo
  if [ "$SUDO_USER" ]; then
    sudo chown $REAL_USER:$REAL_USER "$BASHRC_FILE"
  fi
else
  echo "ROS2 Humble environment already set up in $BASHRC_FILE"
fi

# Source ROS2 setup for the current shell session
source /opt/ros/humble/setup.bash

echo "ROS2 Humble environment setup completed."
echo

# Define path to repository
REPO_DIR="$PWD"
echo "Using repository directory: $REPO_DIR"

# Robot Startup Automation installation
echo "Starting installation of Robot Startup Automation..."

# Step 1: Check and make startup script executable if needed
if [ -x "$REPO_DIR/start_robot.py" ]; then
  echo "Startup script is already executable."
else
  echo "Making startup script executable..."
  chmod +x "$REPO_DIR/start_robot.py"
fi

# Step 2: Check if systemd service file already exists with correct content
SERVICE_FILE="/etc/systemd/system/robot_startup.service"
SERVICE_EXISTS=false

if [ -f "$SERVICE_FILE" ]; then
  # Check if service file contains the correct path to our script
  if grep -q "$REPO_DIR/start_robot.py" "$SERVICE_FILE"; then
    echo "Systemd service file already exists with correct path."
    SERVICE_EXISTS=true
  else
    echo "Systemd service file exists but may have incorrect paths. Recreating..."
  fi
fi

if [ "$SERVICE_EXISTS" = false ]; then
  # Create and populate systemd service file
  echo "Creating systemd service file..."
  cat > robot_startup.service << EOL
[Unit]
Description=Robot Startup Automation
After=network.target

[Service]
ExecStart=$REPO_DIR/start_robot.py
User=$REAL_USER
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

  # Copy systemd service file
  echo "Copying systemd service file to system directory..."
  sudo cp robot_startup.service /etc/systemd/system/

  # Reload systemd daemon
  echo "Reloading systemd daemon..."
  sudo systemctl daemon-reload
fi

# Step 3: Check if service is already enabled
if systemctl is-enabled robot_startup.service &> /dev/null; then
  echo "Robot startup service is already enabled."
else
  echo "Enabling service to start on boot..."
  sudo systemctl enable robot_startup.service
fi

# Step 4: Setup Docker permissions if needed
if groups $REAL_USER | grep -q "docker"; then
  echo "User $REAL_USER is already in the docker group."
else
  echo "Adding user $REAL_USER to the docker group..."
  sudo usermod -aG docker $REAL_USER
  echo "You'll need to log out and back in for Docker permissions to take effect"
fi

echo "Installation completed successfully!"
echo "The robot startup service will run automatically on next boot."
echo "To start it now without rebooting, run: sudo systemctl start robot_startup.service"
echo "ROS2 Humble is installed and configured for user $REAL_USER." 