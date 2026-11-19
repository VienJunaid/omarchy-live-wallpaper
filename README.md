# omarchy-live-wallpaper (legacy-omarchy3 branch)

> **This branch is a port for pre-Omarchy-4 (waybar + walker) setups.** No visual picker, and
> bar matching only covers the bar itself. See [docs/legacy-port.md](docs/legacy-port.md) for
> what differs from the main branch, and for the upgrade path once you're on Omarchy 4.

Animated video wallpapers for [Omarchy](https://omarchy.org), with a text picker and a bar that
matches the scene.

- **Picker.** SUPER+SPACE → Style → Live wallpaper opens a `walker` list of every scene plus
  Auto; pick one and it plays immediately (no preview, no Save step -- see
  [docs/legacy-port.md](docs/legacy-port.md)).
- **Follows a schedule.** The included pack changes scene with the five daily prayer times. Packs can
  also follow the time of day, or you can pin one scene.
- **Bar matches the wallpaper.** The waybar background/foreground take their colours from the
  scene that's playing. Turn it off any time; your theme's colours come back.
- **Packs.** Wallpapers come in packs: a folder of videos plus a small `pack.json`. Drop a video in
  and it appears in the picker. See [docs/creating-a-pack.md](docs/creating-a-pack.md).

## Install

Needs Hyprland + waybar + walker (pre-Omarchy-4; see [docs/legacy-port.md](docs/legacy-port.md)).
`omarchy-prayer-wallpaper-swap.timer`, if you have one, should be disabled first -- it fights
over the same mpvpaper/glow.

```bash
git clone -b legacy-omarchy3 https://github.com/VienJunaid/omarchy-live-wallpaper.git
cd omarchy-live-wallpaper
./install.sh
```

The installer:

1. installs `mpvpaper` (from the AUR) plus `python` and `ffmpeg` if they're missing,
2. puts the `live-wallpaper` command in `~/.local/bin`,
3. hooks bar matching into `~/.config/waybar/style.css` and adds **Style → Live wallpaper** and
   **Style → Match bar** to the menu (`~/.config/omarchy/extensions/menu.sh`),
4. starts a small background loop at login (`~/.config/hypr/autostart.conf`) and starts it now.

It asks for your city (for prayer times) unless `omarchy-prayer` is installed. Every file it edits
is backed up first (`*.bak.<timestamp>`), and its changes are marked so they can be removed cleanly.
Re-running it updates the install.

## Use

| | |
|---|---|
| `live-wallpaper` | open the picker (←/→ or click to browse, **Enter** or **Save** to apply, **Esc** to cancel, **A** to follow the schedule) |
| `live-wallpaper set madinah` | play a scene and keep it |
| `live-wallpaper auto` | follow the schedule again |
| `live-wallpaper next` / `prev` | step through scenes (handy on a keybinding) |
| `live-wallpaper status` | what's playing and why, plus today's schedule |
| `live-wallpaper bar match` / `off` | bar colours follow the wallpaper, or not |
| `live-wallpaper list` / `packs` | scenes and packs |
| `live-wallpaper doctor` | check the setup |

Want a key for "next scene"? Add to `~/.config/hypr/bindings.conf`:

```
bind = SUPER, U, exec, live-wallpaper next
```

## Included pack: Sacred Places

Pixel-art scenes, following the prayer times:

| Scene | Plays at |
|---|---|
| **Madinah**: Masjid an-Nabawi by day | Fajr, Dhuhr, Asr |
| **Kaaba Aerial**: Masjid al-Haram from above | Maghrib |
| **Night Mosque**: crescent moon and lanterns | Isha |

## Settings

`~/.config/omarchy-live-wallpaper/config.json`:

```jsonc
{
  "follow": "sacred-places",       // the pack whose schedule "auto" follows
  "prayer_source": "auto",         // auto | omarchy-prayer | aladhan | fixed
  "location": { "city": "Atlanta", "country": "US", "method": 2 },  // for aladhan.com (method 2 = ISNA)
  "bar": "match",                  // match | off
  "glow": true,                    // tint the window shadow per scene, if the scene sets a colour
  "restart_on_workspace_switch": false,  // restart the video on every workspace switch
  "tick_seconds": 30               // how often the background loop checks the schedule
}
```

Prayer times come from [`omarchy-prayer`](https://github.com/mrCode/omarchy-prayer) if it's
installed, otherwise from [aladhan.com](https://aladhan.com) for your city (cached for the day),
otherwise from fixed approximate times.

## How it works

```
bin/live-wallpaper      the whole tool: packs, schedule, mpvpaper control, bar colours (Python, stdlib only)
plugin/                 unused on this branch (it's the Omarchy-4 QML overlay; see docs/legacy-port.md)
packs/<id>/             pack.json + videos/*.mp4
install.sh              one-command install; uninstall.sh reverses it
```

- `mpvpaper` plays the video on the background layer. Scene changes are hot-swapped over mpv's IPC
  socket, so there's no flash.
- `live-wallpaper daemon` (started at login) checks the schedule every 30 seconds and restarts
  `mpvpaper` if it ever dies.
- Bar colours are written to `~/.config/omarchy-live-wallpaper/waybar-match.css`, `@import`ed by
  `~/.config/waybar/style.css`; `live-wallpaper` restarts waybar after writing it so the change
  shows immediately. Only background/foreground are touched.

## Uninstall

```bash
~/.local/share/omarchy-live-wallpaper/uninstall.sh            # keeps your config and packs
~/.local/share/omarchy-live-wallpaper/uninstall.sh --purge    # removes them too
```

This removes the menu entry, autostart line, command and bar colours.

## License

MIT. See [LICENSE](LICENSE). This covers the code and the included videos.
