#!/bin/bash
# Emits the "Actions" tab's quick-actions grid as JSON: an array of rows,
# each row an array of up to 2 {"label":...,"cmd":...} objects, read from
# /etc/phosh-overlay-gestures/quick-actions.conf ("Label|command" per line).

config="/etc/phosh-overlay-gestures/quick-actions.conf"

json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        printf '%s' "$s"
}

mapfile -t lines < <(grep -v '^[[:space:]]*#' "$config" 2>/dev/null | grep -v '^[[:space:]]*$')

to_entry() {
        local label="${1%%|*}"
        local cmd="${1#*|}"
        printf '{"label":"%s","cmd":"%s"}' "$(json_escape "$label")" "$(json_escape "$cmd")"
}

rows=""
i=0
while [ "$i" -lt "${#lines[@]}" ]; do
        row="[$(to_entry "${lines[$i]}")"
        if [ "$((i + 1))" -lt "${#lines[@]}" ]; then
                row="$row,$(to_entry "${lines[$((i + 1))]}")"
        fi
        row="$row]"
        rows="$rows,$row"
        i=$((i + 2))
done
rows="${rows#,}"
echo "[$rows]"
