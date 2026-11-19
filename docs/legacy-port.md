# Legacy port (pre-Omarchy-4)

This branch (`legacy-omarchy3`) is a fork of the upstream repo, adapted to run on Omarchy
installs that still use **waybar + walker** and plain `.conf` Hyprland config, instead of
Omarchy 4's Quickshell-based `omarchy-shell` and Lua Hyprland config.

Run `omarchy commands --all` / `command -v omarchy-shell` to tell which one you're on. If
`omarchy-shell` exists, use the **main branch** and its `install.sh` instead -- it has the real
visual picker and full bar matching (popups, menu, launcher highlight), which this port can't do.

## What's different here

| | Main branch (Omarchy 4) | This branch |
|---|---|---|
| Picker | QML carousel overlay, live video previews | text list via `walker --dmenu` (`live-wallpaper pick`) |
| Menu entry | `omarchy-menu.jsonc`, own icons | appended to `~/.config/omarchy/extensions/menu.sh`, overrides `show_style_menu` |
| Bar matching | `~/.config/omarchy/shell.toml` -- bar, popups, tooltip, menu and launcher highlight all recolour | `~/.config/waybar/style.css` `@import` -- bar background/foreground only; no popup/menu/launcher hook exists in this shell |
| Autostart | `~/.config/hypr/autostart.lua` | `~/.config/hypr/autostart.conf` (`exec-once`) |
| Window glow | `hyprctl eval` (Lua config) | same code, falls back to `hyprctl keyword` automatically -- unchanged |
| Scheduling, packs, mpvpaper, daemon | same Python tool, same pack format | unchanged |

Everything in `bin/live-wallpaper` that isn't about the shell -- packs, prayer-time/time-of-day
scheduling, mpvpaper control, the daemon loop -- is plain Python with no Omarchy-version
dependency, so it's shared as-is.

## A note on `omarchy-prayer-wallpaper-swap`

This machine already runs a hand-rolled version of the same idea: `~/.local/bin/omarchy-prayer-wallpaper-swap`,
driven by a systemd timer (`omarchy-prayer-wallpaper-swap.timer`), playing videos from
`~/omarchyPC/MacBookPro/wallpapers/prayer-videos/` and writing `~/.config/hypr/wallpaper-glow.conf`.

**Installing this port and leaving that script's timer enabled will fight over mpvpaper and the
window glow.** Before running `./install.sh` here, disable the old one:

```bash
systemctl --user disable --now omarchy-prayer-wallpaper-swap.timer
```

Its five prayer scenes plus six scenery scenes aren't ported over automatically -- the included
`sacred-places` pack only has three. To keep using the fuller set, copy the old videos into a
pack (see `docs/creating-a-pack.md`) under `~/.config/omarchy-live-wallpaper/packs/`, pointing
`pack.json`'s `schedule.map` at `~/omarchyPC/MacBookPro/wallpapers/prayer-videos/*.mp4`, before
switching over -- or just keep the old script and skip installing this one.

## Upgrading to Omarchy 4

When this machine moves to Omarchy 4 (`omarchy-shell` becomes available):

1. `~/.local/share/omarchy-live-wallpaper-legacy/uninstall.sh` (or wherever this was installed from)
2. Switch to the sibling `omarchy-live-wallpaper` clone (main branch, upstream `origin/main`)
3. Run its `install.sh` instead

Your `~/.config/omarchy-live-wallpaper/config.json` and any packs you added under
`~/.config/omarchy-live-wallpaper/packs/` are shell-agnostic and carry over untouched.
