#!/bin/bash

# Check whether the window actually exists rather than trusting the
# drawer-open var: :unfocus-close (tap-away-to-dismiss) closes the window
# directly inside eww without going through this script, so drawer-open can
# go stale (stuck true) relative to the real window state.
if eww -c /etc/phosh-overlay-gestures active-windows | grep -q '^drawer:'; then
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
        eww -c /etc/phosh-overlay-gestures update drawer-open=false search-text=""
        sleep 0.3
        eww -c /etc/phosh-overlay-gestures close drawer
else
        busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
        # drawer-open must be true BEFORE the window opens: GTK's default
        # "focus first focusable child" runs at window-map time, and if the
        # revealer is still collapsed then, the search box never gets a
        # valid focus grab once it's actually shown.
        eww -c /etc/phosh-overlay-gestures update drawer-open=true
        eww -c /etc/phosh-overlay-gestures open drawer
fi
