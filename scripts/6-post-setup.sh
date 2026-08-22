#!/usr/bin/env bash
set -euo pipefail
#-------------------------------------------------------------------------
# Stage 6: Final setup and configuration
#-------------------------------------------------------------------------
 
if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

# --- The desktop user theme.sh needs a passwordless sudo grant for (see
# below) -- an optional first argument (install.sh passes AUR_USER),
# falling back to $SUDO_USER (this script invoked via sudo) or $USER (run
# directly as the desktop user, using the SUDO=(sudo) wrapper above for
# individual commands instead).
TARGET_USER="${1:-${SUDO_USER:-${USER}}}"

echo
echo "FINAL SETUP AND CONFIGURATION"
 
# ------------------------------------------------------------------------
echo
echo "Increasing file watcher count"
echo "(prevents a 'too many files' error in editors like VS Code)"
echo "fs.inotify.max_user_watches=524288" | "${SUDO[@]}" tee /etc/sysctl.d/40-max-user-watches.conf > /dev/null
"${SUDO[@]}" sysctl --system
 
# ------------------------------------------------------------------------
# Shorten the uwsm-managed Hyprland session's display name in SDDM's
# session dropdown. The hyprland/uwsm packages ship it as "Hyprland
# (uwsm-managed)" -- too long for some SDDM themes (e.g. Qylock's
# pixel-sakura, stage 3) and it gets clipped/overlapped there. This
# patches the package-owned .desktop file directly, so it re-runs every
# time this stage runs (not just once): the file isn't a pacman "backup"
# config, so a future hyprland/uwsm package update silently overwrites it
# back to the long name with no .pacnew warning to catch it.
echo
echo "Shortening the uwsm-managed Hyprland session name in SDDM"
UWSM_SESSION_DESKTOP="$(grep -rlF 'uwsm-managed' /usr/share/wayland-sessions/*.desktop 2>/dev/null | head -n1)"
if [[ -n "${UWSM_SESSION_DESKTOP}" ]]; then
    "${SUDO[@]}" sed -i 's/^Name=.*/Name=Hyprland uwsm/' "${UWSM_SESSION_DESKTOP}"
    echo "Patched ${UWSM_SESSION_DESKTOP} -> Name=Hyprland uwsm"
else
    echo "WARNING: no wayland-sessions .desktop file mentioning" >&2
    echo "'uwsm-managed' found under /usr/share/wayland-sessions -- skipping." >&2
    echo "Check that the hyprland/uwsm packages are installed; the file this" >&2
    echo "patches may also have been renamed by a newer package version." >&2
fi

# ------------------------------------------------------------------------
echo
echo "Enabling login display manager"
"${SUDO[@]}" systemctl enable --now sddm.service
echo "NOTE: at the SDDM login screen, pick 'Hyprland uwsm' from the session"
echo "dropdown if it's offered -- that's the currently recommended way to"
echo "launch it. A plain 'Hyprland' entry is also available if you'd"
echo "rather not use uwsm."
echo
echo "NOTE: pipewire/wireplumber run as user (not system) services and are"
echo "generally auto-started on login via socket activation. If audio isn't"
echo "working after your first login, check with:"
echo "  systemctl --user status pipewire wireplumber pipewire-pulse"
echo "and enable them yourself if needed:"
echo "  systemctl --user enable --now pipewire wireplumber pipewire-pulse"
 
# ------------------------------------------------------------------------
echo
echo "Enabling bluetooth daemon and setting it to auto-start"
if [[ -f /etc/bluetooth/main.conf ]]; then
    "${SUDO[@]}" sed -i 's|#AutoEnable=false|AutoEnable=true|g' /etc/bluetooth/main.conf
else
    # bluez normally ships this file -- if it's missing (partial/odd
    # install), don't let that abort the rest of this stage (Plymouth/
    # GRUB, Nvidia) under set -e. bluetooth.service still starts fine
    # with default settings; it just won't auto-power-on adapters.
    echo "WARNING: /etc/bluetooth/main.conf not found -- skipping the" >&2
    echo "AutoEnable tweak. Enabling bluetooth.service anyway." >&2
fi
"${SUDO[@]}" systemctl enable --now bluetooth.service

# ------------------------------------------------------------------------
echo
echo "Enabling power-profiles-daemon (backs the waybar power-profile module)"
"${SUDO[@]}" systemctl enable --now power-profiles-daemon.service

