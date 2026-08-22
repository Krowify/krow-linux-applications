#!/usr/bin/env bash
set -euo pipefail
#-------------------------------------------------------------------------
# Stage 5: Deploy dotfiles and activate the installed themes -- must run
# as a regular, non-root user (same constraint as stage 3), since it
# writes into that user's home directory. The one root-owned exception
# (SDDM's theme selection under /etc/sddm.conf.d) is done via sudo, inside
# theme.sh -- see below.
#-------------------------------------------------------------------------

echo
echo "DEPLOYING DOTFILES"
echo

if [[ ${EUID} -eq 0 ]]; then
    echo "This script must be run as a normal (non-root) user -- it deploys"
    echo "into that user's \$HOME."
    echo "Run: su <your-username>   then re-run this script."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script now lives in scripts/, but dotfiles/ stays at the repo root
# -- one level up.
DOTFILES_DIR="${SCRIPT_DIR}/../dotfiles"

if [[ ! -d "${DOTFILES_DIR}" ]]; then
    echo "ERROR: ${DOTFILES_DIR} not found -- can't deploy dotfiles." >&2
    exit 1
fi

# --- Copy a dotfiles subdirectory into ~/.config, backing up anything
# already there once (to *.bak) rather than silently overwriting it.
deploy_dir() {
    local name="$1"
    local src="${DOTFILES_DIR}/${name}"
    local dest="${HOME}/.config/${name}"

    if [[ -e "${dest}" || -L "${dest}" ]]; then
        # -L too: catches symlinks (e.g. from a dotfile manager), including
        # broken ones -e alone would miss. mv moves the link itself rather
        # than following it, so this never writes through to whatever a
        # symlink points at.
        echo "Backing up existing ~/.config/${name} -> ~/.config/${name}.bak"
        rm -rf "${dest}.bak"
        mv "${dest}" "${dest}.bak"
    fi
    mkdir -p "$(dirname "${dest}")"
    cp -r "${src}" "${dest}"
    echo "Deployed ~/.config/${name}"
}

for dir in hypr waybar alacritty wlogout eww swaync matugen waypaper fastfetch rofi hyde-themes qt6ct xsettingsd; do
    deploy_dir "${dir}"
done
chmod +x "${HOME}/.config/hyde-themes/theme.sh"
chmod +x "${HOME}/.config/rofi/gen-wallcache.sh"

# --- Quickshell dock and workspace overview: each is its own named config
# under ~/.config/quickshell/<name>/ (`qs -c <name>`), not a same-named
# top-level dir the way deploy_dir assumes -- dotfiles/quickshell-dock/
# becomes ~/.config/quickshell/dock/, dotfiles/quickshell-overview/ becomes
# ~/.config/quickshell/overview/. See dotfiles/hypr/hyprland.conf's
# exec-once/keybind lines for how these actually get launched.
for qs_name in dock overview; do
    qs_dest="${HOME}/.config/quickshell/${qs_name}"
    if [[ -e "${qs_dest}" || -L "${qs_dest}" ]]; then
        echo "Backing up existing ~/.config/quickshell/${qs_name} -> ${qs_name}.bak"
        rm -rf "${qs_dest}.bak"
        mv "${qs_dest}" "${qs_dest}.bak"
    fi
    mkdir -p "${HOME}/.config/quickshell"
    cp -r "${DOTFILES_DIR}/quickshell-${qs_name}" "${qs_dest}"
    echo "Deployed ~/.config/quickshell/${qs_name}"
done

# --- waypaper's `folder` setting (dotfiles/waypaper/config.ini) points
# here, and theme.sh drops each theme's own bundled wallpaper (e.g. Tokyo
# Night) into the same place -- create it up front so both have somewhere
# to land before you ever open waypaper.
mkdir -p "${HOME}/Pictures/wallpapers"

# --- gtk-3.0/gtk-4.0: only settings.ini is ours (theme.sh fills in the
# actual theme/icon/cursor names) -- deploy just that file rather than the
# whole directory via deploy_dir, so an existing ~/.config/gtk-*.0 with
# other GTK-managed files (bookmarks, gtkfilechooser.ini, ...) doesn't get
# moved aside wholesale.
for gtk_dir in gtk-3.0 gtk-4.0; do
    dest="${HOME}/.config/${gtk_dir}/settings.ini"
    mkdir -p "$(dirname "${dest}")"
    if [[ -e "${dest}" ]]; then
        echo "Backing up existing ~/.config/${gtk_dir}/settings.ini -> .bak"
        cp "${dest}" "${dest}.bak"
    fi
    cp "${DOTFILES_DIR}/${gtk_dir}/settings.ini" "${dest}"
    echo "Deployed ~/.config/${gtk_dir}/settings.ini"
