#!/usr/bin/env python3

import os
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
    docker_dir = "/home/ubuntu/launch_robot/example-robot-docker"
    run_sh_path = os.path.join(docker_dir, "run.sh")
    
    # Check if files exist
    if not os.path.exists(run_sh_path):
        print(f"Error: {run_sh_path} does not exist!")
        return 1
    
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