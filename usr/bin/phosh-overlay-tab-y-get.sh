#!/bin/bash
# Prints the persisted drawer-tab vertical offset as a percentage of screen
# height (default "50%", the middle), set by phosh-overlay-tab-nudge.sh.
# Used to pass --arg "tab-y=..." whenever drawer-tab is opened, since eww
# window :geometry only ever sees values passed as explicit window
# arguments, never global defvar/defpoll state. Percent (not px), because
# the window is anchored "top right" and margins only take effect on an
# anchored edge - "center" anchoring silently discards any y offset.
value=$(cat "$HOME/.cache/phosh-overlay-gestures/tab-y" 2>/dev/null)
printf '%s\n' "${value:-50%}"
