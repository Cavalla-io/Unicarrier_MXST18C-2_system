#!/usr/bin/env python3

import glob
import time
import serial
import subprocess
import os
import re
import binascii

# List of valid device names
VALID_DEVICE_NAMES = ["steering", "brake", "throttle"]

def find_usb_serial_devices():
    """Find all USB serial devices."""
    return glob.glob('/dev/ttyUSB*')

def get_port_path(device_path):
    """Get the physical port path for the device."""
    # First try to get the device path directly
    cmd = ['udevadm', 'info', '--name=' + device_path, '--query=path']
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip()
    
    # If direct query fails, try attribute walk
    cmd = ['udevadm', 'info', '--name=' + device_path, '--attribute-walk']
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    # Look for DEVPATH
    devpath = None
    for line in result.stdout.split('\n'):
        # Try different possible formats of DEVPATH
        if 'DEVPATH' in line:
            # Try the format with ==
            devpath_match = re.search(r'DEVPATH==?["\']?([^"\'= ]+)["\']?', line)
            if devpath_match:
                devpath = devpath_match.group(1)
                break
            
            # Try the format with :
            devpath_match = re.search(r'DEVPATH\s*:\s*["\']?([^"\'= ]+)["\']?', line)
            if devpath_match:
                devpath = devpath_match.group(1)
                break
    
    # If still not found, try looking for the device path in a different way
    if not devpath:
        print("DEVPATH not found directly, trying to extract from parent device...")
        
        # Use realpath to get the real device path
        cmd = ['realpath', device_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            real_path = result.stdout.strip()
            print(f"Real path: {real_path}")
            
            # Extract the device path from sysfs
            if '/sys/devices/' in real_path:
                # Extract the path part
                devpath = real_path.split('/sys/devices/')[1]
                print(f"Extracted devpath: {devpath}")
            else:
                # Try to find the device in /sys/class/tty
                sys_path = f"/sys/class/tty/{os.path.basename(device_path)}/device"
                if os.path.exists(sys_path):
                    cmd = ['readlink', '-f', sys_path]
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    if result.returncode == 0:
                        real_device = result.stdout.strip()
                        print(f"Real device path: {real_device}")
                        if '/sys/devices/' in real_device:
                            devpath = real_device.split('/sys/devices/')[1]
                            print(f"Extracted devpath from sysfs: {devpath}")
    
    # Print full udevadm output for debugging if no path found
    if not devpath:
        print("Full udevadm output for debugging:")
        print(result.stdout)
        
    return devpath

def find_existing_udev_rules(port_path):
    """Find any existing udev rules that match the given port path."""
    existing_rules = []
    
    # Check all udev rule files in /etc/udev/rules.d/
    rule_files = glob.glob('/etc/udev/rules.d/*.rules')
    
    for rule_file in rule_files:
        try:
            with open(rule_file, 'r') as f:
                content = f.read()
                
                # Check if this file contains our port path
                if port_path in content:
                    # Extract the rule lines that match our port path
                    for line in content.split('\n'):
                        if port_path in line and 'DEVPATH' in line:
                            # Extract the symlink name if possible
                            symlink_match = re.search(r'SYMLINK\+=["\']*([^"\']+)["\']', line)
                            symlink = symlink_match.group(1) if symlink_match else None
                            
                            existing_rules.append({
                                'file': rule_file,
                                'line': line,
                                'symlink': symlink
                            })
        except Exception as e:
            print(f"Error reading rule file {rule_file}: {e}")
    
    return existing_rules

def remove_udev_rule(rule_file, line_to_remove):
    """Remove a specific line from a udev rule file."""
    # Create a temporary file with the line removed
    temp_file = f"/tmp/udev-temp-{os.path.basename(rule_file)}"
    
    try:
        with open(rule_file, 'r') as input_file, open(temp_file, 'w') as output_file:
            for line in input_file:
                if line.strip() != line_to_remove.strip():
                    output_file.write(line)
        
        # Move the modified file back to replace the original
        result = subprocess.run(['sudo', 'mv', temp_file, rule_file])
        
        if result.returncode == 0:
            print(f"Removed rule from {rule_file}")
            return True
        else:
            print(f"Failed to update {rule_file}")
            return False
    except Exception as e:
        print(f"Error removing rule: {e}")
        return False

def create_udev_rule(device_name, port_path):
    """Create a udev rule for the device based on its port path."""
    if not port_path:
        print(f"Cannot create udev rule for {device_name}: missing port path")
        return False
    
    # Check for existing rules for this port
    existing_rules = find_existing_udev_rules(port_path)
    
    if existing_rules:
        print(f"Found {len(existing_rules)} existing udev rules for this port:")
        for i, rule in enumerate(existing_rules):
            print(f"  [{i+1}] File: {rule['file']}")
            print(f"      Rule: {rule['line']}")
            print(f"      Symlink: {rule['symlink']}")
        
        # Remove existing rules if they don't match our desired name
        for rule in existing_rules:
            if rule['symlink'] != device_name:
                print(f"Removing different rule for same port (symlink '{rule['symlink']}' != '{device_name}')")
                remove_udev_rule(rule['file'], rule['line'])
            else:
                print(f"Rule with matching symlink already exists for this port")
                return True  # Rule already exists with correct name
    
    # Create a rule that matches the exact physical port
    rule_content = f'SUBSYSTEM=="tty", DEVPATH=="{port_path}", SYMLINK+="{device_name}"\n'
    
    rule_file = f"/etc/udev/rules.d/99-{device_name}.rules"
    temp_file = f"/tmp/udev-{device_name}.rules"
    
    # Write to temporary file
    with open(temp_file, "w") as f:
        f.write(rule_content)
    
    # Use passwordless sudo to move the file and reload udev
    # These commands should be allowed without password via sudoers config
    print(f"Moving rule file to {rule_file}...")
    result = subprocess.run(['sudo', 'mv', temp_file, rule_file])
    
    if result.returncode == 0:
        print(f"Created udev rule for {device_name}")
        # Reload udev rules
        print("Reloading udev rules...")
        subprocess.run(['sudo', 'udevadm', 'control', '--reload-rules'])
        print("Triggering udev rules...")
        subprocess.run(['sudo', 'udevadm', 'trigger'])
        return True
    else:
        print(f"Failed to create udev rule for {device_name}")
        return False

def identify_device(device_path, baud_rates):
    """Attempt to identify a device with retry logic for valid device names."""
    print(f"Communicating with {device_path}...")
    
    max_attempts = 30
    
    for baud_rate in baud_rates:
        print(f"  Trying baud rate: {baud_rate}...")
        
        # Try up to max_attempts times to get a valid response
        for attempt in range(1, max_attempts + 1):
            try:
                ser = serial.Serial(device_path, baud_rate, timeout=2)
                
                # Some devices need a moment to initialize after opening the port
                time.sleep(0.5)
                
                # Flush any existing data
                ser.reset_input_buffer()
                
                # Send the identify command
                ser.write(b"i")
                
                # Wait for response - read raw bytes first
                raw_response = ser.readline()
                
                if raw_response:
                    # Try to decode as UTF-8, but handle errors
                    try:
                        response = raw_response.decode('utf-8').strip()
                        print(f"  Attempt {attempt}: Device responded with: {response}")
                        
                        # Check if response is one of the valid device names
                        if response.lower() in VALID_DEVICE_NAMES:
                            print(f"  Valid device name received: {response}")
                            ser.close()
                            return response.lower()  # Return normalized lowercase name
                        else:
                            print(f"  Invalid device name. Expected one of {VALID_DEVICE_NAMES}")
                            if attempt < max_attempts:
                                print(f"  Retrying... ({attempt}/{max_attempts})")
                                time.sleep(0.5)  # Wait before retrying
                            else:
                                print(f"  Max attempts reached. Using generic name.")
                                ser.close()
                                return f"unknown_device_at_{device_path.split('/')[-1]}"
                    except UnicodeDecodeError:
                        # If we can't decode as UTF-8, show the hex values
                        hex_response = binascii.hexlify(raw_response).decode('ascii')
                        print(f"  Attempt {attempt}: Device responded with binary data: {hex_response}")
                        if attempt < max_attempts:
                            print(f"  Retrying... ({attempt}/{max_attempts})")
                            time.sleep(0.5)  # Wait before retrying
                        else:
                            print(f"  Max attempts reached. Using generic name.")
                            ser.close()
                            return f"unknown_device_at_{device_path.split('/')[-1]}"
                else:
                    print(f"  Attempt {attempt}: No response")
                    if attempt < max_attempts:
                        print(f"  Retrying... ({attempt}/{max_attempts})")
                        time.sleep(0.5)  # Wait before retrying
                    elif attempt == max_attempts:
                        print(f"  No response after {max_attempts} attempts")
                        break  # Try next baud rate
                    
            except Exception as e:
                print(f"  Error: {e}")
                try:
                    ser.close()
                except:
                    pass
                break  # Try next baud rate
            
            # Close the serial port before retrying
            try:
                ser.close()
            except:
                pass
    
    # If we get here, no valid response was received at any baud rate
    print(f"No valid response from {device_path} after trying all baud rates")
    return None

def main():
    devices = find_usb_serial_devices()
    
    if not devices:
        print("No USB serial devices found.")
        return
    
    print(f"Found {len(devices)} USB serial devices.")
    
    # First, check for devices that are no longer present and remove their rules
    clean_old_rules(devices)
    
    device_info = {}
    
    # Define common baud rates to try if the default doesn't work
    baud_rates = [230400, 115200, 9600]
    
    # Send identify message to each device and wait for response
    for device_path in devices:
        device_name = identify_device(device_path, baud_rates)
        if device_name:
            device_info[device_path] = device_name
    
    # Create udev rules for identified devices
    for device_path, device_name in device_info.items():
        # Only use alphanumeric characters, dash, and underscore for device name
        device_name = re.sub(r'[^a-zA-Z0-9_-]', '', device_name)
        if not device_name:
            print(f"Invalid device name from {device_path}")
            continue
            
        port_path = get_port_path(device_path)
        create_udev_rule(device_name, port_path)

def clean_old_rules(current_devices):
    """Remove udev rules for devices that are no longer present."""
    print("Checking for stale device rules...")
    
    # Get the device numbers for current devices
    current_device_nums = set()
    for device in current_devices:
        match = re.search(r'ttyUSB(\d+)', device)
        if match:
            current_device_nums.add(match.group(1))
    
    print(f"Current device numbers: {current_device_nums}")
    
    # Check all existing device rule files
    rule_files = glob.glob('/etc/udev/rules.d/99-*.rules')
    for rule_file in rule_files:
        # Check if this is a rule for a USB device
        tty_match = re.search(r'ttyUSB(\d+)', open(rule_file, 'r').read())
        if tty_match:
            dev_num = tty_match.group(1)
            # If this device number is not in our current list, remove the rule
            if dev_num not in current_device_nums:
                print(f"Removing stale rule file for ttyUSB{dev_num}: {rule_file}")
                try:
                    subprocess.run(['sudo', 'rm', rule_file])
                except Exception as e:
                    print(f"Error removing rule file: {e}")

if __name__ == "__main__":
    main() 