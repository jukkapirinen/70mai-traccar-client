#!/bin/sh

# Load settings
SETTINGS_FILE="/mnt/sd/traccar_settings.conf"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "ERROR: Settings file not found at $SETTINGS_FILE. Exiting."
    exit 1
fi
. "$SETTINGS_FILE"

log_debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "DEBUG: $1"
    fi
}

log_debug "Settings file loaded successfully from $SETTINGS_FILE."
log_debug "Starting GPS update process..."

# Initialize tracking variables
LAST_TIMESTAMP=""

# Show all loaded variables for debugging
log_debug "SERVER=$SERVER"
log_debug "PORT=$PORT"
log_debug "DEVICE_ID=$DEVICE_ID"
log_debug "GPS_FILE=$GPS_FILE"
log_debug "TIMEZONE_OFFSET=$TIMEZONE_OFFSET"
log_debug "BASE_ACC_X=$BASE_ACC_X"
log_debug "BASE_ACC_Y=$BASE_ACC_Y"
log_debug "BASE_ACC_Z=$BASE_ACC_Z"
log_debug "G_FORCE_THRESHOLD=$G_FORCE_THRESHOLD"
log_debug "SLEEP_INTERVAL=$SLEEP_INTERVAL"
log_debug "UPDATE_INTERVAL=$UPDATE_INTERVAL"

while true; do
    # Read the latest line from the GPS data file
    LATEST_LINE=$(tail -n 1 "$GPS_FILE")
    log_debug "LATEST_LINE=$LATEST_LINE"

    # Parse the line into variables
    IFS=',' read -r TIMESTAMP STATUS LATITUDE LONGITUDE ORIENTATION SPEED ACCX ACCY ACCZ _ <<EOF
$LATEST_LINE
EOF

    # Debug parsed values
    log_debug "TIMESTAMP=$TIMESTAMP"
    log_debug "STATUS=$STATUS"
    log_debug "LATITUDE=$LATITUDE"
    log_debug "LONGITUDE=$LONGITUDE"
    log_debug "ORIENTATION=$ORIENTATION"
    log_debug "SPEED=$SPEED"
    log_debug "ACCX=$ACCX"
    log_debug "ACCY=$ACCY"
    log_debug "ACCZ=$ACCZ"

    # Ensure variables are numeric before arithmetic
    if ! [ "$TIMESTAMP" -eq "$TIMESTAMP" ] 2>/dev/null; then
        log_debug "ERROR: TIMESTAMP is not numeric: $TIMESTAMP"
        sleep "$UPDATE_INTERVAL"
        continue
    fi

    TIMESTAMP_ADJUSTED=$((TIMESTAMP + TIMEZONE_OFFSET))
    log_debug "Original TIMESTAMP=$TIMESTAMP, Adjusted TIMESTAMP=$TIMESTAMP_ADJUSTED"

    # Skip if the timestamp hasn't changed
    if [ "$TIMESTAMP" = "$LAST_TIMESTAMP" ]; then
        log_debug "Skipping update because TIMESTAMP matches LAST_TIMESTAMP"
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    # Check if the GPS signal is valid
    if [ "$STATUS" != "A" ]; then
        log_debug "Invalid GPS signal, skipping update."
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    # Calculate G-force differences
    VAR_ACC_X=$((ACCX - BASE_ACC_X))
    VAR_ACC_Y=$((ACCY - BASE_ACC_Y))
    VAR_ACC_Z=$((ACCZ - BASE_ACC_Z))

    # Debug G-force variations
    log_debug "VAR_ACC_X=$VAR_ACC_X"
    log_debug "VAR_ACC_Y=$VAR_ACC_Y"
    log_debug "VAR_ACC_Z=$VAR_ACC_Z"

    # Check if any G-force variation exceeds the threshold
    if [ "${VAR_ACC_X#-}" -gt "$G_FORCE_THRESHOLD" ] || \
       [ "${VAR_ACC_Y#-}" -gt "$G_FORCE_THRESHOLD" ] || \
       [ "${VAR_ACC_Z#-}" -gt "$G_FORCE_THRESHOLD" ]; then
        log_debug "High G-force detected ACC_X: $VAR_ACC_X, ACC_Y: $VAR_ACC_Y, ACC_Z: $VAR_ACC_Z. Sending update immediately."
    else
        # Not a high G-force event, do interval checks
        if [ -n "$LAST_TIMESTAMP" ]; then
            TIME_DIFF=$((TIMESTAMP - LAST_TIMESTAMP))
            log_debug "TIME_DIFF=$TIME_DIFF"
            if [ "$TIME_DIFF" -lt "$UPDATE_INTERVAL" ]; then
                log_debug "Regular update interval not met. Skipping update."
                sleep "$SLEEP_INTERVAL"
                continue
            fi
        fi
        log_debug "Low G-force detected. Sending regular update."
    fi

    # Convert orientation to degrees
    ORIENTATION_DEG=$((ORIENTATION / 100))

    # Convert speed to knots
    SPEED_KNOTS=$(printf "%d.%02d" $((SPEED * 1944 / 100000)) $((SPEED * 1944 / 1000 % 100)))

    # Send data to Traccar
    wget -qO- -T 30 "http://$SERVER:$PORT/?id=$DEVICE_ID&lat=$LATITUDE&lon=$LONGITUDE&speed=$SPEED_KNOTS&bearing=$ORIENTATION_DEG&valid=1&timestamp=$TIMESTAMP_ADJUSTED" >/dev/null

    log_debug "Data sent: ID=$DEVICE_ID, LAT=$LATITUDE, LON=$LONGITUDE, TIME=$TIMESTAMP_ADJUSTED, SPEED=$SPEED_KNOTS knots, ORIENTATION=$ORIENTATION_DEG, ACCX=$ACCX, ACCY=$ACCY, ACCZ=$ACCZ"

    # Update LAST_TIMESTAMP globally after sending data
    LAST_TIMESTAMP=$TIMESTAMP

    # Pause before the next iteration
    sleep "$SLEEP_INTERVAL"
done
