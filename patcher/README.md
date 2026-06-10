# 70mai Firmware Patcher

This utility automates the extraction, modification, and repacking of Novatek-based 70mai dashcam firmware. It enables telnet access on the rootfs partition and injects the custom usr/ scripts (Traccar client) into the UBIFS usr partition.

## Prerequisites
* Docker installed on your machine.
* Make installed (standard on Linux/macOS; Windows users can use WSL or Git Bash).
* A downloaded 70mai OTA update .zip file.

## Setup Instructions

### 1. Prepare the Workspace
This tool is designed to work within the repository's structure. The custom binaries (usr/ folder) sit at the root of the project, while the patcher tool and the firmware .zip file live in the patcher/ directory.

Place your downloaded OTA firmware .zip file directly inside the patcher/ folder. The script will automatically detect any .zip file in this directory.

Your folder structure should look exactly like this:

/70mai-traccar-client
  ├── /usr                            # Your custom binaries (traccar_client.sh, isp_demon, etc.)
  └── /patcher
      ├── Dockerfile
      ├── Makefile
      ├── patch_firmware.sh
      ├── README.md
      ├── strip_ota.sh
      └── OTA_firmware_update.zip     <-- Place your downloaded firmware here

### 2. Build the Docker Image
Open a terminal in the patcher/ directory and build the container using the provided Makefile:

make build

(You only need to run this once, or if you modify the Dockerfile)

### 3. Run the Patcher
Execute the patching process. The Makefile automatically handles the complex volume mounts to securely read your firmware and pull in the ../usr directory from the parent folder.

make patch

(Tip: You can also just type make or make all to run the build and patch steps back-to-back).

## Output
The script runs entirely inside an isolated container sandbox, ensuring no messy temporary files are left behind on your machine. Once finished, you will find two new files inside your patcher/ directory:

* FW96580A.orig.bin - A backup of the untouched, extracted firmware.
* FW96580A.bin - The final patched firmware, ready to be flashed to the dashcam.

## Cleanup
If you want to delete the generated .bin files and work dir and start fresh, run:

make clean
