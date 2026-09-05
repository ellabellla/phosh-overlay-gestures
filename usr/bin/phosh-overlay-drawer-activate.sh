#!/bin/bash
# Dispatches one "action" string emitted by phosh-overlay-drawer-list.sh's JSON:
#   launch:<desktop-id>              -> launch an app via gtk-launch
#   focus:<app_id>\x1f<title>        -> focus the specific open window

action="$1"

case "$action" in
        launch:*)
                id="${action#launch:}"
                setsid -f gtk-launch "$id" >/dev/null 2>&1 &
                ;;
        focus:*)
                payload="${action#focus:}"
                app_id="${payload%%$'\x1f'*}"
                title="${payload#*$'\x1f'}"
                # wlrctl's matchspec syntax is app_id:<value>, no quotes around the value.
                # Multiple windows can share an app_id, so title narrows it down
                # to the exact one that was tapped.
                setsid -f wlrctl toplevel focus "app_id:$app_id" "title:$title" >/dev/null 2>&1 &
                ;;
esac
