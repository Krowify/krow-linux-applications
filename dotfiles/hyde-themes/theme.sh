#!/usr/bin/env bash
set -uo pipefail
#-------------------------------------------------------------------------
# Deployed by 5-dotfiles.sh into ~/.config/hyde-themes/ (alongside a
# directory per theme -- currently tokyo-night/, decay-green/, and
# graphite-mono/). This is the single place that knows how to actually
# *apply* a theme: copy its per-app color files into place, reload the
# running apps, and resolve/install the GTK theme + icon theme it needs.
# 5-dotfiles.sh calls `theme.sh set tokyo-night` (the default) once at the
# end of a fresh install; from then on, run it yourself (or use
# `theme.sh menu`, bound to Super+Shift+T) to switch. See the README's
# theme switching section.
#
# Not `set -e`: reload commands (hyprctl/killall/swaync-client/eww/awww) are
# expected to fail harmlessly if that app isn't running yet -- e.g. right
# after a fresh install, before you've ever logged into Hyprland -- and a
# single failed reload shouldn't abort applying the rest of the theme. Each
# is also wrapped in `timeout` -- these are IPC calls with no built-in
# timeout of their own, and a stale/unresponsive socket makes them hang
# instead of failing, which `|| true` can't rescue from since the command
# never returns.
#-------------------------------------------------------------------------

THEMES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="${THEMES_DIR}/current-theme"

usage() {
    echo "Usage: theme.sh set <name> | list | current | menu" >&2
    exit 1
}

