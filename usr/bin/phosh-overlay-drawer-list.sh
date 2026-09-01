#!/bin/bash
# Emits a single JSON array on stdout: installed apps (drun) + open windows,
# for the eww pull-tab drawer to render and search.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/phosh-overlay-gestures"
mkdir -p "$cache_dir"

resolve_icon() {
        local name="$1"
        [ -z "$name" ] && return
        case "$name" in
                /*) [ -f "$name" ] && echo "$name" && return ;;
        esac

        local cache_file="$cache_dir/icon-$name"
        if [ -f "$cache_file" ]; then
                cat "$cache_file"
                return
        fi

        local found
        found=$(find /usr/share/icons /usr/share/pixmaps \
                /var/lib/flatpak/exports/share/icons \
                "$HOME/.local/share/flatpak/exports/share/icons" \
                \( -iname "$name.svg" -o -iname "$name.png" \) \
                2>/dev/null | head -n1)
        echo "$found" > "$cache_file"
        echo "$found"
}

json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        printf '%s' "$s"
}

apps_json=""
declare -A seen_ids

app_dirs="/usr/share/applications /usr/local/share/applications $HOME/.local/share/applications"
if [ -n "$XDG_DATA_DIRS" ]; then
        app_dirs=""
        IFS=: read -ra dirs <<< "$XDG_DATA_DIRS"
        for d in "${dirs[@]}"; do
                app_dirs="$app_dirs $d/applications"
        done
        app_dirs="$app_dirs $HOME/.local/share/applications"
fi

# user-local dirs last in app_dirs but should win: process in reverse so later wins
for dir in $app_dirs; do
        [ -d "$dir" ] || continue
        while IFS= read -r desktop_file; do
                id="$(basename "$desktop_file")"
                [ -n "${seen_ids[$id]:-}" ] && continue
                seen_ids[$id]=1

                grep -qi '^NoDisplay=true' "$desktop_file" && continue
                grep -qi '^Hidden=true' "$desktop_file" && continue

                name=$(grep -m1 '^Name=' "$desktop_file" | cut -d= -f2-)
                icon=$(grep -m1 '^Icon=' "$desktop_file" | cut -d= -f2-)
                exec=$(grep -m1 '^Exec=' "$desktop_file" | cut -d= -f2-)
                [ -z "$name" ] || [ -z "$exec" ] && continue

                exec=$(echo "$exec" | sed -E 's/@@[^@]*@@//g; s/%[fFuUick]//g')
                icon_path=$(resolve_icon "$icon")

                entry=$(printf '{"type":"app","name":"%s","icon":"%s","action":"exec:%s"}' \
                        "$(json_escape "$name")" "$(json_escape "$icon_path")" "$(json_escape "$exec")")
                apps_json="$apps_json,$entry"
        done < <(find "$dir" -maxdepth 1 -name '*.desktop' 2>/dev/null)
done

windows_json=""
if command -v wlrctl >/dev/null 2>&1; then
        while IFS= read -r line; do
                [ -z "$line" ] && continue
                app_id=$(echo "$line" | grep -oP 'app_id:"\K[^"]*')
                title=$(echo "$line" | grep -oP 'title:"\K[^"]*')
                [ -z "$title" ] && title="$app_id"
                [ -z "$title" ] && continue

                icon_path=$(resolve_icon "$app_id")

                entry=$(printf '{"type":"window","name":"%s","icon":"%s","action":"focus:%s"}' \
                        "$(json_escape "$title")" "$(json_escape "$icon_path")" "$(json_escape "$app_id")")
                windows_json="$windows_json,$entry"
        done < <(wlrctl toplevel list 2>/dev/null)
fi

all="${windows_json}${apps_json}"
all="${all#,}"
echo "[$all]"
