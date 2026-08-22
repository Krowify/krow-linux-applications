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
    'quickshell'                         # QtQuick-based shell toolkit --
                                          # backs the dock and workspace
                                          # overview below. Routed through
                                          # yay rather than stage 2's plain
                                          # pacman since this repo hasn't
                                          # confirmed it's in the official
                                          # repos on every install target
                                          # (yay falls back to pacman
                                          # transparently either way, so
                                          # this is safe regardless)
    'quickshell-overview-git'            # Workspace overview module (all
                                          # workspaces at once, live window
                                          # previews, drag-and-drop) --
                                          # ported from Shanu-Kumawat/
                                          # quickshell-overview, its own
                                          # separately-maintained project
                                          # with this AUR package; see
                                          # dotfiles/quickshell-overview/.
                                          # The dock (dotfiles/quickshell-
                                          # dock/) has no equivalent
                                          # standalone package -- it's
                                          # ported directly from
                                          # mylinuxforwork/dotfiles instead

    # THEMES -----------------------------------------------------------------
    # This only themes the SDDM login screen itself, independent of the
    # Hyprland session you log into afterward -- it doesn't need Plasma and
    # nothing above changes how it works.
    'sddm-theme-elegant-archlinux-git'   # SDDM login theme
    'bibata-cursor-theme-bin'            # Cursor theme, prebuilt

    # PRODUCTIVITY -----------------------------------------------------------
    'proton-mail-bin'                    # Proton Mail desktop app, prebuilt
    'obsidian'                           # Obsidean Note Taking
)
 
for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    yay -S --noconfirm --needed "${PKG}"
done
 
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
