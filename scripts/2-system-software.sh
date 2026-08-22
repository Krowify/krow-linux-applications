#!/usr/bin/env bash
set -euo pipefail
#-------------------------------------------------------------------------
# Stage 2: Everyday software from the official repositories
#-------------------------------------------------------------------------
 
echo
echo "INSTALLING SOFTWARE"
echo
 
if [[ ${EUID} -eq 0 ]]; then
    PACMAN=(pacman)
else
    PACMAN=(sudo pacman)
fi
 
PKGS=(
    # SYSTEM ----------------------------------------------------------
    # NOTE: no kernel package here on purpose. The base Arch install this
    # repo runs on top of (per the README) already installed one, and
    # 'linux-lts' used to be added on top of it unconditionally -- that
    # just gives you two kernels (and two GRUB entries, two initramfs
    # rebuilds on every kernel-related change) with no real benefit for a
    # single-kernel desktop setup. If you specifically want an LTS kernel
    # as a fallback, add 'linux-lts' back here.
    'base-devel'                # Needed to build AUR packages in stage 3
 
    # TERMINAL UTILITIES ------------------------------------------------
    'bleachbit'                  # File deletion utility
    'cmatrix'                    # The Matrix screen animation
    'cronie'                     # cron jobs
    'curl'                       # Remote content retrieval
    'fastfetch'                   # System info banner, shown on every new
                                   # terminal via the zshrc snippet
    'file-roller'                # Archive utility
    'fzf'                         # Fuzzy finder -- shell completion/
                                   # history search, wired up in the
                                   # zshrc snippet
    'gufw'                       # Firewall manager
    # NOTE: 'hardinfo' used to be listed here but it was pulled from the
    # official repos -- a plain `pacman -S hardinfo` fails with "target
    # not found". Its replacement, 'hardinfo2', isn't reliably in the
    # stable 'extra' repo yet at the time of writing (it's been sitting
    # in extra-testing), so it's installed via AUR in stage 3 instead.
    'htop'                       # Process viewer
    'ntp'                        # Network Time Protocol
    'p7zip'                      # 7z compression program
    'rsync'                      # Remote file sync utility
    'speedtest-cli'              # Internet speed via terminal
    'unrar'                      # RAR compression program
    'unzip'                      # Zip compression program
    'wget'                       # Remote content retrieval
    'kate'                       # GUI text editor (KDE) -- pulls in some KDE
                                  # Frameworks/Qt libs as dependencies, but
                                  # doesn't need Plasma itself
    'zenity'                     # Graphical dialog boxes from shell scripts
    'zsh'                        # Interactive shell
    'zsh-autosuggestions'        # Zsh plugin
    'zsh-syntax-highlighting'    # Zsh plugin
    'starship'                    # Shell prompt, replaces zsh's default --
                                   # config deployed to ~/.config/
                                   # starship.toml (a flat file, unlike
                                   # most of this repo's other dotfiles),
                                   # initialized in the zshrc snippet
    'zoxide'                      # Smarter 'cd' that learns frequently/
                                   # recently used directories -- takes
                                   # over the 'cd' command itself, see the
                                   # zshrc snippet
 
    # GENERAL UTILITIES --------------------------------------------------
    'clamav'                     # Anti-virus
 
    # DEVELOPMENT ----------------------------------------------------------
    'cmake'                      # Cross-platform open-source make system
    'electron'                   # Cross-platform development using JS
    'git'                        # Version control system
    'gcc'                        # C/C++ compiler
    'glibc'                      # C libraries
    'meld'                       # File/directory comparison
    'nodejs'                     # JavaScript runtime environment
    'npm'                        # Node package manager
    'python'                     # Scripting language
    'yarn'                       # Dependency management
 
    # MEDIA -----------------------------------------------------------------
    'celluloid'                  # Video player
    'feh'                        # Image viewer (X11-native, runs fine via
                                  # the xorg-xwayland installed in stage 1)
 
    # PRODUCTIVITY --------------------------------------------------------------
    'libreoffice-still'          # LibreOffice
    'torbrowser-launcher'        # Tor Browser
 
    # WAYLAND / HYPRLAND DESKTOP ---------------------------------------------
    # (was THEMES: 'breeze-gtk' / 'breeze-icons' / 'plasma-workspace'. Those
    # needed plasma-workspace's KDE config modules to actually apply, which
    # no longer makes sense without Plasma. Replaced with a DE-agnostic
    # icon theme plus the bar/launcher/notification/tray stack Hyprland
    # doesn't provide on its own -- KDE Plasma used to supply all of this.)
    'waybar'                      # Status bar
    'swaync'                      # Notification daemon + control center
                                   # (Wayland-native) -- replaces mako
    'rofi'                        # Application launcher -- replaces
                                   # vicinae. Rofi merged native Wayland
                                   # support upstream in 2025, so the
                                   # official package needs no separate
                                   # 'rofi-wayland' fork anymore; if
                                   # yours predates that, swap this for
                                   # the AUR 'rofi-wayland' package
    'awww'                        # Wallpaper daemon with smooth
                                   # transitions -- renamed from 'swww' in
                                   # October 2025 (moved to Codeberg); the
                                   # old 'swww'/'swww-daemon' names no
                                   # longer exist, this is now 'awww'/
                                   # 'awww-daemon'. Official repo, not
                                   # AUR, since the rename. 'waypaper'
                                   # (stage 3) is the GUI picker that
                                   # actually renders through this
    'grim'                        # Screenshot utility
    'slurp'                       # Region/window selector, used with grim
    'imagemagick'                 # Provides 'magick', used by
                                   # dotfiles/rofi/gen-wallcache.sh to
                                   # blur/crop the current wallpaper for
                                   # a couple of rofi layouts
    'hyprsunset'                  # Blue light filter, toggled with
                                   # Super+Shift+N
    'qt6ct'                       # Qt6 platform theme -- makes Qt apps
                                   # (kate, pavucontrol, ...) pick up the
                                   # GTK theme instead of rendering
                                   # unstyled; see dotfiles/qt6ct/
    'xsettingsd'                  # Propagates theme/icon/cursor to GTK2/
                                   # Xwayland clients via XSETTINGS; see
                                   # dotfiles/xsettingsd/
    'jq'                          # JSON processing -- used by a couple of
                                   # hyprland.conf's own keybinds (focused-
                                   # monitor screenshot, dropdown terminal
                                   # detection) instead of hand-rolled awk
    'wl-clipboard'                # Wayland clipboard CLI (wl-copy/wl-paste)
    'cliphist'                    # Clipboard history manager, layered on top
                                   # of wl-clipboard -- 'wl-clipboard' alone
                                   # has no history/browsing UI
    'brightnessctl'               # Screen brightness control
    'power-profiles-daemon'       # Power profile (performance/balanced/
                                   # power-saver) switching -- backs the
                                   # power-profiles-daemon waybar module.
                                   # Service enabled in stage 6
    'pamixer'                     # CLI volume control (pipewire-pulse aware)
    'pavucontrol'                 # GUI volume mixer, invoked directly rather
                                   # than via a tray icon
    'playerctl'                   # CLI media player control (play/pause/next/
                                   # prev) -- backs the XF86Audio* media keys
                                   # and waybar's mpris module
    'alacritty'                   # Terminal emulator, replaces 'kitty'/'xterm'
    'blueman'                     # Bluetooth GUI manager + tray applet --
                                   # Plasma no longer supplies one
    'papirus-icon-theme'          # Icon theme (works standalone, no KDE
                                   # config modules required)
    'ttf-nerd-fonts-symbols'      # Icon glyphs most waybar/launcher configs
                                   # assume are available
    'ttf-jetbrains-mono-nerd'     # Full JetBrains Mono Nerd Font, for a
                                   # patched monospace font in the terminal
    'noto-fonts'                  # Google Noto fonts -- broad Unicode
                                   # coverage as the general UI/fallback font
    'noto-fonts-emoji'            # Color emoji glyphs (Noto's own, not the
                                   # nerd-fonts symbol set above)

    # FILE MANAGER ------------------------------------------------------
    'thunar'                      # GUI file manager
    'thunar-archive-plugin'       # Right-click archive/extract via
                                   # file-roller (already installed above)
    'gvfs'                        # Trash, network shares (smb/sftp/mtp) and
                                   # removable-media mounting inside Thunar

    # MUSIC -----------------------------------------------------------------
    'spotify-launcher'            # Installs/updates the official Spotify
                                   # client into your own home directory and
                                   # launches it -- the ArchWiki-recommended
                                   # way to run Spotify, since it lets
                                   # Spotify self-update instead of relying
                                   # on a repackaged pacman/AUR build
)
 
echo "NOTE: 'code' (VS Code) has been removed from this list -- it is not"
echo "available in the official Arch repos. It's installed from the AUR"
echo "instead in stage 3 (visual-studio-code-bin)."
echo
 
for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    "${PACMAN[@]}" -S --noconfirm --needed "${PKG}"
done

# ------------------------------------------------------------------------
# ncurses (not --needed, deliberately, unlike the loop above): the
# 'alacritty' TERM/terminfo entry ships in ncurses, not the alacritty
# package -- it's only alacritty's *optional* dependency, so pacman never
# guarantees it's present at a version that actually has it. ncurses is
# almost always already installed as a base dependency (of bash/readline),
# just possibly at an older version predating that terminfo addition --
# --needed would skip it in that case and leave the problem in place.
# Missing it causes ncurses apps (vim, nvim, htop, ...) to fail with
# "unable to find terminal" inside Alacritty.
echo
echo "Ensuring ncurses is current (provides Alacritty's terminfo entry)"
"${PACMAN[@]}" -S --noconfirm ncurses

echo
echo "Done!"
echo
