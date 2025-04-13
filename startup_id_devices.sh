#!/bin/bash

# This script runs at system startup to ensure all USB devices are properly identified
# Add this to /etc/rc.local or run it from crontab with @reboot

# Wait for USB devices to settle
sleep 20

# Check for existing USB devices
for i in {0..10}; do
  if [ -e "/dev/ttyUSB$i" ]; then
    echo "Found device at /dev/ttyUSB$i"
    
    # Run the identification script
    /home/cavalla/Unicarrier_MXST18C-2_system/identify_serial_devices.py
    
    # Verify symlinks exist
    echo "Checking for symlinks..."
    ls -la /dev/steering /dev/throttle || true
    break
  fi
done

# Force a udev trigger to ensure rules are applied
sudo udevadm trigger

# Final check after trigger
echo "Final check for symlinks..."
ls -la /dev/steering /dev/throttle || true

exit 0
