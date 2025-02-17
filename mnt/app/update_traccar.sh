#!/bin/sh

# Load settings
SETTINGS_FILE="/mnt/app/traccar_settings.conf"
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

log_debug "Settings file loaded from $SETTINGS_FILE"
log_debug "Initial BASE_ACC_X=$BASE_ACC_X, BASE_ACC_Y=$BASE_ACC_Y, BASE_ACC_Z=$BASE_ACC_Z"
log_debug "GPS_FILE=$GPS_FILE, TIMEZONE_OFFSET=$TIMEZONE_OFFSET, G_FORCE_THRESHOLD=$G_FORCE_THRESHOLD"
log_debug "SLEEP_INTERVAL=$SLEEP_INTERVAL, UPDATE_INTERVAL=$UPDATE_INTERVAL"

initial_calibration_done=0
CALIBRATION_SAMPLES=5
parked_count=0
sum_acc_x=0
sum_acc_y=0
sum_acc_z=0

LAST_TIMESTAMP=""

while true; do
    LATEST_LINE=$(tail -n 1 "$GPS_FILE")
    log_debug "LATEST_LINE=$LATEST_LINE"

    IFS=',' read -r TIMESTAMP STATUS LATITUDE LONGITUDE ORIENTATION SPEED ACCX ACCY ACCZ _ <<EOF
$LATEST_LINE
EOF

    log_debug "TIMESTAMP=$TIMESTAMP, STATUS=$STATUS, LAT=$LATITUDE, LON=$LONGITUDE, ORIENT=$ORIENTATION, SPEED=$SPEED, ACCX=$ACCX, ACCY=$ACCY, ACCZ=$ACCZ"

    if ! [ "$TIMESTAMP" -eq "$TIMESTAMP" ] 2>/dev/null; then
        log_debug "ERROR: TIMESTAMP not numeric: $TIMESTAMP"
        sleep "$UPDATE_INTERVAL"
        continue
    fi

    TIMESTAMP_ADJUSTED=$((TIMESTAMP + TIMEZONE_OFFSET))
    log_debug "Adjusted TIMESTAMP=$TIMESTAMP_ADJUSTED"

    if [ "$TIMESTAMP" = "$LAST_TIMESTAMP" ]; then
        log_debug "Skipping update (no new timestamp)"
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    if [ "$STATUS" != "A" ]; then
        log_debug "Invalid GPS signal; skipping."
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    if [ "$SPEED" -eq 0 ]; then
        if [ "$initial_calibration_done" -eq 0 ]; then
            BASE_ACC_X=$ACCX
            BASE_ACC_Y=$ACCY
            BASE_ACC_Z=$ACCZ
            log_debug "Initial parked calibration => ($BASE_ACC_X, $BASE_ACC_Y, $BASE_ACC_Z)"
            initial_calibration_done=1
            LAST_TIMESTAMP=$TIMESTAMP
            sleep "$SLEEP_INTERVAL"
            continue
        else
            parked_count=$((parked_count + 1))
            sum_acc_x=$((sum_acc_x + ACCX))
            sum_acc_y=$((sum_acc_y + ACCY))
            sum_acc_z=$((sum_acc_z + ACCZ))

            log_debug "Zero-speed count=$parked_count; sumX=$sum_acc_x, sumY=$sum_acc_y, sumZ=$sum_acc_z"

            if [ "$parked_count" -ge "$CALIBRATION_SAMPLES" ]; then
                new_x=$((sum_acc_x / parked_count))
                new_y=$((sum_acc_y / parked_count))
                new_z=$((sum_acc_z / parked_count))
                log_debug "Recalibrate => old=($BASE_ACC_X, $BASE_ACC_Y, $BASE_ACC_Z), new=($new_x, $new_y, $new_z)"
                BASE_ACC_X=$new_x
                BASE_ACC_Y=$new_y
                BASE_ACC_Z=$new_z
                parked_count=0
                sum_acc_x=0
                sum_acc_y=0
                sum_acc_z=0
            fi
        fi
    fi

    VAR_ACC_X=$((ACCX - BASE_ACC_X))
    VAR_ACC_Y=$((ACCY - BASE_ACC_Y))
    VAR_ACC_Z=$((ACCZ - BASE_ACC_Z))
    log_debug "VAR_ACC_X=$VAR_ACC_X, VAR_ACC_Y=$VAR_ACC_Y, VAR_ACC_Z=$VAR_ACC_Z"

    if [ "$SPEED" -eq 0 ]; then
        log_debug "SPEED=0 => ignoring any high G-force event."
        if [ -n "$LAST_TIMESTAMP" ]; then
            TIME_DIFF=$((TIMESTAMP - LAST_TIMESTAMP))
            log_debug "TIME_DIFF=$TIME_DIFF"
            if [ "$TIME_DIFF" -lt "$UPDATE_INTERVAL" ]; then
                log_debug "Interval not met; skipping."
                sleep "$SLEEP_INTERVAL"
                continue
            fi
        fi
        log_debug "Sending parked update."
    else
        if [ "${VAR_ACC_X#-}" -gt "$G_FORCE_THRESHOLD" ] || \
           [ "${VAR_ACC_Y#-}" -gt "$G_FORCE_THRESHOLD" ] || \
           [ "${VAR_ACC_Z#-}" -gt "$G_FORCE_THRESHOLD" ]; then
            log_debug "High G-force detected, sending update now."
        else
            if [ -n "$LAST_TIMESTAMP" ]; then
                TIME_DIFF=$((TIMESTAMP - LAST_TIMESTAMP))
                log_debug "TIME_DIFF=$TIME_DIFF"
                if [ "$TIME_DIFF" -lt "$UPDATE_INTERVAL" ]; then
                    log_debug "Interval not met; skipping."
                    sleep "$SLEEP_INTERVAL"
                    continue
                fi
            fi
            log_debug "Sending regular update."
        fi
    fi

    ORIENTATION_DEG=$((ORIENTATION / 100))
    SPEED_KNOTS=$(printf "%d.%02d" $((SPEED * 1944 / 100000)) $((SPEED * 1944 / 1000 % 100)))

    wget -qO- -T 30 \
      "http://$SERVER:$PORT/?id=$DEVICE_ID&lat=$LATITUDE&lon=$LONGITUDE&speed=$SPEED_KNOTS&bearing=$ORIENTATION_DEG&valid=1&timestamp=$TIMESTAMP_ADJUSTED" \
      >/dev/null

    log_debug "Data sent => ID=$DEVICE_ID, LAT=$LATITUDE, LON=$LONGITUDE, TIME=$TIMESTAMP_ADJUSTED, SPEED=$SPEED_KNOTS, ORIENT=$ORIENTATION_DEG"

    LAST_TIMESTAMP=$TIMESTAMP
    sleep "$SLEEP_INTERVAL"
done
