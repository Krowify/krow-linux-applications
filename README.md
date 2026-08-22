# Arch Installer

This repo installs and configures a fully-functional Arch Linux setup:
a Hyprland (Wayland) desktop, support packages (network, bluetooth,
audio, etc.), a firewall/hardening pass, and a set of preferred
applications.

| Category | Component |
|----------|-----------|
| Bootloader / splash | GRUB + Plymouth |
| Display Manager | SDDM (Plasma Login Manager) |
| Compositor | Hyprland |
| Status bar | Waybar |
| Music | Spotify (via spotify-launcher) |
| App launcher | Rofi |
| Terminal | Alacritty + ZSH + Starship (prompt) + fzf/zoxide (fuzzy search/smarter cd) |
| System info banner | fastfetch |
| Logout menu | Wlogout |
| Widgets | Eww |
| Dock | Quickshell (ported from mylinuxforwork/dotfiles) |
| Workspace overview | Quickshell (Shanu-Kumawat/quickshell-overview, `Super+O`) |
| Qt app theming | qt6ct + xsettingsd |
| Settings GUI | hyprmod |
| Theme | Tokyo Night (default), Decay Green, or Graphite Mono, switchable with `theme.sh` (`Super+Shift+T`) -- see [Theme switching](#theme-switching) and [Credits](CREDITS.txt) |
| Icon theme | Tela-circle-purple (Tokyo Night) / Tela-circle-green (Decay Green) / Tela-circle-grey (Graphite Mono) |
| Fonts | Noto Fonts + Nerd Fonts |
| Wallpaper | Waypaper (GUI picker) + awww (renderer, renamed from swww) |
| Cursor theme | Bibata |
| File manager | Thunar |
| Clipboard | wl-clipboard + cliphist (history), Rofi (picker UI) |
| Notifications | SwayNC |
| Network | NetworkManager + nm-applet |
| Audio | PipeWire + WirePlumber + pamixer |
| Power | Brightnessctl |
| On-screen display | SwayOSD (volume/mic/brightness/caps-lock) |
| Blue light filter | hyprsunset (`Super+Shift+N` to toggle) |
| GPU driver | mesa (AMD/Intel) or Nvidia proprietary -- picked interactively in stage 1 |
| Package manager | pacman + yay + paru |
| VPN | ProtonVPN |
| Privacy browser | Tor Browser |

## Arch Linux First Boot

Run as **root**, right after a base Arch install:

```sh
pacman -S --noconfirm pacman-contrib curl git
git clone https://github.com/Krowify/arch-install
cd linux-installation
bash install.sh
```

`install.sh` (repo root) runs all six stages, in `scripts/`, with a
single command. AUR builds
(stage 3) can't run as root -- `makepkg` refuses -- and dotfiles (stage
5) need to land in a real user's `$HOME`, not root's, so the script
handles both switches for you:

- If you're running it as **root**, it asks for a username to use for
  stages 3 and 5, offers to create the account if it doesn't exist yet,
  then automatically drops into that user (`su -`) for each of those
  stages and switches back to root in between (for stages 4 and 6).
- If you're already running it as a **regular user with sudo**, it
  just uses your current account for stages 3 and 5 and calls `sudo`
  where needed for the rest.

Expect a few interactive prompts along the way (root/sudo password,
account creation if applicable, `makepkg` confirmations, whether to
enable the SSH server in stage 4) -- that's intentional so nothing
installs, creates accounts, or opens a network port silently.

| Stage | Script                          | Runs as                     | Purpose                                                |
|-------|----------------------------------|------------------------------|----------------------------------------------------------|
| 0     | `install.sh` (repo root)         | root or sudo user           | Master runner -- executes all stages below in order       |
| 1     | `scripts/1-base.sh`              | root                         | Wayland, Hyprland compositor, networking, audio, bluetooth, GPU driver (asks Intel/Nvidia/AMD) |
| 2     | `scripts/2-system-software.sh`   | root                         | Everyday software + Hyprland desktop utilities (bar, launcher, etc.) from the official repos |
| 3     | `scripts/3-user-software.sh`     | non-root (handled by install.sh) | AUR packages via `yay` (VS Code, Discord, themes, etc.)|
| 4     | `scripts/4-firewall.sh`          | root                         | Firewall, sysctl hardening, fail2ban                       |
| 5     | `scripts/5-dotfiles.sh`          | non-root (handled by install.sh) | Deploys Hyprland/waybar/etc. config, applies the default theme via `theme.sh` |
| 6     | `scripts/6-post-setup.sh`        | root                         | File watcher limit, display manager, bluetooth autostart, Plymouth/GRUB wiring, Nvidia kernel parameter (if applicable) |

