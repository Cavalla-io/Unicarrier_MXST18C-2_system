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

# Initialize counters for tracking check results
PASS_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0

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
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK $name is NOT installed"
    ((ERROR_COUNT++))
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
      ((PASS_COUNT++))
    else
      echo -e "  $WARN_MARK Service $service is enabled but not currently running"
      ((WARN_COUNT++))
    fi
    
    return 0
  else
    echo -e "$CROSS_MARK Service $service is NOT enabled"
    ((ERROR_COUNT++))
    return 1
  fi
}

# Function to check file permissions
check_file_permissions() {
  local file=$1
  local type=$2
  
  if [ ! -e "$file" ]; then
    echo -e "$CROSS_MARK $type $file does not exist"
    ((ERROR_COUNT++))
    return 1
  fi
  
  if [ -x "$file" ]; then
    echo -e "$CHECK_MARK $type $file exists and is executable"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$WARN_MARK $type $file exists but is NOT executable"
    ((WARN_COUNT++))
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
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK $description NOT found in $file"
    ((ERROR_COUNT++))
    return 1
  fi
}

# Function to check if a directory exists
check_directory() {
  local dir=$1
  local description=$2
  
  if [ -d "$dir" ]; then
    echo -e "$CHECK_MARK Directory $description exists at $dir"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK Directory $description does NOT exist at $dir"
    ((ERROR_COUNT++))
    return 1
  fi
}

# Function to check if a Python package is installed
check_python_package() {
  local package=$1
  if python3 -c "import $package" &> /dev/null; then
    echo -e "$CHECK_MARK Python package $package is installed"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK Python package $package is NOT installed"
    ((ERROR_COUNT++))
    return 1
  fi
}

# Function to check if a ROS2 package is installed
check_ros2_package() {
  local package=$1
  # Use ros2 pkg prefix instead of ros2 pkg list | grep to avoid broken pipe error
  if ros2 pkg prefix "$package" &>/dev/null; then
    echo -e "$CHECK_MARK ROS2 package $package is installed"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK ROS2 package $package is NOT installed"
    ((ERROR_COUNT++))
    return 1
  fi
}

