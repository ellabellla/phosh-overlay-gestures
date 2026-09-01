#!/bin/bash
# Dispatches one "action" string emitted by phosh-overlay-drawer-list.sh's JSON:
#   exec:<cmd>               -> launch an app
#   focus:<wlrctl selector>  -> focus an open window

action="$1"

case "$action" in
        exec:*)
                cmd="${action#exec:}"
                setsid -f sh -c "$cmd" >/dev/null 2>&1 &
                ;;
        focus:*)
                app_id="${action#focus:}"
                setsid -f wlrctl toplevel focus "app_id:\"$app_id\"" >/dev/null 2>&1 &
                ;;
esac
