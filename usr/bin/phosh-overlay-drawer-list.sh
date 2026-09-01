#!/bin/bash
# Emits a single JSON array on stdout: installed apps (drun) + open windows,
# for the eww pull-tab drawer to render and search.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/phosh-overlay-gestures"
mkdir -p "$cache_dir"

# eww's (image :path ...) throws and aborts building the whole drawer if
# given an empty/missing path, so every entry must resolve to a real file.
fallback_icon="/etc/phosh-overlay-gestures/fallback-icon.svg"

# One filesystem walk into a name->path index instead of a `find` per icon
# (there can be tens of thousands of icon files) - rebuilt only if missing
# or a day old, not on every run.
icon_index_file="$cache_dir/icon-index"

build_icon_index() {
        find /usr/share/icons /usr/share/pixmaps \
                /var/lib/flatpak/exports/share/icons \
                "$HOME/.local/share/flatpak/exports/share/icons" \
                \( -iname '*.svg' -o -iname '*.png' \) 2>/dev/null |
        while IFS= read -r f; do
                base="${f##*/}"
                printf '%s\t%s\n' "${base%.*}" "$f"
        done > "$icon_index_file"
}

if [ ! -s "$icon_index_file" ] || [ -n "$(find "$icon_index_file" -mmin +1440 2>/dev/null)" ]; then
        build_icon_index
fi

# Single-name lookup against the index. Cheap enough for the handful of
# open windows resolved on every run; only used for the full app list when
# the (rarely rebuilt) apps cache below is actually being rebuilt.
resolve_icon() {
        local name="$1"
        [ -z "$name" ] && printf '%s' "$fallback_icon" && return
        case "$name" in
                /*)
                        if [ -f "$name" ]; then
                                printf '%s' "$name"
                        else
                                printf '%s' "$fallback_icon"
                        fi
                        return
                        ;;
        esac
        local found
        found=$(awk -F'\t' -v k="${name,,}" 'tolower($1)==k{print $2; exit}' "$icon_index_file")
        [ -z "$found" ] && found="$fallback_icon"
        printf '%s' "$found"
}

json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        printf '%s' "$s"
}

app_dirs="/usr/share/applications /usr/local/share/applications $HOME/.local/share/applications"
if [ -n "$XDG_DATA_DIRS" ]; then
        app_dirs=""
        IFS=: read -ra dirs <<< "$XDG_DATA_DIRS"
        for d in "${dirs[@]}"; do
                app_dirs="$app_dirs $d/applications"
        done
        app_dirs="$app_dirs $HOME/.local/share/applications"
fi

# Installed apps almost never change. Cache the fully-built (icons already
# resolved) JSON and only redo the .desktop scan + icon lookups when a
# .desktop file actually changed on disk, instead of on every poll tick.
apps_cache_file="$cache_dir/apps.json"

apps_stale() {
        [ ! -s "$apps_cache_file" ] && return 0
        for d in $app_dirs; do
                [ -d "$d" ] || continue
                [ -n "$(find "$d" -maxdepth 1 -name '*.desktop' -newer "$apps_cache_file" -print -quit 2>/dev/null)" ] && return 0
        done
        return 1
}

build_apps_json() {
        local apps_json=""
        declare -A seen_ids

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

        printf '%s' "$apps_json" > "$apps_cache_file"
}

apps_stale && build_apps_json
apps_json="$(cat "$apps_cache_file")"

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
