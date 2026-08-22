#!/usr/bin/env bash
set -euo pipefail
#-------------------------------------------------------------------------
# Stage 3: AUR software -- must be run as a regular, non-root user
#-------------------------------------------------------------------------
 
echo
echo "INSTALLING AUR SOFTWARE"
echo
 
if [[ ${EUID} -eq 0 ]]; then
    echo "This script must be run as a normal (non-root) user -- makepkg"
    echo "refuses to build packages as root."
    echo "Run: su <your-username>   then re-run this script."
    exit 1
fi
 
# --- Install yay (AUR helper) if it isn't already present
if ! command -v yay >/dev/null 2>&1; then
    YAY_DIR="${HOME}/yay"
    if [[ -d "${YAY_DIR}" ]]; then
        echo "Existing ${YAY_DIR} found, updating instead of re-cloning"
        git -C "${YAY_DIR}" pull
        # Drop any build artifacts (src/, pkg/, old .pkg.tar.*) left over from a
        # prior run -- makepkg reusing these can produce a package pacman
        # refuses to install, which makepkg only reports as a non-fatal
        # "WARNING: Failed to install built package(s)." (it doesn't exit
        # non-zero), so a stale build silently slips past `set -e` here.
        git -C "${YAY_DIR}" clean -xdf
    else
        echo "CLONING: yay"
        git clone "https://aur.archlinux.org/yay-bin.git" "${YAY_DIR}"
    fi
    (cd "${YAY_DIR}" && makepkg -si --noconfirm)

    # makepkg's own install-failure warning above isn't fatal, so verify
    # yay actually landed on PATH instead of trusting its exit code.
    if ! command -v yay >/dev/null 2>&1; then
        echo "ERROR: yay build finished but 'yay' is not on PATH -- the" >&2
        echo "install step failed. Check the makepkg output above (a" >&2
        echo "'WARNING: Failed to install built package(s).' line is the" >&2
        echo "usual sign) and re-run this script." >&2
        exit 1
    fi
else
    echo "yay is already installed, skipping build"
fi
 
PKGS=(
    # UTILITIES -------------------------------------------------------
    'timeshift'                          # Backup and restore
    'autojump'                           # Zsh plugin
    # NOTE: 'pnmixer' used to be listed here as a tray volume control, but
    # it's a legacy GtkStatusIcon app -- one of the tray-icon types most
    # likely to not show up at all under a Wayland tray. Dropped in favor
    # of 'pamixer' (CLI) and 'pavucontrol' (GUI), both installed in stage 2.
    'hardinfo2-git'                      # Hardware info app (replacement for
                                          # 'hardinfo', removed from the official
                                          # repos -- moved here from stage 2)
    'paru-bin'                           # Second AUR helper/pacman wrapper,
                                          # alongside yay above -- prebuilt so
                                          # it doesn't need a Rust toolchain

    # BROWSERS / COMMUNICATIONS ------------------------------------------
    'brave-bin'                          # Brave browser
    'discord'                            # Chat for gamers
    'vencord-bin'                        # Discord client mod, prebuilt --
                                          # patches Discord directly, no
                                          # separate installer GUI

    # EDITORS ---------------------------------------------------------------
    'visual-studio-code-bin'             # VS Code (not in official repos)

    # WAYLAND / HYPRLAND DESKTOP ------------------------------------------
    # NOTE: 'eww-wayland' used to be a separate split package for a
    # Wayland-only build (skipping the X11 backend), but it's been removed
    # from the AUR -- yay reports "target not found" for it now. Its
    # functionality was folded back into the main 'eww' pkgbase, so that's
    # what's installed here.
    'eww'                                 # Widget system
    'wlogout'                            # Wayland-native logout/power menu --
                                          # AUR-only, not in the official repos
    'swayosd-git'                        # On-screen volume/brightness/caps-
                                          # lock display -- hyprland.conf's
                                          # hardware-control binds route
                                          # through 'swayosd-client' instead
                                          # of pamixer/brightnessctl directly
                                          # so you actually see feedback
    'hyprmod'                            # GTK4/libadwaita settings GUI for
                                          # Hyprland -- live-previews changes,
                                          # writes to its own config rather
                                          # than touching hyprland.conf
    'waypaper'                           # GUI wallpaper picker, frontend for
                                          # awww (stage 2, official repo) --
                                          # replaces swaybg/hyprpaper;
                                          # configured to trigger Matugen on
                                          # every wallpaper change (see
                                          # dotfiles/waypaper/config.ini)
    'matugen-bin'                        # Generates a Material You color
                                          # scheme from the current wallpaper
                                          # and re-themes Hyprland/Waybar/
                                          # SwayNC/Alacritty from it -- see
                                          # the README's color theming section

    # THEMES -----------------------------------------------------------------
    # No SDDM login theme package here anymore -- Qylock's 'pixel-sakura'
    # (github.com/Darkkal44/qylock) isn't packaged for the AUR, so it's
    # installed by hand further down instead. This only themes the SDDM
    # login screen itself, independent of the Hyprland session you log
    # into afterward -- it doesn't need Plasma and nothing above changes
    # how it works.
    'bibata-cursor-theme-bin'            # Cursor theme, prebuilt

    # PRODUCTIVITY -----------------------------------------------------------
    'proton-mail-bin'                    # Proton Mail desktop app, prebuilt
    'obsidian'                           # Obsidean Note Taking
)
 
for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    yay -S --noconfirm --needed "${PKG}"
done

# --- Install Qylock's 'pixel-sakura' SDDM theme. It isn't packaged in the
# AUR, so it's pulled straight from its GitHub repo instead of via yay --
# only the one theme subfolder is copied (it's fully self-contained, no
# shared assets live elsewhere in that repo). Qylock's own sddm.sh
# installer is skipped entirely: it's interactive (prompts for Qt5/Qt6 and
# a theme choice on stdin), which doesn't work unattended here, and
# writing the active theme into /etc/sddm.conf.d is already handled by
# theme.sh (via SDDM_THEME_GLOB in global.conf) once stage 5 runs.
echo
echo "Installing Qylock 'pixel-sakura' SDDM theme"
QYLOCK_DIR="$(mktemp -d)"
git clone --depth 1 https://github.com/Darkkal44/qylock.git "${QYLOCK_DIR}"
sudo mkdir -p /usr/share/sddm/themes
sudo rm -rf /usr/share/sddm/themes/pixel-sakura
sudo cp -r "${QYLOCK_DIR}/themes/pixel-sakura" /usr/share/sddm/themes/pixel-sakura
rm -rf "${QYLOCK_DIR}"
echo "NOTE: this theme's clock/text wants the 'Pixelify Sans' font (a free"
echo "Google/OFL-licensed font). If it doesn't render with it, download the"
echo "font and drop the .ttf into"
echo "/usr/share/sddm/themes/pixel-sakura/font/ -- see qylock's own README"
echo "for details."

# --- Change default shell to zsh. Via sudo, not plain chsh: chsh
# authenticates through PAM using your own login password, which fails
# with "Authentication failure" when this script runs non-interactively
# under install.sh's `su - <user> -c ...` (no reliable controlling
# terminal to read a password from -- same issue as the sudo pacman/mkdir/
# tee calls elsewhere in this repo). Root doesn't need a password to
# change a user's shell, so routing through sudo sidesteps it; install.sh
# grants NOPASSWD for this exact call during stage 3.
echo
echo "Changing default shell to zsh"
sudo chsh -s "$(command -v zsh)"
 
echo
echo "Done!"
echo
