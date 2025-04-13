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

# Install dependencies required by Unicarrier_MXST18C-2 project
echo "Installing dependencies for Unicarrier_MXST18C-2..."

# Install CAN utilities if needed
echo "Installing CAN utilities..."
sudo apt-get update && sudo apt-get install -y can-utils

# Install Python dependencies
echo "Installing Python dependencies..."
sudo apt-get install -y python3-pip
# Install Python packages for the real user (not just in sudo's environment)
if [ "$SUDO_USER" ]; then
  echo "Installing Python packages for user $REAL_USER..."
  sudo -H -u $REAL_USER pip3 install --user pyserial python-can
else
  # Regular user running the script
  pip3 install --user pyserial python-can
fi

# Install ROS2 specific dependencies
echo "Installing ROS2 specific dependencies..."
sudo apt-get install -y \
  ros-humble-cv-bridge \
  ros-humble-image-transport \
  ros-humble-image-transport-plugins \
  ros-humble-image-pipeline

# Install Depthai dependencies for the camera pipeline
echo "Installing Depthai dependencies..."
sudo apt-get install -y \
  ros-humble-camera-calibration \
  ros-humble-vision-msgs

# Try to install depthai packages from apt if available
sudo apt-get install -y ros-humble-depthai ros-humble-depthai-bridge ros-humble-depthai-descriptions ros-humble-depthai-ros-msgs || {
  echo "Depthai packages not found in apt, they may need to be installed from source"
}

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

# Step 5: Setup serial port permissions for the user
echo "Setting up serial port permissions..."
if groups $REAL_USER | grep -q "dialout"; then
  echo "User $REAL_USER is already in the dialout group."
else
  echo "Adding user $REAL_USER to the dialout group for serial port access..."
  sudo usermod -aG dialout $REAL_USER
  echo "You'll need to log out and back in for serial port permissions to take effect"
fi

# Step 6: Setup sudo permissions for udev operations (and other tasks)
echo "Setting up passwordless sudo for all operations..."
SUDO_PRIVILEGES="/etc/sudoers.d/cavalla-all"

# Create a simple sudoers file that grants full access
echo "Creating full sudo privileges file..."
sudo bash -c "echo '$REAL_USER ALL=(ALL) NOPASSWD: ALL' > $SUDO_PRIVILEGES"

# Set correct permissions on the sudoers file
sudo chmod 0440 "$SUDO_PRIVILEGES"
echo "Full sudo privileges configured for $REAL_USER."

# Setup CAN bus permissions and configuration
echo "Setting up CAN bus permissions and configuration..."
if [ -f "$REPO_DIR/setup_network_privileges.sh" ]; then
  sudo bash "$REPO_DIR/setup_network_privileges.sh" "$REAL_USER"
else
  echo "Warning: setup_network_privileges.sh not found. CAN bus permissions not configured."
fi

# Explicitly enable and start CAN services
echo "Ensuring CAN services are enabled and started..."
if systemctl list-unit-files | grep -q "can-setup.service"; then
  echo "Enabling can-setup.service..."
  sudo systemctl enable can-setup.service
  echo "Starting can-setup.service..."
  sudo systemctl start can-setup.service || echo "Warning: Failed to start can-setup.service"
else
  echo "Warning: can-setup.service not found. It should be created by setup_network_privileges.sh."
fi

if systemctl list-unit-files | grep -q "can-permissions.service"; then
  echo "Enabling can-permissions.service..."
  sudo systemctl enable can-permissions.service
  echo "Starting can-permissions.service..."
  sudo systemctl start can-permissions.service || echo "Warning: Failed to start can-permissions.service"
else
  echo "Warning: can-permissions.service not found. It should be created by setup_network_privileges.sh."
fi

# Initialize CAN interface using can_tools.sh if available
if [ -f "$REPO_DIR/can_tools.sh" ]; then
  echo "Making can_tools.sh executable..."
  chmod +x "$REPO_DIR/can_tools.sh"
  echo "Starting CAN interface using can_tools.sh..."
  "$REPO_DIR/can_tools.sh" start || echo "Warning: Failed to start CAN interface with can_tools.sh"
else
  echo "Warning: can_tools.sh not found. Cannot initialize CAN interface."
fi

# Step 7: Setup automatic identification of serial devices
echo "Setting up automatic identification of serial devices..."
if [ -f "$REPO_DIR/identify_serial_devices.py" ]; then
  # Make the script executable by everyone
  echo "Making identify_serial_devices.py executable for all users..."
  chmod 755 "$REPO_DIR/identify_serial_devices.py"

  # Create systemd service file with improved settings
  echo "Creating improved systemd service for serial device identification..."
  cat > "$REPO_DIR/auto_identify_serial.service" << EOL
