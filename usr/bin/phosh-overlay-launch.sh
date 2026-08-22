#!/bin/bash
if [ -z "$LISGD_INPUT_DEVICE" ] || [ ! -e "$LISGD_INPUT_DEVICE" ]; then
    echo "LISGD_INPUT_DEVICE is unset or points to a nonexistent device: '$LISGD_INPUT_DEVICE'"
    notify-send -u critical "Invalid LISGD_INPUT_DEVICE" "Set the variable pointing to your touchscreen device, can be found with 'libinput debug-events'"
    exit 1
fi
phosh-overlay-shutdown.sh > /dev/null 2>&1

setsid -f eww -c /etc/phosh-overlay-gestures daemon > /dev/null 2>&1 &
setsid -f eww -c /etc/phosh-overlay-gestures open right-gesture-block > /dev/null 2>&1 &
setsid -f phosh-overlay-gestures-start.sh > /dev/null 2>&1