All scripts use `set -euo pipefail`, so they stop on the first error
instead of silently continuing with a partially-configured system.

## Running stages manually (optional)

If you'd rather step through each stage yourself instead of using
`install.sh`, you can still run them individually (from the repo root):

```sh
sh scripts/1-base.sh
sh scripts/2-system-software.sh

su <your-username>
sh scripts/3-user-software.sh

su
sh scripts/4-firewall.sh

su <your-username>
sh scripts/5-dotfiles.sh

su
sh scripts/6-post-setup.sh
```

## System Description

This runs Hyprland, a tiling Wayland compositor, and installs known
drivers and applications for a quick, consistent Linux setup. It also
configures the firewall and other services expected to be running at
startup.

SDDM is used as the login manager. Once stage 1 finishes, the
`hyprland` package's own `.desktop` entries make Hyprland selectable
from SDDM's session dropdown with nothing further to configure -- pick
"Hyprland uwsm" if it's offered, otherwise plain "Hyprland". (Stage 6
renames it from the package's default "Hyprland (uwsm-managed)" --
some SDDM themes clip/overlap the longer name.)

## Dotfiles (stage 5)

Package installed alone don't produce a working desktop -- Hyprland,
waybar, swaync, etc. all need a config to autostart and behave. Stage 5
deploys `dotfiles/` (source templates in this repo) into `~/.config`,
then runs `theme.sh set tokyo-night` to apply the default theme
(see [Theme switching](#theme-switching) below for what that actually
does):

- Any existing file/directory it would overwrite gets moved to
  `<name>.bak` first instead of silently clobbered.
- Appends zsh plugin sourcing (`zsh-autosuggestions`,
  `zsh-syntax-highlighting`, `autojump`) to `~/.zshrc`, guarded by a
  marker comment so re-running the stage doesn't duplicate it.

Default keybinds (`$mod` = Super) -- see [`KEYBINDINGS.md`](KEYBINDINGS.md)
for the exact copy-pasteable `bind` lines. Keyed to match
[HyDE-Project/HyDE's own KEYBINDINGS.md](https://github.com/HyDE-Project/HyDE/blob/master/KEYBINDINGS.md)
wherever this repo has an equivalent app or Hyprland dispatcher for it --
see the comment above the keybinds section in `dotfiles/hypr/hyprland.conf`
for what wasn't ported (HyDE features that call into its own
`~/.local/lib/hyde/` helper scripts, which this repo doesn't install) and
why. Where this repo's own pre-existing key and HyDE's key both did the
same thing (`Super+Return`/`Super+T` for terminal, `Super+A`/`Super+Tab`
for the launcher, `Super+W`/`Super+F` for toggle-floating), the duplicate
was dropped rather than kept as an alias -- one bind per action.

Grouped into Super binds, Alt binds, window-movement binds (focus/resize/
move/group-cycle -- these all happen to use Super too, but get their own
table since they're a distinct category), and everything else (hardware,
media, and the handful of binds with neither modifier).

### Super

Grouped by what each bind actually does, terminal first.

**Terminal**

| Keybind | Action |
|---------|--------|
| `Super+Return` | Terminal (Alacritty) |
| `Super+Alt+T` | Dropdown terminal (own special workspace) |

**Close, force-kill, exit**

| Keybind | Action |
|---------|--------|
| `Super+Q` | Close focused window |
| `Super+Alt+F4` | Force-kill focused window |
| `Super+Delete` | Exit Hyprland session |
| `Super+Escape` | Logout menu (Wlogout) |
| `Super+L` | Lock screen (Hyprlock) |

**Toggle**

| Keybind | Action |
|---------|--------|
| `Super+T` | Toggle floating |
| `Super+G` | Toggle group |
| `Super+Shift+F` | Toggle pin on focused window |
| `Super+J` | Toggle split |
| `Super+M` | Toggle Eww widget panel |
| `Super+O` | Toggle workspace overview (Quickshell) |
| `Super+Ctrl+B` | Toggle waybar |
| `Super+N` | Toggle notification center (SwayNC) |
| `Super+Shift+N` | Toggle blue light filter (hyprsunset) |

**Launchers and apps**

| Keybind | Action |
|---------|--------|
| `Super+Tab` | App launcher (Rofi) |
| `Super+A` | Fullscreen app grid (Rofi, "launchpad" style) |
| `Super+Shift+G` | Game-tile app grid (Rofi) |
| `Super+Shift+Q` | Quick-launch icon strip (Rofi) |
| `Super+Shift+E` | File finder (Rofi) |
| `Super+Shift+V` | Clipboard history (cliphist + Rofi) |
| `Super+Shift+/` | Web search (Rofi prompt) |
| `Super+E` | File manager (Thunar) |
| `Super+C` | Text editor (VS Code) |
| `Super+B` | Web browser (Brave) |

**Workspace and theming**

| Keybind | Action |
|---------|--------|
| `Super+Ctrl+Right/Left` | Next/previous workspace (relative) |
| `Super+Ctrl+Down` | Go to nearest empty workspace |
| `Super+Shift+W` | Open wallpaper picker (waypaper) |
| `Super+Shift+T` | Open theme picker (`theme.sh menu`) |

### Alt

| Keybind | Action |
|---------|--------|
| `Alt+F4` | Close focused window |
| `Alt+P` | Toggle pseudotile |
| `Alt+Ctrl+Delete` | Logout menu (Wlogout) |
| `Alt+Tab` / `Alt+Shift+Tab` | Cycle windows forward/backward |

### Window movement

| Keybind | Action |
|---------|--------|
| `Super+Ctrl+H` / `Super+Ctrl+L` | Cycle window group backward/forward |
| `Super+Left/Right/Up/Down` | Focus window in direction |
| `Super+Shift+Left/Right/Up/Down` | Resize active window |
| `Super+Ctrl+Shift+Left/Right/Up/Down` | Move active window between tiles |
| `Super+Z` / `Super+X` | Hold to move / resize window (no mouse) |
| `Super+1` .. `Super+0` | Switch to workspace 1-10 |
| `Super+Shift+1` .. `Super+Shift+0` | Move window to workspace 1-10 |
| `Super+Alt+1` .. `Super+Alt+0` | Move window to workspace 1-10 (silent) |

### Screenshot

| Keybind | Action |
|---------|--------|
| `Print` | Screenshot all monitors to clipboard |
| `Super+P` | Screenshot region to clipboard |
| `Super+Alt+P` | Screenshot focused monitor to clipboard |

### Other (hardware, media, no modifier)

| Keybind | Action |
|---------|--------|
| `Ctrl+Shift+Escape` | System monitor (`top` in Alacritty) |
| `Shift+F11` | Toggle fullscreen |
| `F10` / `F11` / `F12` | Mute / lower / raise volume |
| `XF86Audio*`, `XF86MonBrightness*` | Media, mic mute, and brightness keys |

No wallpaper image ships with the default theme -- pick one with `waypaper`
(`Super+Shift+W`), which sets it via `awww` and re-themes the desktop via
Matugen. See [Color theming](#color-theming-matugen) below. Until you pick
one, Hyprland/Waybar/SwayNC/Alacritty stay on the static fallback palette
baked into the active theme's dotfiles. (Tokyo Night is the exception --
it ships its own wallpaper, set automatically when you switch to it; see
[Theme switching](#theme-switching).)

waypaper's `folder` setting points at `~/Pictures/wallpapers` (created by
stage 5), and `use_xdg_state = true` moves your actual wallpaper/folder/
monitor picks out of `~/.config/waypaper/config.ini` and into
`~/.local/state/waypaper/state.ini`. That split matters because stage 5
redeploys `~/.config/waypaper/config.ini` from this repo's template on
every run (like most of this repo's dotfiles) -- with state kept
separately, re-running `scripts/5-dotfiles.sh` (e.g. after pulling a repo update)
can never wipe out your current wallpaper.

## Multi-monitor layout (optional)

`dotfiles/hypr/hyprland.conf` ships a single default `monitor =
,preferred,auto,auto` line (auto-detect, preferred mode, for every
monitor). For anything beyond that -- e.g. a portrait monitor beside a
normal one, or one mounted upside down -- use hyprmod's GUI (in your app
launcher) instead of hand-editing `hyprland.conf`: it live-previews monitor
position/rotation/mode changes via `hyprctl` and persists them to its own
config, independently of this repo's dotfiles, so a future re-run of
`scripts/5-dotfiles.sh` never reverts your layout.

## Theme switching

This repo ships three themes -- Tokyo Night (the default), Decay Green,
and Graphite Mono -- and a small switcher, `theme.sh`, deployed by stage 5
to `~/.config/hyde-themes/`. Run it directly, or press `Super+Shift+T` for
a Rofi picker:

```sh
~/.config/hyde-themes/theme.sh set tokyo-night   # apply a theme
~/.config/hyde-themes/theme.sh menu              # Rofi picker
~/.config/hyde-themes/theme.sh list              # list available themes
~/.config/hyde-themes/theme.sh current           # show the active theme
```

Each theme lives in its own directory under `~/.config/hyde-themes/`
(sourced from `dotfiles/hyde-themes/<name>/` in this repo) and holds:

- One color file per themed app (`hypr-colors.conf`, `waybar-colors.css`,
  `swaync-variables.css`, `wlogout-colors.css`, `alacritty-colors.toml`,
  `rofi-colors.rasi`, `eww-colors.scss`) -- every app's own config now just `@import`s (or,
  for Hyprland/Alacritty/Wlogout, `source`s) a stable filename in its
  `~/.config/<app>/` directory, and `theme.sh set` is what copies the
  chosen theme's version of each file into place and reloads that app
  (`hyprctl reload`, `killall -SIGUSR2 waybar`, `swaync-client -rs`,
  `eww reload` -- Alacritty/Wlogout need no reload, see
  [Color theming](#color-theming-matugen) below).
- `theme.conf`, naming the GTK theme + icon theme this desktop theme
  needs (as case-insensitive glob patterns, same idea as stage 5's old
  folder detection) and, optionally, a URL to fetch them from if they
  aren't installed anywhere `theme.sh` looks (`/usr/share/{themes,icons}`,
  then `~/.local/share/{themes,icons}`). None of the three themes here
  have official-repo or known-good AUR packages for their GTK/icon
  themes, so `theme.sh` downloads all of them straight from
  [HyDE-Project/hyde-themes](https://github.com/HyDE-Project/hyde-themes)
  (the same assets HyDE itself ships) the first time you switch to each
  one, and extracts them into `~/.local/share/{themes,icons}` -- no
  `sudo`, no AUR package name to guess. **This means switching to a theme
  for the first time needs a network connection.**
- Optionally a bundled wallpaper, set directly via `awww img` when you
  switch to that theme. All three now have one: Tokyo Night's lives in
  its own directory (`tokyo-night/wallpaper.png`, from HyDE's repo); Decay
  Green's and Graphite Mono's are `DecayGreen.png`/`monochrome.jpg` in the
  shared `dotfiles/hyde-themes/wallpapers/` pool (referenced via
  `WALLPAPER=` in each theme's `theme.conf`) rather than HyDE ports, since
  neither has a verified wallpaper asset upstream for this repo to pull
  from.

`~/.config/hyde-themes/global.conf` (not per-theme) covers the two bits
of chrome that stay the same across every theme: the cursor theme and the
SDDM login theme. Writing the SDDM theme config needs `sudo`, but stage 6
(`scripts/6-post-setup.sh`) grants a permanent, narrowly-scoped NOPASSWD rule for
exactly that command -- so switching themes (`theme.sh set`/`menu`) never
prompts for your password, on the first switch or any after it.

**Palette fidelity:** all three themes' color files (Hyprland border
colors, Waybar/Rofi accents, Alacritty background/foreground/cursor) are
now ported from HyDE's actual published `hypr.theme`/`waybar.theme`/
`rofi.theme`/`kitty.theme` source for each one (see [Credits](CREDITS.txt))
-- an earlier revision of Decay Green and Graphite Mono looked for that
source in the wrong place and fell back to a same-shape approximation
instead; that's fixed now. What's still this repo's own construction for
all three themes: the *extended* Material-You-shaped role sets (Waybar's
and Wlogout's full token lists go well beyond the handful of colors HyDE's
theme files actually define) and SwayNC's/Eww's colors, since neither has
a HyDE source to port from at all -- both are derived from each theme's
real anchor colors, not independently pixel-matched.

**No file manager swap needed.** Thunar is a GTK app and already reads
its icons/colors from the GTK theme `theme.sh` sets in
`~/.config/gtk-3.0/gtk-4.0/settings.ini` (plus `gsettings`, for anything
that reads theme names that way instead) -- switching themes re-themes
Thunar for free, the same way it re-themes every other GTK app.

**How this interacts with Matugen:** all three themes here are *curated*
palettes, not ones derived from a wallpaper -- `theme.sh` sets each
one's colors directly and sets its wallpaper via `awww` directly too (if
it has one bundled), bypassing `waypaper`'s Matugen hook on purpose. If
you then open `waypaper` and pick a wallpaper yourself, that **will**
re-run Matugen and overwrite the active theme's curated colors with a
wallpaper-derived palette -- that's expected, not a bug: picking a
wallpaper through `waypaper` is itself an opt-in "go dynamic" action,
orthogonal to which theme you last switched to. Re-run
`theme.sh set <name>` to restore the curated palette.

**Adding another theme:** copy `dotfiles/hyde-themes/tokyo-night/` (drop
`wallpaper.png` and its `WALLPAPER=` line in `theme.conf` if you don't
have one to bundle -- see `decay-green/`/`graphite-mono/` for that
pattern) to a new `dotfiles/hyde-themes/<name>/`, edit its color files
and `theme.conf`, re-run stage 5 (or just `cp -r` it into
`~/.config/hyde-themes/<name>/` directly) -- it'll show up in
`theme.sh list`/`menu` immediately, no other wiring needed.

Not covered by any of this: Qt/Kvantum theming for `kate`/`pavucontrol`
(no theme configures Kvantum, so Qt apps keep using your system Qt
style regardless of which theme is active), and the SDDM login theme
(shared across every theme on purpose -- see `global.conf` above).

## Color theming (Matugen)

Picking a wallpaper through `waypaper` doesn't just set the background --
`waypaper`'s `post_command` (`dotfiles/waypaper/config.ini`) runs
`matugen image "$wallpaper"`, which generates a Material You color scheme
from that image and rewrites the color files for Hyprland, Waybar, SwayNC,
Alacritty's background/foreground/cursor, Wlogout, Eww, and Rofi from it:

| App | Generated file | Picked up via |
|-----|-----------------|----------------|
| Hyprland | `~/.config/hypr/colors.conf` | `hyprctl reload` (Matugen's post_hook) |
| Waybar | `~/.config/waybar/tokens/colors.css` | `killall -SIGUSR2 waybar` (Matugen's post_hook) |
| SwayNC | `~/.config/swaync/tokens/variables.css` | `swaync-client -rs` (Matugen's post_hook) |
| Alacritty | `~/.config/alacritty/colors.toml` | live-reloads on file change by itself |
| Wlogout | `~/.config/wlogout/colors.css` | none needed -- launched fresh each time (Super+Escape), not a running daemon |
| Eww | `~/.config/eww/colors.scss` | `eww reload` (Matugen's post_hook) |
| Rofi | `~/.config/rofi/colors.rasi` | none needed -- launched fresh each time, not a running daemon |

Eww and Rofi were added later than the rest -- earlier revisions of this
repo left them out of Matugen's coverage entirely, so picking a new
wallpaper would re-theme everything except those two, leaving them stuck
on whatever `theme.sh` last set. Fixed now; role names match `theme.sh`'s
curated `eww-colors.scss`/`rofi-colors.rasi` files exactly, so both
resolve unchanged either way.

Two files that used to exist here, `~/.config/waybar/colors.css` and
`~/.config/swaync/colors.css` (an "accent" layer separate from the
`tokens/` one above), were removed along with this change -- neither
`style.css` ever actually imported them, in Waybar or SwayNC, so they
were pure dead weight that both Matugen and `theme.sh` wrote to for no
reason.

Each of those files ships with a static fallback matching the default
theme (Tokyo Night -- see [Credits](CREDITS.txt)) so things look right
before you've ever picked a wallpaper. Matugen overwrites them in place
once you do, for whichever theme happens to be active -- see [How this
interacts with Matugen](#theme-switching) above; `theme.sh set <name>`
restores the curated palette afterward.

Alacritty's ANSI 16-color palette (`[colors.normal]`/`[colors.bright]` in
`alacritty.toml` itself) is deliberately **not** Matugen-templated --
Material You doesn't define semantic roles for "ANSI green"/"ANSI cyan"
etc., and remapping them per-wallpaper would make `ls`/`diff`/etc. output
unpredictable. Only background/foreground/cursor (`colors.toml`) move with
the wallpaper.

The template sources live in `dotfiles/matugen/templates/`, wired up in
`dotfiles/matugen/config.toml`. To theme another app, add a
`[templates.name]` block there and a matching template file -- see the
[Matugen wiki](https://github.com/InioX/matugen/wiki) for the full list of
generated color roles.

Note: none of this Matugen wiring has been verified against a live
install (unlike most of the rest of this repo, which has been fixed up
against real error messages over time) -- if a template fails or a color
role name doesn't exist, run `matugen image <path> --dry-run` to see what
it actually generates and adjust the role names in
`dotfiles/matugen/templates/*` and `dotfiles/matugen/config.toml`
accordingly.

## More

- [Troubleshooting](TROUBLESHOOTING.txt)
- [Credits](CREDITS.txt)
