#!/bin/bash

# Verification script for Robot Startup Automation installation
# This script checks that all components from install.sh were properly installed

# Text formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"
WARN_MARK="${YELLOW}!${NC}"

# Get current directory (repository location)
REPO_DIR="$PWD"

echo "Verifying installation components..."
echo "Using repository directory: $REPO_DIR"
echo

# Function to check if a command exists
check_command() {
  local cmd=$1
  local name=$2
  if command -v $cmd &> /dev/null; then
    echo -e "$CHECK_MARK $name is installed"
    return 0
  else
    echo -e "$CROSS_MARK $name is NOT installed"
    return 1
  fi
}

# Function to check if a service is enabled
check_service() {
  local service=$1
  if systemctl is-enabled $service &> /dev/null; then
    echo -e "$CHECK_MARK Service $service is enabled"
    
    # Also check if it's running
    if systemctl is-active $service &> /dev/null; then
      echo -e "  $CHECK_MARK Service $service is running"
    else
      echo -e "  $WARN_MARK Service $service is enabled but not currently running"
    fi
    
    return 0
  else
    echo -e "$CROSS_MARK Service $service is NOT enabled"
    return 1
  fi
}

# Function to check file permissions
check_file_permissions() {
  local file=$1
  local type=$2
  
  if [ ! -e "$file" ]; then
    echo -e "$CROSS_MARK $type $file does not exist"
    return 1
  fi
  
  if [ -x "$file" ]; then
    echo -e "$CHECK_MARK $type $file exists and is executable"
    return 0
  else
    echo -e "$WARN_MARK $type $file exists but is NOT executable"
    return 1
  fi
}

# Function to check if a line exists in a file
check_line_in_file() {
  local pattern=$1
  local file=$2
  local description=$3
  
  if grep -q "$pattern" "$file"; then
    echo -e "$CHECK_MARK $description found in $file"
    return 0
  else
    echo -e "$CROSS_MARK $description NOT found in $file"
    return 1
  fi
}

# Function to check if a directory exists
check_directory() {
  local dir=$1
  local description=$2
  
  if [ -d "$dir" ]; then
    echo -e "$CHECK_MARK Directory $description exists at $dir"
    return 0
  else
    echo -e "$CROSS_MARK Directory $description does NOT exist at $dir"
    return 1
  fi
}

echo "== Checking ROS2 Humble Installation =="
ros2_installed=0
check_command "ros2" "ROS2 command line tools" && ros2_installed=1

if [ $ros2_installed -eq 1 ]; then
  # Try to get ROS2 version information
  ros2_version=$(ros2 --version 2>/dev/null)
  if [[ $ros2_version == *"humble"* ]]; then
    echo -e "$CHECK_MARK Correct ROS2 Humble version detected: $ros2_version"
  else
    echo -e "$WARN_MARK ROS2 installed but version might not be Humble: $ros2_version"
    # Check if humble packages are installed another way
    if dpkg -l | grep -q "ros-humble-desktop"; then
      echo -e "$CHECK_MARK ROS2 Humble packages are installed (verified via dpkg)"
    fi
  fi
fi

# Check if rosdep is initialized
echo -e "\n== Checking ROS development tools =="
check_command "rosdep" "rosdep dependency tool"
check_command "colcon" "colcon build tool"

# Check ROS2 environment setup
echo -e "\n== Checking ROS2 Environment Setup =="
check_line_in_file "source /opt/ros/humble/setup.bash" "$HOME/.bashrc" "ROS2 environment sourcing"

# Check if ROS_DISTRO environment variable is set correctly
if [ "$ROS_DISTRO" = "humble" ]; then
  echo -e "$CHECK_MARK ROS_DISTRO environment variable is set to humble"
else
  echo -e "$WARN_MARK ROS_DISTRO environment variable is not set to humble (current: $ROS_DISTRO)"
  echo "   This is normal if you haven't sourced the setup file or restarted your terminal"
  echo "   Try: source /opt/ros/humble/setup.bash"
fi

# Check Robot Startup Service
echo -e "\n== Checking Robot Startup Automation =="
check_file_permissions "$REPO_DIR/start_robot.py" "Startup script"
check_service "robot_startup.service"

# Check if the systemd service file exists
if [ -f "/etc/systemd/system/robot_startup.service" ]; then
  echo -e "$CHECK_MARK robot_startup.service file exists in systemd directory"
  
  # Check if the service file has the correct path
  if grep -q "$REPO_DIR" "/etc/systemd/system/robot_startup.service"; then
    echo -e "$CHECK_MARK robot_startup.service contains the correct path"
  else
    echo -e "$CROSS_MARK robot_startup.service might have incorrect paths"
    echo "   Consider recreating the service file with the correct paths"
  fi
else
  echo -e "$CROSS_MARK robot_startup.service file is missing from systemd directory"
fi

# Check Docker installation (required for robot container)
echo -e "\n== Checking Docker Setup =="
check_command "docker" "Docker"

# Check if user can run Docker commands (is in docker group)
if groups | grep -q "docker"; then
  echo -e "$CHECK_MARK Current user is in the docker group"
else
  echo -e "$WARN_MARK Current user is NOT in the docker group, might need sudo for Docker commands"
  echo "   Run: sudo usermod -aG docker $(whoami)"
  echo "   Then log out and back in for changes to take effect"
fi

# Check the docker directory for run.sh
if [ -f "$REPO_DIR/example-robot-docker/run.sh" ]; then
  echo -e "$CHECK_MARK Docker run.sh script exists"
  if [ -x "$REPO_DIR/example-robot-docker/run.sh" ]; then
    echo -e "$CHECK_MARK Docker run.sh script is executable"
  else
    echo -e "$WARN_MARK Docker run.sh script exists but is not executable"
    echo "   Run: chmod +x $REPO_DIR/example-robot-docker/run.sh"
  fi
else
  echo -e "$CROSS_MARK Docker run.sh script is missing"
  echo "   Copy or create it at: $REPO_DIR/example-robot-docker/run.sh"
fi

echo -e "\n== Installation Verification Summary =="
echo "If any components failed, you may need to run the install script again"
echo "or troubleshoot the specific components that failed."
echo 
echo "For ROS2 environment issues, try: source /opt/ros/humble/setup.bash"
echo "For service issues, try: sudo systemctl restart robot_startup.service"
echo
echo "To manually start the robot service: sudo systemctl start robot_startup.service" 