done

# --- Hide launcher clutter that isn't ours to fix at the source: Avahi
# (not installed by this repo, but a common transitive dependency of other
# packages) ships three .desktop entries that show up in every drun-based
# launcher regardless of whether you use zeroconf browsing. Overriding them
# with NoDisplay=true in ~/.local/share/applications/ (higher XDG precedence
# than /usr/share/applications/) hides them without touching the avahi
# package itself, so a future update can't silently re-clutter the list.
# Copied individually (not via deploy_dir) since ~/.local/share/applications
# holds real installed-app entries this repo shouldn't move aside wholesale.
mkdir -p "${HOME}/.local/share/applications"
cp "${DOTFILES_DIR}/local-applications/"*.desktop "${HOME}/.local/share/applications/"
echo "Deployed ~/.local/share/applications/ overrides (hides Avahi's launcher clutter)"

# --- Vesktop: only the BetterDiscord-style theme(s) under themes/ are
# ours -- deploy just that subfolder rather than the whole directory via
# deploy_dir, so an existing ~/.config/vesktop with Vesktop's own app
# settings/state doesn't get moved aside wholesale. Pick it up in
# Vesktop's Settings -> Themes tab. See the windowrule in
# dotfiles/hypr/hyprland.conf that makes its transparent background
# actually show your wallpaper.
mkdir -p "${HOME}/.config/vesktop/themes"
cp "${DOTFILES_DIR}/vesktop/themes/"*.css "${HOME}/.config/vesktop/themes/"
echo "Deployed ~/.config/vesktop/themes/ (ClearVision V7, Tokyo Night accents)"

# --- starship.toml is a flat file (starship's own default config path,
# unlike everything else here which lives in its own ~/.config subdir).
STARSHIP_DEST="${HOME}/.config/starship.toml"
if [[ -e "${STARSHIP_DEST}" || -L "${STARSHIP_DEST}" ]]; then
    echo "Backing up existing ~/.config/starship.toml -> ~/.config/starship.toml.bak"
    rm -f "${STARSHIP_DEST}.bak"
    mv "${STARSHIP_DEST}" "${STARSHIP_DEST}.bak"
fi
cp "${DOTFILES_DIR}/starship.toml" "${STARSHIP_DEST}"
echo "Deployed ~/.config/starship.toml"

# --- zshrc: append the plugin-sourcing snippet once, idempotently
ZSHRC="${HOME}/.zshrc"
MARKER=">>> linux-installation dotfiles (stage 5) >>>"
touch "${ZSHRC}"
if grep -qF "${MARKER}" "${ZSHRC}"; then
    echo "~/.zshrc already has the stage 5 block, skipping"
else
    echo "Appending zsh plugin config to ~/.zshrc"
    {
        echo
        cat "${DOTFILES_DIR}/zshrc-snippet.sh"
    } >> "${ZSHRC}"
fi

# --- Apply the default theme -- resolves/installs the GTK theme, icon
# theme, cursor theme, and SDDM theme (the last needs sudo -- see
# theme.sh), and deploys the color files every other app in this repo
# imports. Re-run `~/.config/hyde-themes/theme.sh menu` (or Super+Shift+T
# once you're in Hyprland) any time to switch to another theme -- see the
# README's theme switching section.
echo
"${HOME}/.config/hyde-themes/theme.sh" set tokyo-night

echo
echo "Done!"
echo "Log out and back into the 'Hyprland uwsm' session (or"
echo "restart Hyprland with 'hyprctl reload' from inside one) to pick up"
echo "the new config. Pick a wallpaper with 'waypaper' (or Super+Shift+W) --"
echo "until you do, Hyprland/Waybar/SwayNC/Alacritty stay on the current"
echo "theme's static palette."
echo "Want a different look? Super+Shift+T (or"
echo "'~/.config/hyde-themes/theme.sh menu') opens a theme picker -- see"
echo "the README's theme switching section."
echo "Got more than one monitor? Use hyprmod's GUI (in your app launcher)"
echo "to arrange them -- it writes to its own config independently of"
echo "this repo's dotfiles, so it isn't affected by future re-runs of"
echo "this script."
echo
