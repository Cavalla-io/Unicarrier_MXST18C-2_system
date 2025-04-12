# Robot Startup Automation

This repository contains an automated system to initialize your robot on startup. The automation handles launching the robot's Docker container for running ROS2 applications.

## System Overview

### Components

1. **`start_robot.py`**: A Python script that:
   - Checks for the Docker run script
   - Launches the Docker container by running `run.sh` in the example-robot-docker directory

2. **`robot_startup.service`**: A systemd service file that runs the startup script automatically when the system boots.

3. **`example-robot-docker/run.sh`**: Script that launches the robot's Docker container.

4. **`install.sh`**: Installation script that automates the setup process, including:
   - Installing ROS2 Humble (if not already installed)
   - Setting up the ROS2 environment in .bashrc
   - Setting up the systemd service
   - Adding the user to the Docker group

5. **`verify_installation.sh`**: Script to verify all components are correctly installed.

## How It Works

The automation follows this sequence:
1. The system boots up
2. The systemd service (`robot_startup.service`) starts automatically
3. The service runs `start_robot.py`
4. The script runs `run.sh` in the docker directory
5. The Docker container starts, and the robot is operational

## Installation

The simplest way to install is to use the provided installation script:

```bash
# Clone the repository
git clone https://github.com/Cavalla-io/Unicarrier_MXST18C-2_system.git
cd Unicarrier_MXST18C-2_system

# Make the installation script executable
chmod +x install.sh

# Run the installation script
./install.sh
```

The installation script will:
1. Install ROS2 Humble if not already installed
2. Configure ROS2 environment in your .bashrc
3. Set up the startup script
4. Create and enable the systemd service
5. Add your user to the docker group if needed

After installation, verify that everything was set up correctly:

```bash
./verify_installation.sh
```

## Manual Installation

If you prefer to install manually, follow these steps:

1. Ensure the startup script is executable:
   ```bash
   chmod +x start_robot.py
   ```

2. Create a systemd service file:
   ```bash
   cat > robot_startup.service << EOL
   [Unit]
   Description=Robot Startup Automation
   After=network.target

   [Service]
   ExecStart=$(pwd)/start_robot.py
   User=$(whoami)
   Restart=on-failure
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   EOL
   ```

3. Copy the systemd service file to the system directory:
   ```bash
   sudo cp robot_startup.service /etc/systemd/system/
   ```

4. Reload the systemd daemon:
   ```bash
   sudo systemctl daemon-reload
   ```

5. Enable the service to start on boot:
   ```bash
   sudo systemctl enable robot_startup.service
   ```

## Usage

The automation will run automatically when the system boots. 

To manually start the service without rebooting:
```bash
sudo systemctl start robot_startup.service
```

To check the status of the service:
```bash
sudo systemctl status robot_startup.service
```

To stop the service:
```bash
sudo systemctl stop robot_startup.service
```

## Troubleshooting

### Viewing Logs
To check the logs if something isn't working:
```bash
journalctl -u robot_startup.service
```

### Verifying Installation
To verify that all components were installed correctly:
```bash
./verify_installation.sh
```

### Common Issues

1. **Docker doesn't start**:
   - Check that `run.sh` has correct permissions
   - Verify Docker is installed and running
   - Make sure your user is in the docker group

2. **Service fails to start**:
   - Verify file paths in the systemd service file
   - Check service status: `sudo systemctl status robot_startup.service`
   - Ensure your user has necessary permissions

3. **ROS2 environment issues**:
   - Check that ROS2 is properly sourced in your .bashrc
   - Try running: `source /opt/ros/humble/setup.bash`

## Customization

If you need to modify the startup behavior:

1. Edit the `start_robot.py` file to change the execution sequence
2. After making changes, restart the service:
   ```bash
   sudo systemctl restart robot_startup.service
   ```

## Adding to a New System

To implement this automation on a new system, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Unicarrier_MXST18C-2_system.git
   cd Unicarrier_MXST18C-2_system
   ```

2. Update the robot name in the `example-robot-docker/run.sh` file:
   ```bash
   # Open the file in your preferred editor
   nano example-robot-docker/run.sh
   
   # Change the TAGNAME variable to match your robot's identifier
   # Look for this line and modify it:
   TAGNAME=cavalla_001
   ```

3. Run the installation script:
   ```bash
   ./install.sh
   ```
   
   This will install all necessary components and configure the system to start the robot automatically on boot.

4. Verify the installation:
   ```bash
   ./verify_installation.sh
   ``` 