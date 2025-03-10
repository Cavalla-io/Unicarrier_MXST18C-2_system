#!/usr/bin/env python3

import os
import time
import subprocess
import signal
import sys

def signal_handler(sig, frame):
    print("\nShutting down...")
    sys.exit(0)

# Register signal handler for Ctrl+C
signal.signal(signal.SIGINT, signal_handler)

def main():
    # Paths to scripts
    uvc_rgb_path = "/home/ubuntu/launch_robot/uvc_rgb.py"
    docker_dir = "/home/ubuntu/launch_robot/example-robot-docker"
    run_sh_path = os.path.join(docker_dir, "run.sh")
    
    # Check if files exist
    if not os.path.exists(uvc_rgb_path):
        print(f"Error: {uvc_rgb_path} does not exist!")
        return 1
    
    if not os.path.exists(run_sh_path):
        print(f"Error: {run_sh_path} does not exist!")
        return 1
    
    # Start uvc_rgb.py
    print("Starting uvc_rgb.py...")
    try:
        uvc_process = subprocess.Popen(
            ["python3", uvc_rgb_path, "--daemon"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        print(f"uvc_rgb.py started with PID {uvc_process.pid}")
    except Exception as e:
        print(f"Error starting uvc_rgb.py: {e}")
        return 1
    
    # Wait for /dev/video0 to exist
    print("Waiting for /dev/video0 to exist...")
    max_wait = 30  # Maximum seconds to wait
    for i in range(max_wait):
        if os.path.exists("/dev/video0"):
            print("/dev/video0 exists!")
            break
        print(f"Still waiting for /dev/video0... ({i+1}/{max_wait})")
        time.sleep(1)
    
    if not os.path.exists("/dev/video0"):
        print("Warning: /dev/video0 did not appear after waiting, but proceeding anyway...")
    
    # Run the Docker container with sudo
    print("Starting Docker container with sudo...")
    try:
        os.chdir(docker_dir)
        
        # Use sudo to run the Docker script
        docker_process = subprocess.run(
            ["sudo", "./run.sh", "--detached"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print("Docker container started successfully")
        print(docker_process.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error starting Docker container: {e}")
        print(f"Output: {e.stdout}")
        print(f"Error: {e.stderr}")
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 1
    
    print("Startup complete!")
    return 0

if __name__ == "__main__":
    sys.exit(main()) 