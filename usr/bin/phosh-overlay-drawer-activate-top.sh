#!/bin/bash
# Runs when Enter is pressed in the drawer search box: activates the first
# entry that matches the current search filter (same matching rule as the
# eww :visible expression - case-insensitive regex on the name), then
# closes the drawer.

entries=$(eww -c /etc/phosh-overlay-gestures get drawer-entries)
search=$(eww -c /etc/phosh-overlay-gestures get search-text)

action=$(printf '%s' "$entries" | jq -r --arg q "$search" '
        map(select($q == "" or (.name | test($q; "i"))))
        | .[0].action // empty
')

[ -n "$action" ] && phosh-overlay-drawer-activate.sh "$action" &
phosh-overlay-drawer-close.sh