[Unit]
Description=Identify Serial Devices
After=systemd-udev-settle.service dev-ttyUSB0.device
Wants=systemd-udev-settle.service
Requires=systemd-udevd.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=$REPO_DIR/identify_serial_devices.py
ExecStartPost=/bin/bash -c 'ls -la /dev/throttle /dev/steering || true'
User=$REAL_USER
RemainAfterExit=yes
TimeoutSec=120
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

  # Create enhanced udev rule file for both add and remove actions
  echo "Creating enhanced udev rule for automatic identification on device connection/disconnection..."
  cat > "$REPO_DIR/99-auto-identify-usb-serial.rules" << EOL
# Run identification script when a USB serial device is added (with a delay)
SUBSYSTEM=="tty", KERNEL=="ttyUSB*", ACTION=="add", RUN+="/bin/bash -c 'sleep 3 && $REPO_DIR/identify_serial_devices.py'"

# Also clean up rules when a device is removed
SUBSYSTEM=="tty", KERNEL=="ttyUSB*", ACTION=="remove", RUN+="/bin/bash -c 'for f in /etc/udev/rules.d/99-*-\$(echo %k | sed \"s/ttyUSB//\").rules; do if [ -f \"\$f\" ]; then sudo rm \"\$f\"; fi; done && sudo udevadm control --reload-rules'"

# Create a persistent rule to ensure symlinks persist
SUBSYSTEM=="tty", KERNEL=="ttyUSB*", ACTION=="add", PROGRAM+="/bin/bash -c 'if grep -q \"SYMLINK+=\\\"steering\\\"\" /etc/udev/rules.d/99-steering.rules 2>/dev/null && grep -q \"\$(basename \$(dirname \$(readlink -f /sys\$DEVPATH)))\" /etc/udev/rules.d/99-steering.rules; then echo steering; fi'"
RESULT=="steering", SYMLINK+="steering"

SUBSYSTEM=="tty", KERNEL=="ttyUSB*", ACTION=="add", PROGRAM+="/bin/bash -c 'if grep -q \"SYMLINK+=\\\"throttle\\\"\" /etc/udev/rules.d/99-throttle.rules 2>/dev/null && grep -q \"\$(basename \$(dirname \$(readlink -f /sys\$DEVPATH)))\" /etc/udev/rules.d/99-throttle.rules; then echo throttle; fi'"
RESULT=="throttle", SYMLINK+="throttle"
EOL

  # Install systemd service with verification
  echo "Installing systemd service..."
  sudo cp "$REPO_DIR/auto_identify_serial.service" /etc/systemd/system/
  sudo chmod 644 /etc/systemd/system/auto_identify_serial.service
  sudo systemctl daemon-reload
  
  if sudo systemctl enable auto_identify_serial.service; then
    echo "Service auto_identify_serial.service enabled successfully"
    sudo systemctl start auto_identify_serial.service
    echo "Service auto_identify_serial.service started"
  else
    echo "Warning: Failed to enable auto_identify_serial.service"
  fi
  
  # Install udev rule with verification
  echo "Installing udev rule..."
  sudo cp "$REPO_DIR/99-auto-identify-usb-serial.rules" /etc/udev/rules.d/
  sudo chmod 644 /etc/udev/rules.d/99-auto-identify-usb-serial.rules
  
  if sudo udevadm control --reload-rules; then
    echo "Udev rules reloaded successfully"
    sudo udevadm trigger
    echo "Udev rules triggered"
  else
    echo "Warning: Failed to reload udev rules"
  fi
  
  # Create a systemd override to ensure the service runs on every boot
  sudo mkdir -p /etc/systemd/system/auto_identify_serial.service.d/
  echo "[Service]
ExecStartPre=/bin/sleep 5" | sudo tee /etc/systemd/system/auto_identify_serial.service.d/override.conf > /dev/null
  sudo systemctl daemon-reload
  
  # Run the identification script to set up initial device state
  echo "Running initial identification..."
  sudo -u $REAL_USER "$REPO_DIR/identify_serial_devices.py"
  
  echo "Automatic identification of serial devices setup completed."
else
  echo "Warning: identify_serial_devices.py not found. Automatic identification of serial devices not configured."
fi

echo "Installation completed successfully!"
echo "The robot startup service will run automatically on next boot."
echo "To start it now without rebooting, run: sudo systemctl start robot_startup.service"
echo "ROS2 Humble is installed and configured for user $REAL_USER." 