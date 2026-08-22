# Keybindings

Every `bind`/`bindm`/`bindel` line from `dotfiles/hypr/hyprland.conf`,
grouped the same way the file itself groups them, with the exact syntax
so you can copy-paste straight into a live `~/.config/hypr/hyprland.conf`.
`$mod` = `SUPER`.

Keyed to match [HyDE-Project/HyDE's own KEYBINDINGS.md](https://github.com/HyDE-Project/HyDE/blob/master/KEYBINDINGS.md)
wherever this repo has an equivalent app/dispatcher. Not ported: HyDE
binds that call into its own `~/.local/lib/hyde/` helper script library
this repo doesn't install -- wallbash mode selector, waybar layout
cycling, animations/hyprlock layout pickers, game mode/launcher, the
generated keybind-hint menu, GPU/CPU/sensor widgets, an updates checker,
OCR "scan text", true freeze-frame screenshot, and per-window audio mute.

To update a live install: copy the block(s) you need into your live
`hyprland.conf`, then `hyprctl reload` (no need to touch anything else --
these are self-contained `bind` lines).

## Window management

```
bind = $mod, Q, killactive,
bind = ALT, F4, killactive,
bind = $mod ALT, F4, forcekillactive,
bind = $mod, Delete, exit,
bind = $mod, T, togglefloating,
bind = $mod, G, togglegroup,
bind = ALT, P, pseudo,
bind = SHIFT, F11, fullscreen, 0
bind = $mod, L, exec, hyprlock
bind = $mod SHIFT, F, pin,
bind = ALT CTRL, Delete, exec, wlogout
bind = $mod, ESCAPE, exec, wlogout
bind = $mod CTRL, B, exec, pkill -x waybar || waybar
bind = $mod, J, layoutmsg, togglesplit
```

## Group navigation

```
bind = $mod CTRL, H, changegroupactive, b
bind = $mod CTRL, L, changegroupactive, f
```

## Change focus

```
bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up, movefocus, u
bind = $mod, down, movefocus, d
```

## Alt-Tab style window cycling

```
bind = ALT, Tab, cyclenext,
bind = ALT, Tab, bringactivetotop,
bind = ALT SHIFT, Tab, cyclenext, prev
bind = ALT SHIFT, Tab, bringactivetotop,
```

## Resize active window

```
bind = $mod SHIFT, right, resizeactive, 20 0
bind = $mod SHIFT, left, resizeactive, -20 0
bind = $mod SHIFT, up, resizeactive, 0 -20
bind = $mod SHIFT, down, resizeactive, 0 20
```

## Move/resize with mouse (or Z/X held like a mouse button)

```
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow
bindm = $mod, Z, movewindow
bindm = $mod, X, resizewindow
```

## Misc: move the active window between tiles

```
bind = $mod CTRL SHIFT, left, movewindow, l
bind = $mod CTRL SHIFT, right, movewindow, r
bind = $mod CTRL SHIFT, up, movewindow, u
bind = $mod CTRL SHIFT, down, movewindow, d
```

## Launcher: apps

```
bind = $mod, Return, exec, alacritty
bind = $mod ALT, T, exec, hyprctl clients -j | jq -e '.[] | select(.class=="dropterm")' >/dev/null && hyprctl dispatch togglespecialworkspace dropterm || alacritty --class dropterm
bind = $mod, E, exec, thunar
bind = $mod, C, exec, code
bind = $mod, B, exec, brave
bind = CTRL SHIFT, Escape, exec, alacritty -e top
```

`Super+Alt+T` needs this window rule alongside it (already in
`hyprland.conf`'s window-rules section, not the binds section):

```
windowrule = match:class ^(dropterm)$, float on, size 60% 60%, center on, workspace special:dropterm silent
```

## Launcher: Rofi menus

```
bind = $mod, TAB, exec, rofi -show drun -modi drun,filebrowser,window,run
bind = $mod SHIFT, E, exec, rofi -show filebrowser
bind = $mod SHIFT, V, exec, sh -c 'cliphist list | rofi -dmenu -theme ~/.config/rofi/clipboard.rasi | cliphist decode | wl-copy'
bind = $mod SHIFT, slash, exec, sh -c 'q="$(rofi -dmenu -p Search)"; [ -n "$q" ] && xdg-open "https://www.google.com/search?q=$q"'
```

## Launcher: alternate Rofi styles

Each just `drun` restyled with a different `-theme` -- see `dotfiles/rofi/`
(ported from HyDE-Project/HyDE's `Configs/.local/share/hyde/rofi/themes/`).

```
bind = $mod, A, exec, rofi -show drun -theme ~/.config/rofi/launchpad.rasi
bind = $mod SHIFT, G, exec, rofi -show drun -theme ~/.config/rofi/gamelauncher_2.rasi
bind = $mod SHIFT, Q, exec, rofi -show drun -theme ~/.config/rofi/quickapps.rasi
```

## Quickshell workspace overview

Needs `quickshell` + `quickshell-overview-git` (stage 3, AUR) -- see
`dotfiles/quickshell-overview/`. Auto-started (`exec-once = qs -c overview`
in `hyprland.conf`'s Autostart section), toggled via IPC rather than
launched fresh per invocation:

```
bind = $mod, O, exec, qs ipc -c overview call overview toggle
```

## Hardware controls: audio

Routed through `swayosd-client` (needs the `swayosd-git` AUR package and
its `swayosd-server` daemon, autostarted in `hyprland.conf`) instead of
`pamixer` directly, so raising/lowering/muting shows an on-screen popup:

```
bindel = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
bindel = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
bindel = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
bind = , F10, exec, swayosd-client --output-volume mute-toggle
bind = , F11, exec, swayosd-client --output-volume lower
bind = , F12, exec, swayosd-client --output-volume raise
bind = , XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle
```

## Hardware controls: media

Needs `playerctl` (`sudo pacman -S --needed playerctl`):

```
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioPause, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous
```

## Hardware controls: brightness

Also routed through `swayosd-client`, same reasoning as audio above:

```
bindel = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise
bindel = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower
```

## Blue light filter

Needs `hyprsunset`. Off by default -- toggles on/off (no running process
= no filter):

```
bind = $mod SHIFT, N, exec, pkill hyprsunset || hyprsunset -t 4000
```

## Utilities: screen capture

Needs `jq` for the focused-monitor one:

```
bind = , Print, exec, grim - | wl-copy
bind = $mod, P, exec, grim -g "$(slurp)" - | wl-copy
bind = $mod ALT, P, exec, grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" - | wl-copy
```

## Theming and wallpaper

```
bind = $mod SHIFT, W, exec, waypaper
bind = $mod SHIFT, T, exec, ~/.config/hyde-themes/theme.sh menu
```

## Workspaces: navigation

```
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod, 0, workspace, 10
bind = $mod CTRL, down, workspace, empty
bind = $mod, mouse_down, workspace, e+1
bind = $mod, mouse_up, workspace, e-1
```

## Workspaces: relative

```
bind = $mod CTRL, right, workspace, e+1
bind = $mod CTRL, left, workspace, e-1
```

## Workspaces: move window silently

```
bind = $mod ALT, 1, movetoworkspacesilent, 1
bind = $mod ALT, 2, movetoworkspacesilent, 2
bind = $mod ALT, 3, movetoworkspacesilent, 3
bind = $mod ALT, 4, movetoworkspacesilent, 4
bind = $mod ALT, 5, movetoworkspacesilent, 5
bind = $mod ALT, 6, movetoworkspacesilent, 6
bind = $mod ALT, 7, movetoworkspacesilent, 7
bind = $mod ALT, 8, movetoworkspacesilent, 8
bind = $mod ALT, 9, movetoworkspacesilent, 9
bind = $mod ALT, 0, movetoworkspacesilent, 10
```

## Workspaces: move window to workspace

```
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9
bind = $mod SHIFT, 0, movetoworkspace, 10
bind = $mod ALT CTRL, right, movetoworkspace, e+1
bind = $mod ALT CTRL, left, movetoworkspace, e-1
```

## Repo-specific extras (not part of HyDE's list)

```
bind = $mod, N, exec, swaync-client -t -sw
bind = $mod, M, exec, eww open widget-panel || eww close widget-panel
```
