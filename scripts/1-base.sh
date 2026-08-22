#!/usr/bin/env bash
set -euo pipefail
#-------------------------------------------------------------------------
# Stage 1: Base system, display server, desktop, networking, audio, bluetooth
#-------------------------------------------------------------------------
 
echo
echo "Installing Base System"
echo
 
# Works whether this is run as root (typical right after a fresh Arch
# install) or as a regular user that already has sudo configured.
if [[ ${EUID} -eq 0 ]]; then
    PACMAN=(pacman)
else
    PACMAN=(sudo pacman)
fi
 
# Make sure sudo itself exists before later stages rely on it.
"${PACMAN[@]}" -S --noconfirm --needed sudo
 
PKGS=(
    # --- WAYLAND CORE
    'wayland'                 # Core Wayland display server protocol libs
    'wayland-protocols'       # Additional/staging Wayland protocol extensions
    'xorg-xwayland'           # Runs X11-only apps inside a Wayland session
                               # (was 'xorg-server-xwayland' years ago; the
                               # current package name is 'xorg-xwayland')
    'mesa'                    # Open source OpenGL/Vulkan implementation --
                               # Hyprland renders through this directly via
                               # DRM/KMS, no separate xf86-video-* driver
                               # needed for AMD/Intel the way Xorg required
    # NOTE: no standalone 'wlroots' package here on purpose. Hyprland used
    # to be built on system wlroots, but as of 0.42 it ships its own
    # rendering backend ('aquamarine') instead and pulls it in automatically
    # as a dependency of the 'hyprland' package below -- there's nothing
    # separate to install for it.

    # --- Boot splash (Plymouth, requires GRUB as the bootloader)
    # NOTE: the actual mkinitcpio-hook/GRUB-kernel-param wiring for this is
    # done in stage 6, not here -- running it as the last root-level stage,
    # after all package installs are done, means 'mkinitcpio -P' and
    # 'grub-mkconfig' always see the final, fully-installed set of kernels
    # and packages, regardless of what stage 1/2 end up installing.
    'plymouth'                 # Graphical boot splash daemon

    # --- Setup Desktop
    # (was 'plasma-meta' / KDE Plasma running on Xorg. Replaced with
    # Hyprland, a standalone Wayland compositor, plus the support packages
    # it needs -- these used to be pulled in transitively by plasma-meta.)
    'hyprland'                    # Wayland compositor / window manager
    'uwsm'                        # Universal Wayland Session Manager --
                                   # current recommended way to launch
                                   # Hyprland; wires the session into a
                                   # systemd graphical-session target, which
                                   # xdg-desktop-portal and friends expect
    'xdg-desktop-portal-hyprland'  # Portal backend for Hyprland (screen
                                    # share, screenshots, native file pickers)
    'xdg-desktop-portal-gtk'      # Fallback portal backend for GTK apps
                                   # (e.g. file-roller's, LibreOffice's file
                                   # picker dialogs)
    'qt5-wayland'                 # Wayland support for Qt5 apps
    'qt6-wayland'                 # Wayland support for Qt6 apps
    'hyprpolkitagent'             # GUI polkit auth-prompt agent -- with
                                   # Plasma gone there's nothing else
                                   # supplying one
    'hypridle'                    # Idle daemon (screen-off / lock / suspend
                                   # on timeout)
    'hyprlock'                    # Screen locker
    # NOTE: no wallpaper daemon here on purpose -- 'awww' (stage 2) plus
    # 'waypaper' (stage 3, AUR) as the GUI picker on top of it handle
    # wallpapers now, including triggering Matugen to re-theme the desktop
    # whenever the wallpaper changes. See the README's color theming section.

    # --- Display / Login Manager
    # The 'hyprland' package ships wayland-sessions .desktop entries
    # automatically (a plain "Hyprland" entry, plus a "Hyprland
    # (uwsm-managed)" entry once uwsm is present), so SDDM picks it up with
    # nothing extra to configure. SDDM's own greeter still renders in X11
    # by default even when launching a Wayland session underneath -- that's
    # expected and doesn't affect the session you actually log into. (Stage
    # 6 shortens the uwsm entry's display name to "Hyprland uwsm" -- the
    # package's default is too long for some SDDM themes.)
    'sddm'                    # Display manager (login screen)
 
    # --- Networking Setup
    'dialog'                  # Lets shell scripts trigger dialog boxes
    'networkmanager'          # Network connection manager
    'openvpn'                 # OpenVPN support
    'networkmanager-openvpn'  # OpenVPN plugin for NM
    'network-manager-applet'  # System tray network utility -- under Hyprland
                               # this needs a tray host to actually be
                               # visible; waybar's tray module (stage 2)
                               # covers that
    # NOTE: no standalone 'dhclient' here on purpose. NetworkManager uses
    # its own internal DHCP client by default (internal/dhcpcd, configurable
    # via /etc/NetworkManager/NetworkManager.conf's [main] dhcp= setting) --
    # it doesn't shell out to dhclient unless explicitly told to, so it was
    # dead weight.
    'libsecret'               # Library for storing passwords
    'fail2ban'                # Ban IPs after repeated failed logins
    'ufw'                     # Uncomplicated firewall
    'proton-vpn-gtk-app'      # ProtonVPN client
 
    # --- Audio
    'alsa-utils'              # ALSA components
    'alsa-plugins'            # ALSA plugins
    'pipewire'                # Pipewire audio server
    'wireplumber'             # Pipewire's session/policy manager -- required
                               # for pipewire to actually route audio;
                               # pipewire-media-session (the old alternative)
                               # is deprecated
    'pipewire-pulse'          # PulseAudio-compatible server on top of
                               # pipewire, so Pulse-only apps keep working
    'pipewire-alsa'           # ALSA client support routed through pipewire
    # NOTE: 'pnmixer' used to be listed here but it's AUR-only -- a plain
    # `pacman -S pnmixer` always fails with "target not found". It's been
    # dropped from stage 3 too: it's a legacy GtkStatusIcon tray app, which
    # is one of the more unreliable tray-icon types under Wayland. Use
    # waybar's built-in pulseaudio module or the `pamixer` CLI instead
    # (both stage 2), or `pavucontrol` for a full GUI mixer.
 
    # --- Bluetooth
    'bluez'                   # Bluetooth protocol stack daemons
    'bluez-utils'             # Bluetooth development/debug utilities
    'bluez-libs'              # Bluetooth libraries
    # NOTE: 'bluez-firmware' used to be listed here but it was pulled from
    # the official repos years ago and no longer exists there. If your
    # Bluetooth chip needs firmware, check the AUR (e.g. broadcom-bt-firmware)
    # or see if it's already covered by the 'linux-firmware' package.
    # A GUI/tray manager ('blueman') is installed in stage 2, since Plasma
    # no longer provides one automatically.
)
 
