#!/bin/bash
# Emits a single JSON array on stdout: installed apps (drun) + open windows,
# for the eww pull-tab drawer to render and search.
#
# No caching anywhere: parsing every .desktop file with a bash loop forking
# grep/cut per field was the slow part (500ms+ for ~60 apps), not the
# filesystem work itself. A single awk process parsing all files at once,
# plus one `find`+`awk` pass to resolve every needed icon, comes in well
# under 200ms, so it's cheap enough to just always recompute fresh.

fallback_icon="/etc/phosh-overlay-gestures/fallback-icon.svg"
icon_dirs="/usr/share/icons /usr/share/pixmaps /var/lib/flatpak/exports/share/icons $HOME/.local/share/flatpak/exports/share/icons"

json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        s="${s//$'\x1f'/\\u001f}"
        printf '%s' "$s"
}

app_dirs="/usr/share/applications /usr/local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/applications $HOME/.local/share/flatpak/exports/share/applications"
if [ -n "$XDG_DATA_DIRS" ]; then
        IFS=: read -ra dirs <<< "$XDG_DATA_DIRS"
        for d in "${dirs[@]}"; do
                app_dirs="$app_dirs $d/applications"
        done
fi

# One awk process parses every .desktop file (instead of forking grep/cut
# per file per field). Outputs "id\tname\ticon", one line per visible app.
# BEGINFILE/FILENAME only work with files passed as awk arguments, not fed
# over a pipe, so the file list has to be an array expanded into "$@".
mapfile -t desktop_files < <(find $app_dirs -maxdepth 1 -name '*.desktop' 2>/dev/null)
apps_tsv=""
if [ "${#desktop_files[@]}" -gt 0 ]; then
        apps_tsv=$(awk -F= '
                BEGINFILE {
                        app=0; hidden=0; name=""; icon=""
                        id=FILENAME
                        sub(/^.*\//, "", id)
                        sub(/\.desktop$/, "", id)
                        if (id in seen) { nextfile }
                        seen[id]=1
                }
                /^Type=Application/ { app=1 }
                /^NoDisplay=true/ { hidden=1 }
                /^Hidden=true/ { hidden=1 }
                /^Name=/ && !name { name=substr($0,6) }
                /^Icon=/ && !icon { icon=substr($0,6) }
                ENDFILE {
                        if (app && !hidden && name) print id "\t" name "\t" icon
                }
        ' "${desktop_files[@]}")
fi

# Open windows via wlrctl - typically just a handful. Output is
# "<app_id>: <title>" per line (e.g. "kitty: ~/repos/wlrctl"), not the
# app_id:"..." title:"..." field format we'd assumed.
declare -a win_titles win_appids
if command -v wlrctl >/dev/null 2>&1; then
        while IFS= read -r line; do
                [ -z "$line" ] && continue
                app_id="${line%%: *}"
                title="${line#*: }"
                [ -z "$title" ] && title="$app_id"
                [ -z "$title" ] && continue
                win_titles+=("$title")
                win_appids+=("$app_id")
        done < <(wlrctl toplevel list 2>/dev/null)
fi

# Resolve every needed icon name (from apps + open windows) in ONE pass
# over the icon dirs, instead of one `find` per icon.
needed=$(
        { printf '%s\n' "$apps_tsv" | awk -F'\t' '$3!="" && $3 !~ /^\//{print tolower($3)}'
          for a in "${win_appids[@]}"; do [ -n "$a" ] && printf '%s\n' "${a,,}"; done
        } | sort -u
)

declare -A icon_path_for
if [ -n "$needed" ]; then
        while IFS=$'\t' read -r key path; do
                icon_path_for["$key"]="$path"
        done < <(find $icon_dirs \( -iname '*.svg' -o -iname '*.png' \) -printf '%f\t%p\n' 2>/dev/null |
                awk -F'\t' -v needed="$needed" '
                        BEGIN{n=split(needed,arr,"\n"); for(i=1;i<=n;i++) want[arr[i]]=1}
                        { k=$1; sub(/\.[^.]+$/,"",k); k=tolower(k); if (k in want && !(k in seen)) { print k"\t"$2; seen[k]=1 } }
                ')
fi

# eww's (image :path ...) throws and aborts building the whole drawer if
# given an empty/missing path, so every entry must resolve to a real file.
resolve_icon() {
        local name="$1"
        [ -z "$name" ] && { printf '%s' "$fallback_icon"; return; }
        case "$name" in
                /*)
                        if [ -f "$name" ]; then printf '%s' "$name"; else printf '%s' "$fallback_icon"; fi
                        return
                        ;;
        esac
        printf '%s' "${icon_path_for[${name,,}]:-$fallback_icon}"
}

apps_json=""
while IFS=$'\t' read -r id name icon; do
        [ -z "$id" ] && continue
        icon_path=$(resolve_icon "$icon")
        # gtk-launch handles Exec= parsing/field-codes/terminal-wrapping for us
        entry=$(printf '{"type":"app","name":"%s","icon":"%s","action":"launch:%s"}' \
                "$(json_escape "$name")" "$(json_escape "$icon_path")" "$(json_escape "$id")")
        apps_json="$apps_json,$entry"
done <<< "$apps_tsv"

windows_json=""
for i in "${!win_titles[@]}"; do
        icon_path=$(resolve_icon "${win_appids[$i]}")
        # Multiple windows can share the same app_id (e.g. several terminal
        # tabs), so the focus action carries both app_id and title
        # (separated by \x1f) to uniquely match the specific window tapped.
        action="focus:${win_appids[$i]}"$'\x1f'"${win_titles[$i]}"
        entry=$(printf '{"type":"window","name":"%s","icon":"%s","action":"%s"}' \
                "$(json_escape "${win_titles[$i]}")" "$(json_escape "$icon_path")" "$(json_escape "$action")")
        windows_json="$windows_json,$entry"
done

all="${windows_json}${apps_json}"
all="${all#,}"
echo "[$all]"
