#!/usr/bin/env bash
set -uo pipefail
#-------------------------------------------------------------------------
# Deployed by 5-dotfiles.sh into ~/.config/rofi/. Regenerates the
# wallpaper-derived crops a couple of borrowed HyDE-Project/HyDE rofi
# layouts expect at fixed paths under ~/.cache/hyde/ (config.rasi's
# style_10-based header, clipboard.rasi's wallbox/wallframe panels) --
# HyDE's own ~/.local/lib/hyde/ scripts generate these on every wallpaper
# change; this repo doesn't install that library, so this is this repo's
# own (much smaller) stand-in for just the handful of crops actually
# referenced.
#
# Wired into two triggers, same as everything else that reacts to a
# wallpaper change in this repo:
#   - waypaper's post_command (dotfiles/waypaper/config.ini), alongside
#     the existing Matugen call, on every manual wallpaper pick.
#   - theme.sh's apply_wallpaper(), on every `theme.sh set <name>`.
#
# Output files intentionally have no extension (wall.blur, not
# wall.blur.png) -- matches the exact paths baked into the borrowed .rasi
# files' url() calls. rofi/cairo sniff the image format from content, not
# the filename, so this is safe; it just has to stay in sync with
# whatever those .rasi files literally reference.
#
# Not `set -e`: a missing/corrupt source image shouldn't take down
# whatever called this (a wallpaper pick, a theme switch) -- fall through
# to WARNING + exit 1 instead, same reasoning as theme.sh's own reload
# calls.
#-------------------------------------------------------------------------

usage() {
    echo "Usage: gen-wallcache.sh <path-to-wallpaper>" >&2
    exit 1
}

SRC="${1:-}"
[[ -n "${SRC}" ]] || usage

if [[ ! -f "${SRC}" ]]; then
    echo "WARNING: gen-wallcache.sh: no such file: ${SRC}" >&2
    exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
    echo "WARNING: gen-wallcache.sh: 'magick' (imagemagick) not found -- skipping" >&2
    exit 1
fi

CACHE_DIR="${HOME}/.cache/hyde"
mkdir -p "${CACHE_DIR}"

# blur: a large, heavily blurred crop -- style_10's inputbar header and
# clipboard's wallbox strip both render this behind a rounded panel, so
# it just needs to fill generously and read as "soft wallpaper," not be
# pixel-accurate.
if ! magick "${SRC}" -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -blur 0x18 png:"${CACHE_DIR}/wall.blur"; then
    echo "WARNING: gen-wallcache.sh: failed to generate wall.blur" >&2
fi

# thmb: a smaller, unblurred square-ish crop -- style_10's rounded header
# panel (this repo's new default launcher).
if ! magick "${SRC}" -resize 640x640^ -gravity center -extent 640x640 \
        png:"${CACHE_DIR}/wall.thmb"; then
    echo "WARNING: gen-wallcache.sh: failed to generate wall.thmb" >&2
fi

# quad: a narrower square crop -- clipboard's 5em-wide wallframe strip.
if ! magick "${SRC}" -resize 400x400^ -gravity center -extent 400x400 \
        png:"${CACHE_DIR}/wall.quad"; then
    echo "WARNING: gen-wallcache.sh: failed to generate wall.quad" >&2
fi