for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    "${PACMAN[@]}" -S --noconfirm --needed "${PKG}"
done

# ------------------------------------------------------------------------
# GPU driver -- AMD and Intel render through mesa (already installed
# above) with no extra driver needed. Nvidia needs its own proprietary
# driver installed and, later, a kernel parameter set (that part happens
# in stage 6, once mkinitcpio/GRUB have seen every installed kernel).
echo
echo "GPU driver setup"
echo "Wayland/Hyprland render through mesa using the kernel's own DRM/KMS"
echo "drivers -- AMD and Intel need nothing further. Nvidia is the"
echo "exception: it needs its own proprietary driver."
echo

DETECTED_GPU=""
if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qi 'nvidia'; then
        DETECTED_GPU="nvidia"
    elif lspci | grep -qiE 'intel.*(vga|graphics|display)'; then
        DETECTED_GPU="intel"
    elif lspci | grep -qiE '(vga|display).*amd|amd.*(vga|display)|advanced micro devices.*display'; then
        DETECTED_GPU="amd"
    fi
fi
if [[ -n "${DETECTED_GPU}" ]]; then
    echo "Detected GPU (via lspci): ${DETECTED_GPU}"
fi

while true; do
    read -rp "Which GPU are you using? [intel/nvidia/amd] ${DETECTED_GPU:+(detected: ${DETECTED_GPU}) }: " GPU_CHOICE
    GPU_CHOICE="${GPU_CHOICE,,}"
    [[ -z "${GPU_CHOICE}" && -n "${DETECTED_GPU}" ]] && GPU_CHOICE="${DETECTED_GPU}"
    case "${GPU_CHOICE}" in
        intel|amd)
            echo "mesa (already installed above) is all ${GPU_CHOICE} needs -- nothing further to install."
            break
            ;;
        nvidia)
            echo "Installing Nvidia drivers..."
            NVIDIA_PKGS=(
                'nvidia-open'   # Open-kernel Nvidia driver module (Turing/2018+
                                 # cards). Use 'nvidia' instead if yours is older.
                'nvidia-utils'  # Userspace driver libraries (OpenGL/Vulkan)
                'egl-wayland'   # EGL layer Wayland compositors need to use the
                                 # Nvidia driver
            )
            for PKG in "${NVIDIA_PKGS[@]}"; do
                echo "INSTALLING: ${PKG}"
                "${PACMAN[@]}" -S --noconfirm --needed "${PKG}"
            done
            echo "NOTE: if your card is older than Turing (pre-GTX 16xx/RTX 20xx)"
            echo "and fails to boot into Hyprland, swap 'nvidia-open' for 'nvidia':"
            echo "  sudo pacman -S --needed nvidia nvidia-utils egl-wayland"
            echo "'nvidia_drm.modeset=1' gets added to your kernel parameters"
            echo "automatically in stage 6."
            break
            ;;
        *)
            echo "Please answer 'intel', 'nvidia', or 'amd'."
            ;;
    esac
done

echo "NOTE: Plymouth is installed but not yet wired into mkinitcpio/GRUB --"
echo "that happens in stage 6, after the second kernel (stage 2) is in"
echo "place."
echo
echo "Done!"
echo
