#!/bin/bash
pkill lisgd
for i in $(seq 1 20); do
    pgrep -x lisgd > /dev/null || break
    sleep 0.1
done
eww -c /etc/phosh-overlay-gestures kill
