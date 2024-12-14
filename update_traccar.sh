#!/bin/sh

# Configurations
SERVER="traccar_server"
PORT="5055"
DEVICE_ID="12345678"
GPS_FILE="/mnt/sd/GPSData000001.txt"

# Timezone Offset in seconds (8 hours)
TIMEZONE_OFFSET=28800  # 8 hours = 8 * 3600 seconds

# Baseline G-force values (take values from parked car)
BASE_ACC_X=4
BASE_ACC_Y=84
BASE_ACC_Z=44

# Time thresholds
G_FORCE_THRESHOLD=5
SLEEP_INTERVAL=2
UPDATE_INTERVAL=20

# Initialize tracking variables
LAST_TIMESTAMP=""

# Start main loop
echo "Starting GPS update process..."
while true; do
    # Read the latest line from the GPS data file
    LATEST_LINE=$(tail -n 1 "$GPS_FILE")

    # Parse the line into variables
    IFS=',' read -r TIMESTAMP STATUS LATITUDE LONGITUDE ORIENTATION SPEED ACCX ACCY ACCZ _ <<EOF
$LATEST_LINE
EOF

    # Adjust GPS timestamp to the correct time zone using the variable
    TIMESTAMP_ADJUSTED=$((TIMESTAMP + TIMEZONE_OFFSET))
    echo "DEBUG: Original TIMESTAMP=$TIMESTAMP, Adjusted TIMESTAMP=$TIMESTAMP_ADJUSTED"

    # Skip if the timestamp hasn't changed
    if [ "$TIMESTAMP" = "$LAST_TIMESTAMP" ]; then
        echo "DEBUG: Skipping update because TIMESTAMP matches LAST_TIMESTAMP"
        sleep $SLEEP_INTERVAL
        continue
    fi

    # Check if the GPS signal is valid
    if [ "$STATUS" != "A" ]; then
        echo "DEBUG: Invalid GPS signal, skipping update."
        sleep $SLEEP_INTERVAL
        continue
    fi

    # Calculate G-force differences
    VAR_ACC_X=$((ACCX - BASE_ACC_X))
    VAR_ACC_Y=$((ACCY - BASE_ACC_Y))
    VAR_ACC_Z=$((ACCZ - BASE_ACC_Z))

    # Check if any G-force variation exceeds the threshold
    if [ "${VAR_ACC_X#-}" -gt "$G_FORCE_THRESHOLD" ] || \
       [ "${VAR_ACC_Y#-}" -gt "$G_FORCE_THRESHOLD" ] || \
       [ "${VAR_ACC_Z#-}" -gt "$G_FORCE_THRESHOLD" ]; then
        # High G-force event: Send update immediately without interval checks
        echo "DEBUG: High G-force detected ACC_X: $VAR_ACC_X, ACC_Y $VAR_ACC_Y, ACC_Z $VAR_ACC_Z. Sending update immediately."
    else
        # Not a high G-force event, do interval checks
        if [ -n "$LAST_TIMESTAMP" ]; then
            TIME_DIFF=$((TIMESTAMP - LAST_TIMESTAMP))
            echo "DEBUG: TIME_DIFF=$TIME_DIFF"
            if [ "$TIME_DIFF" -lt "$UPDATE_INTERVAL" ]; then
                echo "DEBUG: Regular update interval not met. Skipping update."
                sleep $SLEEP_INTERVAL
                continue
            fi
        fi
        echo "DEBUG: Low G-force detected. Sending regular update."
    fi

    # Convert orientation to degrees
    ORIENTATION_DEG=$((ORIENTATION / 100))

    # Convert speed to knots
    SPEED_KNOTS=$(printf "%d.%02d" $((SPEED * 1944 / 100000 )) $((SPEED * 1944 / 1000 % 100)))

    # Send data to Traccar
    wget -qO- --timeout=30 "http://$SERVER:$PORT/?id=$DEVICE_ID&lat=$LATITUDE&lon=$LONGITUDE&speed=$SPEED_KNOTS&bearing=$ORIENTATION_DEG&valid=1&timestamp=$TIMESTAMP_ADJUSTED" >/dev/null

    # Log the update
    echo "Data sent: ID=$DEVICE_ID, LAT=$LATITUDE, LON=$LONGITUDE, TIME=$TIMESTAMP_ADJUSTED, SPEED=$SPEED_KNOTS knots, ORIENTATION=$ORIENTATION_DEG, ACCX=$ACCX, ACCY=$ACCY, ACCZ=$ACCZ"

    # Update LAST_TIMESTAMP globally after sending data
    LAST_TIMESTAMP=$TIMESTAMP

    # Pause before the next iteration
    sleep $SLEEP_INTERVAL
done