# ------------------------------------------------------------------------
# Permanent (unlike the install-time drop-ins in install.sh, this one is
# never removed) NOPASSWD grant for the exact SDDM theme-write commands
# theme.sh runs on every theme switch (see dotfiles/hyde-themes/theme.sh)
# -- without it, every future `theme.sh set`/`theme.sh menu` prompts for
# your password. Scoped to just those two commands, not sudo as a whole.
echo
echo "Granting ${TARGET_USER} passwordless sudo for the SDDM theme write"
echo "(so future theme switches via theme.sh don't prompt for a password)"
SDDM_SUDOERS_DROPIN="/etc/sudoers.d/99-linux-installation-theme-sddm"
echo "${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/bin/mkdir -p /etc/sddm.conf.d, /usr/bin/tee /etc/sddm.conf.d/10-theme.conf" | "${SUDO[@]}" tee "${SDDM_SUDOERS_DROPIN}" > /dev/null
"${SUDO[@]}" chmod 0440 "${SDDM_SUDOERS_DROPIN}"
if ! "${SUDO[@]}" visudo -cf "${SDDM_SUDOERS_DROPIN}"; then
    echo "WARNING: generated sudoers drop-in failed validation -- removing" >&2
    echo "it. Theme switches will keep prompting for your password; fix" >&2
    echo "${SDDM_SUDOERS_DROPIN} by hand if you want this passwordless." >&2
    "${SUDO[@]}" rm -f "${SDDM_SUDOERS_DROPIN}"
fi

# ------------------------------------------------------------------------
# Plymouth boot splash wiring (mkinitcpio hook + GRUB kernel param). This
# runs here, as the last root-level stage, rather than in stage 1, so it
# always sees the final set of installed kernels/packages instead of
# depending on install ordering within stages 1-2.
echo
echo "Configuring Plymouth boot splash"
if grep -q '\bplymouth\b' /etc/mkinitcpio.conf 2>/dev/null; then
    echo "plymouth hook already present in /etc/mkinitcpio.conf, skipping"
else
    # Plymouth needs to hook in before any hook that might print to the
    # console (e.g. 'block'/'filesystems'/'fsck'), and after 'udev' so
    # device nodes exist -- 'base udev ... ' is what a stock, freshly
    # installed mkinitcpio.conf starts with.
    "${SUDO[@]}" sed -i 's/^HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
    if grep -q '\bplymouth\b' /etc/mkinitcpio.conf; then
        "${SUDO[@]}" mkinitcpio -P
    else
        echo "WARNING: could not find 'HOOKS=(base udev ...' in" >&2
        echo "/etc/mkinitcpio.conf to patch -- it's been customized from the" >&2
        echo "stock layout. Add 'plymouth' to the HOOKS array yourself (right" >&2
        echo "after 'udev') and run 'mkinitcpio -P'." >&2
    fi
fi

GRUB_PARAMS_TO_ADD=()
if command -v grub-mkconfig >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
    if grep -q 'splash' /etc/default/grub; then
        echo "GRUB already has 'splash' on the kernel command line, skipping"
    else
        GRUB_PARAMS_TO_ADD+=('splash')
    fi
else
    echo "NOTE: GRUB not detected (no grub-mkconfig / /etc/default/grub) --"
    echo "Plymouth is installed but nothing added 'splash' to the kernel"
    echo "command line. If you're on a different bootloader (systemd-boot,"
    echo "rEFInd, etc.), add 'splash' (and optionally 'quiet') to its kernel"
    echo "parameters yourself -- see the Arch Wiki's Plymouth page."
fi

# ------------------------------------------------------------------------
# Nvidia kernel parameter -- only if stage 1's GPU prompt actually
# installed the Nvidia driver (checked here, rather than passed in from
# stage 1, since each numbered stage runs as its own process).
echo
echo "Checking for an installed Nvidia driver"
if pacman -Qq nvidia-open &>/dev/null || pacman -Qq nvidia &>/dev/null; then
    echo "Nvidia driver detected"
    if command -v grub-mkconfig >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
        if grep -q 'nvidia_drm.modeset=1' /etc/default/grub; then
            echo "GRUB already has 'nvidia_drm.modeset=1', skipping"
        else
            GRUB_PARAMS_TO_ADD+=('nvidia_drm.modeset=1')
        fi
    else
        echo "NOTE: GRUB not detected -- add 'nvidia_drm.modeset=1' to your"
        echo "bootloader's kernel parameters yourself."
    fi
else
    echo "No Nvidia driver installed, nothing to do"
fi

if [[ ${#GRUB_PARAMS_TO_ADD[@]} -gt 0 ]]; then
    "${SUDO[@]}" sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 ${GRUB_PARAMS_TO_ADD[*]}\"/" /etc/default/grub
    "${SUDO[@]}" grub-mkconfig -o /boot/grub/grub.cfg
fi

# ------------------------------------------------------------------------
echo "
###############################################################################
# Done
###############################################################################
"
