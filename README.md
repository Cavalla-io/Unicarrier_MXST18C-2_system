# Robot Startup Automation

This repository contains an automated system to initialize your robot on startup. The automation handles launching the camera driver (`uvc_rgb.py`) and waiting for the video device to become available before launching the robot's Docker container.

## System Overview

### Components

1. **`startup_script.sh`**: A bash script that:
   - Runs the camera initialization script (`uvc_rgb.py`)
   - Waits for the camera device (`/dev/video0`) to become available
   - Launches the Docker container by running `run.sh` in the docker directory

2. **`robot_startup.service`**: A systemd service file that runs the startup script automatically when the system boots.

3. **`uvc_rgb.py`**: The camera initialization script that sets up the camera device.

4. **`example-robot-docker/run.sh`**: Script that launches the robot's Docker container.

## How It Works

The automation follows this sequence:
1. The system boots up
2. The systemd service (`robot_startup.service`) starts automatically
3. The service runs `start_robot.py`
4. The script executes the camera initialization script (`uvc_rgb.py`)
5. The script waits for the camera device (`/dev/video0`) to become available
6. Once the camera is ready, the script runs `run.sh` in the docker directory
7. The Docker container starts, and the robot is operational

## Installation

To install the automation, follow these steps:

1. Ensure the startup script is executable:
   ```bash
   chmod +x /home/ubuntu/Unicarrier_MXST18C-2_system/start_robot.py
   ```

2. Copy the systemd service file to the system directory:
   ```bash
   sudo cp /home/ubuntu/Unicarrier_MXST18C-2_system/robot_startup.service /etc/systemd/system/
   ```

3. Reload the systemd daemon:
   ```bash
   sudo systemctl daemon-reload
   ```

4. Enable the service to start on boot:
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

### Common Issues

1. **Camera not initializing**:
   - Check that `uvc_rgb.py` is working correctly
   - Verify camera connections

2. **Docker doesn't start**:
   - Check that `run.sh` has correct permissions
   - Verify Docker is installed and running

3. **Service fails to start**:
   - Verify file paths in `startup_script.sh`
   - Ensure the ubuntu user has necessary permissions

## Customization

If you need to modify the startup behavior:

1. Edit the `startup_script.sh` file to change the execution sequence
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

3. Run the setup script and wait for the build to complete:
   ```bash
   cd example-robot-docker
   ./run.sh
   ```
   
   This will build the Docker container with your custom configuration and launch the robot system.

4. Follow the installation instructions in the "Installation" section above to set up the systemd service for automatic startup. 