list_themes() {
    find "${THEMES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# --- Find an installed theme/icon folder by a case-insensitive glob,
# trying a couple of likely install roots (system-wide, then user-local --
# AUR packages land in the former, assets theme.sh fetches itself in the
# latter). $1 = subdir under each root (themes/icons), $2 = primary glob,
# $3 = fallback glob (may be empty).
find_asset_dir() {
    local subdir="$1" pattern="$2" fallback="${3:-}" root match
    for root in "/usr/share/${subdir}" "${HOME}/.local/share/${subdir}"; do
        [[ -d "${root}" ]] || continue
        match="$(find "${root}" -maxdepth 1 -iname "${pattern}" -printf '%f\n' 2>/dev/null | sort | head -n1)"
        if [[ -n "${match}" ]]; then
            echo "${match}"
            return 0
        fi
    done
    if [[ -n "${fallback}" && "${fallback}" != "${pattern}" ]]; then
        find_asset_dir "${subdir}" "${fallback}" ""
        return $?
    fi
    return 1
}

# --- Download+extract a theme/icon archive into ~/.local/share/<subdir>
# if it isn't already installed anywhere find_asset_dir looks. Used for
# assets (like Tokyo Night's GTK/icon theme) that aren't packaged in the
# official repos or a known-good AUR package -- see tokyo-night/theme.conf.
fetch_asset() {
    local subdir="$1" url="$2" dest="${HOME}/.local/share/${1}"
    if ! command -v curl >/dev/null 2>&1; then
        echo "WARNING: curl not found -- can't fetch ${url}" >&2
        return 1
    fi
    echo "Fetching ${url} -> ${dest}"
    mkdir -p "${dest}"
    if ! curl --connect-timeout 5 --max-time 30 -fsSL "${url}" | tar xz -C "${dest}"; then
        echo "WARNING: failed to fetch/extract ${url}" >&2
        return 1
    fi
}

# --- Replace the value of a "key: value" / "key=value" style config line
# in place, matched by key prefix so it's safe to run repeatedly (unlike a
# one-shot __PLACEHOLDER__ sed, which only matches the first time).
# $1 = file, $2 = sed-escaped key regex (up to and including the
# separator), $3 = new value.
set_kv() {
    local file="$1" key_re="$2" value="$3"
    [[ -f "${file}" ]] || return 0
    sed -i -E "s|^([[:space:]]*${key_re}).*|\1${value}|" "${file}"
}

apply_gtk_icon_cursor() {
    local theme_conf="$1"
    # shellcheck disable=SC1090
    source "${theme_conf}"
    # shellcheck disable=SC1090
    source "${THEMES_DIR}/global.conf"

    local gtk_theme icon_theme cursor_theme sddm_theme

    gtk_theme="$(find_asset_dir themes "${GTK_THEME_GLOB}" "${GTK_THEME_FALLBACK_GLOB:-}" || true)"
    if [[ -z "${gtk_theme}" && -n "${GTK_THEME_ASSET_URL:-}" ]]; then
        fetch_asset themes "${GTK_THEME_ASSET_URL}" || true
        gtk_theme="$(find_asset_dir themes "${GTK_THEME_GLOB}" "${GTK_THEME_FALLBACK_GLOB:-}" || true)"
    fi
    gtk_theme="${gtk_theme:-Adwaita}"

    icon_theme="$(find_asset_dir icons "${ICON_THEME_GLOB}" "${ICON_THEME_FALLBACK_GLOB:-}" || true)"
    if [[ -z "${icon_theme}" && -n "${ICON_THEME_ASSET_URL:-}" ]]; then
        fetch_asset icons "${ICON_THEME_ASSET_URL}" || true
        icon_theme="$(find_asset_dir icons "${ICON_THEME_GLOB}" "${ICON_THEME_FALLBACK_GLOB:-}" || true)"
    fi
    icon_theme="${icon_theme:-Adwaita}"

    cursor_theme="$(find_asset_dir icons "${CURSOR_THEME_GLOB}" "${CURSOR_THEME_FALLBACK_GLOB:-}" || true)"
    cursor_theme="${cursor_theme:-Adwaita}"

    echo "GTK theme:    ${gtk_theme}"
    echo "Icon theme:   ${icon_theme}"
    echo "Cursor theme: ${cursor_theme}"

    for gtk_dir in gtk-3.0 gtk-4.0; do
        set_kv "${HOME}/.config/${gtk_dir}/settings.ini" 'gtk-theme-name=' "${gtk_theme}"
        set_kv "${HOME}/.config/${gtk_dir}/settings.ini" 'gtk-icon-theme-name=' "${icon_theme}"
        set_kv "${HOME}/.config/${gtk_dir}/settings.ini" 'gtk-cursor-theme-name=' "${cursor_theme}"
    done

    mkdir -p "${HOME}/.icons/default"
    printf '[Icon Theme]\nInherits=%s\n' "${cursor_theme}" > "${HOME}/.icons/default/index.theme"

    set_kv "${HOME}/.config/rofi/config.rasi" 'icon-theme:[[:space:]]*' "\"${icon_theme}\";"
    set_kv "${HOME}/.config/hypr/hyprland.conf" 'env = XCURSOR_THEME,' "${cursor_theme}"
    set_kv "${HOME}/.config/hypr/hyprland.conf" 'env = HYPRCURSOR_THEME,' "${cursor_theme}"

    # qt6ct/xsettingsd -- see the header comments in dotfiles/qt6ct/qt6ct.conf
    # and dotfiles/xsettingsd/xsettingsd.conf for why these exist at all.
    set_kv "${HOME}/.config/qt6ct/qt6ct.conf" 'icon_theme=' "${icon_theme}"
    set_kv "${HOME}/.config/xsettingsd/xsettingsd.conf" 'Net/ThemeName[[:space:]]*' "\"${gtk_theme}\""
    set_kv "${HOME}/.config/xsettingsd/xsettingsd.conf" 'Net/IconThemeName[[:space:]]*' "\"${icon_theme}\""
    set_kv "${HOME}/.config/xsettingsd/xsettingsd.conf" 'Gtk/CursorThemeName[[:space:]]*' "\"${cursor_theme}\""
    # xsettingsd reloads its config on SIGHUP rather than needing a restart.
    timeout 5 killall -HUP xsettingsd >/dev/null 2>&1 || true

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme "${gtk_theme}" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme "${icon_theme}" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    fi

    if [[ -n "${SDDM_THEME_GLOB:-}" ]]; then
        sddm_theme="$(find /usr/share/sddm/themes -maxdepth 1 -iname "${SDDM_THEME_GLOB}" -printf '%f\n' 2>/dev/null | sort | head -n1)"
        if [[ -n "${sddm_theme}" ]]; then
            sudo mkdir -p /etc/sddm.conf.d
            printf '[Theme]\nCurrent=%s\n' "${sddm_theme}" | sudo tee /etc/sddm.conf.d/10-theme.conf > /dev/null
        fi
    fi
}

deploy_colors() {
    local dir="$1"

    cp "${dir}/hypr-colors.conf" "${HOME}/.config/hypr/colors.conf"
    timeout 5 hyprctl reload >/dev/null 2>&1 || true

    mkdir -p "${HOME}/.config/waybar/tokens"
    cp "${dir}/waybar-colors.css" "${HOME}/.config/waybar/tokens/colors.css"
    timeout 5 killall -SIGUSR2 waybar >/dev/null 2>&1 || true

    mkdir -p "${HOME}/.config/swaync/tokens"
    cp "${dir}/swaync-variables.css" "${HOME}/.config/swaync/tokens/variables.css"
    timeout 5 swaync-client -rs >/dev/null 2>&1 || true

    cp "${dir}/wlogout-colors.css" "${HOME}/.config/wlogout/colors.css"

    cp "${dir}/alacritty-colors.toml" "${HOME}/.config/alacritty/colors.toml"

    cp "${dir}/rofi-colors.rasi" "${HOME}/.config/rofi/colors.rasi"

    cp "${dir}/eww-colors.scss" "${HOME}/.config/eww/colors.scss"
    timeout 5 eww reload >/dev/null 2>&1 || true

    # fastfetch has no @import for a separate colors file, so this is the
    # theme's *entire* config, not just a colors partial -- see the
    # comment atop fastfetch-colors.jsonc.
    mkdir -p "${HOME}/.config/fastfetch"
    cp "${dir}/fastfetch-colors.jsonc" "${HOME}/.config/fastfetch/config.jsonc"

    # Same story for the Starship prompt -- no @import, so this is the
    # whole ~/.config/starship.toml, not a colors partial. See the
    # comment atop starship-colors.toml.
    cp "${dir}/starship-colors.toml" "${HOME}/.config/starship.toml"
}

apply_wallpaper() {
    local dir="$1" name="$2"
    [[ -f "${dir}/theme.conf" ]] || return 0
    local wallpaper=""
    # shellcheck disable=SC1090
    wallpaper="$(source "${dir}/theme.conf"; echo "${WALLPAPER:-}")"
    [[ -n "${wallpaper}" && -f "${dir}/${wallpaper}" ]] || return 0

    local dest_dir="${HOME}/Pictures/wallpapers"
    mkdir -p "${dest_dir}"
    local dest="${dest_dir}/${name}.${wallpaper##*.}"
    cp "${dir}/${wallpaper}" "${dest}"

    # Bypasses waypaper's own post_command (matugen) on purpose -- this
    # theme's colors are the curated ones deploy_colors just applied, not
    # ones Matugen should derive from the wallpaper. Picking a wallpaper
    # through waypaper afterward still re-themes dynamically as normal;
    # see the README's theme switching section.
    if command -v awww >/dev/null 2>&1; then
        timeout 5 awww img "${dest}" >/dev/null 2>&1 || true
    fi

    # Refreshes the wallpaper crops a couple of rofi layouts read from
    # ~/.cache/hyde/ (config.rasi's style_10-based header, clipboard.rasi's
    # wallbox/wallframe) -- see gen-wallcache.sh.
    "${HOME}/.config/rofi/gen-wallcache.sh" "${dest}" || true
}

cmd_set() {
    local name="${1:-}"
    [[ -n "${name}" ]] || usage
    local dir="${THEMES_DIR}/${name}"
    if [[ ! -d "${dir}" ]]; then
        echo "ERROR: no theme named '${name}' under ${THEMES_DIR}" >&2
        echo "Available: $(list_themes | tr '\n' ' ')" >&2
        exit 1
    fi

    echo "Applying theme: ${name}"
    deploy_colors "${dir}"
    apply_gtk_icon_cursor "${dir}/theme.conf"
    apply_wallpaper "${dir}" "${name}"
    echo "${name}" > "${MARKER}"
    echo "Done."
}

cmd_menu() {
    if ! command -v rofi >/dev/null 2>&1; then
        echo "ERROR: rofi not found" >&2
        exit 1
    fi
    local current chosen
    current="$(cat "${MARKER}" 2>/dev/null || true)"
    chosen="$(list_themes | sed "s/^${current}\$/${current} (current)/" | rofi -dmenu -p "Theme" -theme "${HOME}/.config/rofi/theme-picker.rasi")"
    [[ -n "${chosen}" ]] || exit 0
    chosen="${chosen% (current)}"
    "${BASH_SOURCE[0]}" set "${chosen}"
}

case "${1:-}" in
    set)     cmd_set "${2:-}" ;;
    list)    list_themes ;;
    current) cat "${MARKER}" 2>/dev/null || echo "(none applied yet)" ;;
    menu)    cmd_menu ;;
    *)       usage ;;
esac
