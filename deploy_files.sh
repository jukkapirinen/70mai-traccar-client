#!/bin/sh
# Script to copy configuration and scripts to appropriate locations and set permissions

# Define source and destination files
cp ./mnt/app/traccar_settings.conf /mnt/app/traccar_settings.conf
cp ./mnt/app/gettime.sh /mnt/app/gettime.sh
cp ./usr/bin/isp_demon /usr/bin/isp_demon
cp ./mnt/app/update_traccar.sh /mnt/app/update_traccar.sh

chmod +x /mnt/app/gettime.sh /mnt/app/update_traccar.sh /usr/bin/isp_demon
