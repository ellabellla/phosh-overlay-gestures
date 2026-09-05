#!/bin/bash
# Runs when Enter is pressed in the drawer search box: closes the drawer
# first, then activates the first entry that matches the current search
# filter (same matching rule as the eww :visible expression -
# case-insensitive regex on the name). Closing first, not in parallel,
# avoids handing keyboard focus to another window while our exclusive-mode
# surface is still mid-teardown.

entries=$(eww -c /etc/phosh-overlay-gestures get drawer-entries)
search=$(eww -c /etc/phosh-overlay-gestures get search-text)

action=$(printf '%s' "$entries" | jq -r --arg q "$search" '
        map(select($q == "" or (.name | test($q; "i"))))
        | .[0].action // empty
')

phosh-overlay-drawer-close.sh
[ -n "$action" ] && phosh-overlay-drawer-activate.sh "$action"
