# omarchy-live-wallpaper

Animated video wallpapers for [Omarchy](https://omarchy.org), with a visual picker and a bar that
matches the scene.

- **Visual picker.** SUPER+SPACE → Style → Live wallpaper opens a carousel. The big card in the
  middle plays the real video, smaller cards show the other scenes, and nothing changes until you
  press **Save**.
- **Follows a schedule.** The included pack changes scene with the five daily prayer times. Packs can
  also follow the time of day, or you can pin one scene.
- **Bar matches the wallpaper.** The Omarchy bar, popups and menu highlight take their colours from
  the scene that's playing. Turn it off any time; your own colours come back.
- **Packs.** Wallpapers come in packs: a folder of videos plus a small `pack.json`. Drop a video in
  and it appears in the picker. See [docs/creating-a-pack.md](docs/creating-a-pack.md).

## Install

Needs **Omarchy 4** or newer.

```bash
curl -fsSL https://raw.githubusercontent.com/VienJunaid/omarchy-live-wallpaper/main/install.sh | bash
```

The installer:

1. installs `mpvpaper` (from the AUR) plus `python` and `ffmpeg` if they're missing,
2. puts the `live-wallpaper` command in `~/.local/bin`,
3. installs the picker into the Omarchy shell and adds **Style → Live wallpaper** and **Style → Match bar** to the menu,
4. starts a small background loop at login (`~/.config/hypr/autostart.lua`) and starts it now,
5. turns off Omarchy's static background, which would otherwise cover the video.

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

Want a key for "next scene"? Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + U", "Next live wallpaper", "live-wallpaper next")
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
plugin/                 the carousel picker: an omarchy-shell overlay plugin (QML), calls `live-wallpaper list --json`
packs/<id>/             pack.json + videos/*.mp4
install.sh              one-command install; uninstall.sh reverses it
```

- `mpvpaper` plays the video on the background layer. Scene changes are hot-swapped over mpv's IPC
  socket, so there's no flash.
- `live-wallpaper daemon` (started at login) checks the schedule every 30 seconds and restarts
  `mpvpaper` if it ever dies.
- Bar colours are written to `~/.config/omarchy/shell.toml`, which the shell hot-reloads. Only the
  keys it manages are touched, and any of your own values it replaces are put back when matching is
  turned off.

## Uninstall

```bash
~/.local/share/omarchy-live-wallpaper/uninstall.sh            # keeps your config and packs
~/.local/share/omarchy-live-wallpaper/uninstall.sh --purge    # removes them too
```

This removes the menu entries, picker, autostart line, command and bar colours, and turns
Omarchy's normal background back on.

## License

MIT. See [LICENSE](LICENSE). This covers the code and the included videos.
