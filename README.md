# Driver Installation Automation Script

This script automates the installation of driver files (MSI/EXE) located within its folder. 

## Purpose
We developed this script to streamline the installation process, eliminating the need to manually execute each file one by one. By running in silent mode, the script performs all installations in the background, ensuring a seamless experience that does not disrupt the user.

## Prerequisites
- Windows OS
- Administrative privileges for script execution

## How to Use
The process is straightforward and requires no modification of the script. Simply follow these three steps:

1. **Download:** Obtain the drivers compatible with your CPU and motherboard manufacturer (may be download to their official sites).
2. **Setup:** Place these driver files into the same folder as the script.
3. **Execute:** Run the script as an administrator. 

Once the process is finished, a final message will appear to confirm that the installation is complete.

## Features
- **Batch Processing:** Automatically detects and processes MSI and EXE files in the folder.
- **Silent Installation:** Runs in the background to minimize user disruption.
- **Verification:** Provides an execution summary showing the status (Success/Fail) of each driver installation.

---
*Note: After the script completes, please check for any pending system updates to ensure all drivers are up to date.*