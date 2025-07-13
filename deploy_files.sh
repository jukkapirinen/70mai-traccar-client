#!/bin/sh
# Script to copy configuration and scripts to appropriate locations and set permissions

# Define source and destination files
cp ./mnt/other/traccar_settings.conf /mnt/other/traccar_settings.conf
cp ./usr/bin/isp_demon /usr/bin/isp_demon
cp ./usr/bin/traccar_client.sh /usr/bin/traccar_client.sh

chmod +x /mnt/app/update_traccar.sh /usr/bin/isp_demon
