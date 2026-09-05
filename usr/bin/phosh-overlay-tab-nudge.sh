#!/bin/bash
# Moves the drawer-tab pull-tab up or down along the right edge. Persists
# the new offset to disk (survives daemon/reboot) and reopens the window so
# it picks up the new position - eww only reads window geometry at open
# time, it doesn't live-reposition an already-open window.
#
# Offset is a percentage of screen height, not pixels: drawer-tab is
# anchored "top right" (required for the y offset to have any effect at
# all - gtk-layer-shell ignores margins on edges that aren't anchored, and
# "center" anchoring has neither top nor bottom anchored), and a percentage
# means the same value places it proportionally the same place regardless
# of screen size.

step=3
min=0
max=90
state_dir="$HOME/.cache/phosh-overlay-gestures"
state_file="$state_dir/tab-y"
mkdir -p "$state_dir"

current=$(cat "$state_file" 2>/dev/null)
current="${current%\%}"
case "$current" in
        ''|*[!0-9]*) current=50 ;;
esac

case "$1" in
        up) new=$((current - step)) ;;
        down) new=$((current + step)) ;;
        *) exit 1 ;;
esac

[ "$new" -lt "$min" ] && new=$min
[ "$new" -gt "$max" ] && new=$max

echo "${new}%" > "$state_file"
eww -c /etc/phosh-overlay-gestures close drawer-tab
eww -c /etc/phosh-overlay-gestures open drawer-tab --arg "tab-y=${new}%"
