# Creating a wallpaper pack

A **pack** is a folder of videos plus a small `pack.json`. Every video in it is a **scene**: it
shows up in the picker, can be saved as your wallpaper, gets a thumbnail, and gets a matching bar
colour scheme. No code changes are needed.

## Where packs live

| Location | For |
|---|---|
| `~/.config/omarchy-live-wallpaper/packs/<pack-id>/` | your own packs (kept on update and uninstall) |
| `packs/<pack-id>/` in this repo | packs shipped to everyone (send a pull request) |

If both have a pack with the same id, yours wins.

## The smallest possible pack

```
~/.config/omarchy-live-wallpaper/packs/my-scenes/
├── pack.json          {"name": "My Scenes"}
└── videos/
    ├── forest.mp4
    └── harbour-at-night.mp4
```

Open the picker (`live-wallpaper`) and both scenes are there, named "Forest" and
"Harbour At Night". That's it.

## Videos

- **Format:** `.mp4` (H.264) is the safest; `.webm`, `.mkv` and `.mov` also work. The file name
  (without the extension) is the scene's id: lowercase with dashes, e.g. `harbour-at-night.mp4`.
- **Size:** 1920×1080 at 24–30 fps is plenty. The wallpaper is cropped to fill the screen, so
  keep the important part near the middle.
- **Looping:** videos loop forever, so make the last frame flow into the first. 30–120 s loops work
  well.
- **Weight:** a 60 s, 1080p clip at a modest bitrate is 2–10 MB. Re-encode big files with:
  `ffmpeg -i in.mp4 -c:v libx264 -crf 26 -preset slow -an -movflags +faststart out.mp4`
- **Thumbnails** are taken 5 seconds in and cached in `~/.cache/omarchy-live-wallpaper/posters/`.
  They refresh automatically when a video changes.

## pack.json reference

Everything except `name` is optional.

```jsonc
{
  "name": "My Scenes",
  "description": "Shown by `live-wallpaper packs`.",

  // Where the videos are. Default: the "videos" folder next to pack.json. Can be absolute or
  // start with ~, so a pack can point at videos that live somewhere else (e.g. a render folder).
  "videos_dir": "videos",

  // Videos in videos_dir to leave out.
  "exclude": ["work-in-progress"],

  // What "follow schedule" plays (used when this pack is the one in config.json → "follow").
  "schedule": {
    // Five daily prayers: each one maps to a scene id. Fajr lasts until Dhuhr, Isha until Fajr.
    "type": "prayer",
    "map": { "fajr": "forest", "dhuhr": "forest", "asr": "forest", "maghrib": "harbour-at-night", "isha": "harbour-at-night" }
  },
  // ...or by the clock instead (24-hour "HH:MM", the last slot runs past midnight):
  // "schedule": { "type": "time", "slots": [["06:00", "forest"], ["19:00", "harbour-at-night"]] },

  // Per-scene extras, keyed by the video's file name.
  "scenes": {
    "forest": {
      "label": "Forest",                  // shown in the picker (default: the file name, Title Case)
      "subtitle": "Morning mist",         // shown under the label
      "order": 1,                         // sort order in the picker (default: alphabetical)
      "glow": "7fa8ff",                   // window shadow colour while this scene plays (optional)
      "bar": {                            // hand-picked bar colours (optional; sampled from the video otherwise)
        "background": "1f2a44", "alpha": 0.85, "text": "f0cfa2", "active": "7fa8ff",
        "border": ["4b6eb0", "f0cfa2"]
      }
    }
  }
}
```

## Making your pack the one that's followed

Set `"follow"` in `~/.config/omarchy-live-wallpaper/config.json` to your pack's folder name:

```json
{ "follow": "my-scenes" }
```

The background loop picks it up within 30 seconds (or run `live-wallpaper auto` to switch now).

## Checking your pack

```bash
live-wallpaper packs     # is it found? how many scenes? which schedule?
live-wallpaper list      # every scene id
live-wallpaper status    # what's playing and why, plus today's schedule
live-wallpaper set my-scenes/forest
```

## Sharing a pack

Put it under `packs/<pack-id>/` in a fork of this repo and open a pull request. Only include videos
you made or have the right to share.