# Function to check if a Debian package is installed
check_deb_package() {
  local package=$1
  if dpkg -l | grep -q "$package"; then
    echo -e "$CHECK_MARK Debian package $package is installed"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "$CROSS_MARK Debian package $package is NOT installed"
    ((ERROR_COUNT++))
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
    ((PASS_COUNT++))
  else
    echo -e "$WARN_MARK ROS2 installed but version might not be Humble: $ros2_version"
    ((WARN_COUNT++))
    # Check if humble packages are installed another way
    if dpkg -l | grep -q "ros-humble-desktop"; then
      echo -e "$CHECK_MARK ROS2 Humble packages are installed (verified via dpkg)"
      ((PASS_COUNT++))
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
  ((PASS_COUNT++))
else
  echo -e "$WARN_MARK ROS_DISTRO environment variable is not set to humble (current: $ROS_DISTRO)"
  echo "   This is normal if you haven't sourced the setup file or restarted your terminal"
  echo "   Try: source /opt/ros/humble/setup.bash"
  ((WARN_COUNT++))
fi

# Check Python dependencies
echo -e "\n== Checking Python Dependencies =="
check_python_package "serial" "PySerial"
check_python_package "can" "Python-CAN"

# Check ROS2 specific dependencies
echo -e "\n== Checking ROS2 Specific Dependencies =="
ros2_packages=(
  "cv_bridge"
  "image_transport"
  "image_pipeline"
  "camera_calibration"
  "vision_msgs"
)

for pkg in "${ros2_packages[@]}"; do
  check_ros2_package "$pkg"
done

# Check Depthai packages
echo -e "\n== Checking Depthai Dependencies =="
depthai_packages=(
  "depthai"
  "depthai_bridge"
  "depthai_descriptions"
  "depthai_ros_msgs"
)

for pkg in "${depthai_packages[@]}"; do
  check_ros2_package "$pkg" || echo "   Note: $pkg may need to be installed from source if not available in ROS repositories"
done

# Check CAN utilities
echo -e "\n== Checking CAN Utilities =="
if dpkg -l | grep -q "can-utils"; then
  echo -e "$CHECK_MARK can-utils package is installed"
  ((PASS_COUNT++))
else
  echo -e "$CROSS_MARK can-utils package is NOT installed"
  echo "   Run: sudo apt-get install -y can-utils"
  ((ERROR_COUNT++))
fi

# Check if CAN interface is setup
echo -e "\n== Checking CAN Interface Configuration =="
if ip link show can0 &> /dev/null; then
  echo -e "$CHECK_MARK CAN interface can0 exists"
  ((PASS_COUNT++))
  
  if ip link show can0 | grep -q "state UP"; then
    echo -e "$CHECK_MARK CAN interface can0 is UP"
    ((PASS_COUNT++))
  else
    echo -e "$WARN_MARK CAN interface can0 exists but is DOWN"
    echo "   Try: ./can_tools.sh start"
    ((WARN_COUNT++))
  fi
else
  echo -e "$WARN_MARK CAN interface can0 does not exist yet"
  echo "   Try: ./can_tools.sh start"
  ((WARN_COUNT++))
fi

# Check CAN permissions services
echo -e "\n== Checking CAN Permission Services =="
check_service "can-setup.service"
check_service "can-permissions.service"

# Check Robot Startup Service
echo -e "\n== Checking Robot Startup Automation =="
check_file_permissions "$REPO_DIR/start_robot.py" "Startup script"
check_service "robot_startup.service"

# Check if the systemd service file exists
if [ -f "/etc/systemd/system/robot_startup.service" ]; then
  echo -e "$CHECK_MARK robot_startup.service file exists in systemd directory"
  ((PASS_COUNT++))
  
  # Check if the service file has the correct path
  if grep -q "$REPO_DIR" "/etc/systemd/system/robot_startup.service"; then
    echo -e "$CHECK_MARK robot_startup.service contains the correct path"
    ((PASS_COUNT++))
  else
    echo -e "$CROSS_MARK robot_startup.service might have incorrect paths"
    echo "   Consider recreating the service file with the correct paths"
    ((ERROR_COUNT++))
  fi
else
  echo -e "$CROSS_MARK robot_startup.service file is missing from systemd directory"
  ((ERROR_COUNT++))
fi

# Check Docker installation (required for robot container)
echo -e "\n== Checking Docker Setup =="
check_command "docker" "Docker"

# Check if user can run Docker commands (is in docker group)
if groups | grep -q "docker"; then
  echo -e "$CHECK_MARK Current user is in the docker group"
  ((PASS_COUNT++))
else
  echo -e "$WARN_MARK Current user is NOT in the docker group, might need sudo for Docker commands"
  echo "   Run: sudo usermod -aG docker $(whoami)"
  echo "   Then log out and back in for changes to take effect"
  ((WARN_COUNT++))
fi

# Check network privileges for user
echo -e "\n== Checking Network Privileges =="
if id -nG | grep -qw "netdev"; then
  echo -e "$CHECK_MARK Current user is in the netdev group"
  ((PASS_COUNT++))
else
  echo -e "$WARN_MARK Current user is NOT in the netdev group, may have limited network control"
  echo "   Run: sudo ./setup_network_privileges.sh $(whoami)"
  ((WARN_COUNT++))
fi

# Check if can_tools.sh is executable
check_file_permissions "$REPO_DIR/can_tools.sh" "CAN tools script"

echo -e "\n== Checking ROS2 Workspace =="
# Define the ROS2 workspace directory explicitly
ROS2_WORKSPACE="/home/cavalla/Unicarrier_MXST18C-2"
echo "Checking ROS2 workspace at: $ROS2_WORKSPACE"

check_directory "$ROS2_WORKSPACE/src" "ROS2 workspace source directory"
check_directory "$ROS2_WORKSPACE/build" "ROS2 workspace build directory"
check_directory "$ROS2_WORKSPACE/install" "ROS2 workspace install directory"

if [ -f "$ROS2_WORKSPACE/install/setup.bash" ]; then
  echo -e "$CHECK_MARK ROS2 workspace is built and has setup.bash"
  ((PASS_COUNT++))
else
  echo -e "$WARN_MARK ROS2 workspace may not be built yet"
  echo "   Run: cd $ROS2_WORKSPACE && colcon build"
  ((WARN_COUNT++))
fi

echo -e "\n== Installation Verification Summary =="
echo -e "${GREEN}Passed:${NC} $PASS_COUNT checks"
echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT checks"
echo -e "${RED}Errors:${NC} $ERROR_COUNT checks"
echo

if [ $ERROR_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
  echo -e "${GREEN}All checks passed! Installation looks complete.${NC}"
elif [ $ERROR_COUNT -eq 0 ]; then
  echo -e "${YELLOW}Installation looks good with some minor warnings.${NC}"
else
  echo -e "${RED}Some installation components have errors that need attention.${NC}"
fi

echo
echo "If any components failed, you may need to run the install script again"
echo "or troubleshoot the specific components that failed."
echo 
echo "For ROS2 environment issues, try: source /opt/ros/humble/setup.bash"
echo "For CAN interface issues, try: ./can_tools.sh start"
echo "For service issues, try: sudo systemctl restart robot_startup.service"
echo
echo "To manually start the robot service: sudo systemctl start robot_startup.service" 