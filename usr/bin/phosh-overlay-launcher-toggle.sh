#!/bin/bash

state=$(eww -c /etc/phosh-overlay-gestures get drawer-open)

if [ "$state" == "false" ]; then
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
        eww -c /etc/phosh-overlay-gestures update drawer-entries="$(phosh-overlay-drawer-list.sh)"
        eww -c /etc/phosh-overlay-gestures open drawer
        eww -c /etc/phosh-overlay-gestures update drawer-open=true
else
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
        eww -c /etc/phosh-overlay-gestures update drawer-open=false search-text=""
        sleep 0.3
        eww -c /etc/phosh-overlay-gestures close drawer
fi
