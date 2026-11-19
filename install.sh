#!/usr/bin/env bash
# omarchy-live-wallpaper installer -- LEGACY PORT for pre-Omarchy-4 (waybar + walker,
# .conf Hyprland config; no omarchy-shell/Quickshell). See docs/legacy-port.md.
#
#   ./install.sh   (run from a clone of this folder)
#
# Safe to re-run (it updates in place). Every file it edits is backed up first, and every edit is
# wrapped in ">>> omarchy-live-wallpaper" markers so uninstall.sh can take it out again.

set -euo pipefail

INSTALL_DIR="${LW_INSTALL_DIR:-$HOME/.local/share/omarchy-live-wallpaper}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-live-wallpaper"
BIN="$HOME/.local/bin/live-wallpaper"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
AUTOSTART="$HOME/.config/hypr/autostart.conf"
MENU_EXT="$HOME/.config/omarchy/extensions/menu.sh"
MARK_BEGIN=">>> omarchy-live-wallpaper"
MARK_END="<<< omarchy-live-wallpaper"
STAMP="$(date +%s)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
backup() { [[ -f $1 ]] && cp -a "$1" "$1.bak.$STAMP" || true; }
strip_block() { # file
  [[ -f $1 ]] || return 0
  grep -q "$MARK_BEGIN" "$1" || return 0
  python3 - "$1" "$MARK_BEGIN" "$MARK_END" <<'PY'
import re, sys
path, begin, end = sys.argv[1:4]
s = open(path, encoding="utf-8").read()
s = re.sub(r"\n?[^\n]*" + re.escape(begin) + r".*?" + re.escape(end) + r"[^\n]*", "", s, flags=re.S)
open(path, "w", encoding="utf-8").write(s.rstrip("\n") + "\n")
PY
}

# ---- 0. this is the legacy port: needs Hyprland + waybar + walker (not omarchy-shell)
command -v hyprctl >/dev/null || die "Hyprland not found."
command -v waybar >/dev/null || die "waybar not found. This port is for pre-Omarchy-4 (waybar) setups; on Omarchy 4+ use the main install.sh instead."
command -v walker >/dev/null || warn "walker not found; 'live-wallpaper pick' needs it (you can still use 'live-wallpaper set <scene>')."
if command -v omarchy-shell >/dev/null; then
  warn "omarchy-shell was found -- you may already be on Omarchy 4. The main install.sh (with the visual picker) is the better fit; see docs/legacy-port.md."
fi

# ---- 1. get the code: use this checkout
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
[[ -n $SELF_DIR && -x $SELF_DIR/bin/live-wallpaper ]] || die "run this from a clone of the repo (./install.sh)"
SRC="$SELF_DIR"
say "Installing from $SRC"

# ---- 2. dependencies
say "Checking dependencies"
missing=()
for pkg in python ffmpeg; do
  pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if ((${#missing[@]})); then
  command -v sudo >/dev/null && sudo pacman -S --needed --noconfirm "${missing[@]}" \
    || die "install these yourself and re-run: ${missing[*]}"
fi
if ! command -v mpvpaper >/dev/null; then
  say "mpvpaper not found -- install it from the AUR (e.g. yay -S mpvpaper) and re-run."
  die "missing mpvpaper"
fi

# ---- 3. the command
mkdir -p "$(dirname "$BIN")"
ln -sfn "$SRC/bin/live-wallpaper" "$BIN"
say "Linked $BIN"

# ---- 4. config (kept on re-install)
mkdir -p "$CONFIG_DIR/packs"
if [[ ! -f $CONFIG_DIR/config.json ]]; then
  city="" country=""
  if [[ -r /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
    echo
    echo "The included pack follows the five daily prayer times. Where are you?"
    echo "(Leave blank to use fixed approximate times; you can change this later in $CONFIG_DIR/config.json)"
    read -r -p "  City: " city < /dev/tty || true
    [[ -n $city ]] && read -r -p "  Country (e.g. US, GB, Saudi Arabia): " country < /dev/tty || true
  fi
  python3 - "$CONFIG_DIR/config.json" "$city" "$country" <<'PY'
import json, sys
path, city, country = sys.argv[1:4]
cfg = {
    "follow": "sacred-places",
    "prayer_source": "auto",
    "location": {"city": city, "country": country, "method": 2},
    "bar": "match",
    "glow": True,
    "restart_on_workspace_switch": False,
}
open(path, "w").write(json.dumps(cfg, indent=2) + "\n")
PY
  say "Wrote $CONFIG_DIR/config.json"
else
  say "Keeping existing $CONFIG_DIR/config.json"
fi

# ---- 5. bar matching: @import our override file into waybar's style.css, after the theme's own
mkdir -p "$(dirname "$WAYBAR_STYLE")"
[[ -f $WAYBAR_STYLE ]] || printf '@import "../omarchy/current/theme/waybar.css";\n' > "$WAYBAR_STYLE"
backup "$WAYBAR_STYLE"
strip_block "$WAYBAR_STYLE"
python3 - "$WAYBAR_STYLE" "$CONFIG_DIR/waybar-match.css" "$MARK_BEGIN" "$MARK_END" <<'PY'
import sys
path, css, begin, end = sys.argv[1:5]
s = open(path, encoding="utf-8").read()
block = f'/* {begin} (managed by install.sh - remove with uninstall.sh) */\n@import "{css}";\n/* {end} */\n'
lines = s.splitlines(keepends=True)
i = next((n + 1 for n, l in enumerate(lines) if l.strip().startswith("@import")), 0)
lines.insert(i, block)
open(path, "w", encoding="utf-8").write("".join(lines))
PY
say "Hooked bar matching into $WAYBAR_STYLE"
[[ -f $CONFIG_DIR/waybar-match.css ]] || echo "/* omarchy-live-wallpaper: not started yet */" > "$CONFIG_DIR/waybar-match.css"

# ---- 6. menu entry: Style > Live wallpaper / Match bar (omarchy-menu user extension)
mkdir -p "$(dirname "$MENU_EXT")"
[[ -f $MENU_EXT ]] || printf '# user extensions -- see omarchy-menu\n' > "$MENU_EXT"
backup "$MENU_EXT"
strip_block "$MENU_EXT"
cat >> "$MENU_EXT" <<EOF

# $MARK_BEGIN (managed by install.sh - remove with uninstall.sh)
# Adds Live wallpaper / Match bar to Style, on top of omarchy-menu's own show_style_menu.
show_style_menu() {
  case \$(menu "Style" "󰸌  Theme\n󰟵  Unlock\n  Font\n  Background\n  Hyprland\n󱄄  Screensaver\n  Live wallpaper\n  Match bar\n  About") in
  *Theme*) show_theme_menu ;;
  *Unlock*) omarchy-launch-walker -m menus:omarchyunlocks --width 800 --minheight 400 ;;
  *Font*) show_font_menu ;;
  *Background*) show_background_menu ;;
  *Hyprland*) open_in_editor ~/.config/hypr/looknfeel.conf ;;
  *Screensaver*) show_screensaver_menu ;;
  *"Live wallpaper"*) live-wallpaper pick ;;
  *"Match bar"*) live-wallpaper bar toggle ;;
  *About*) show_about_menu ;;
  *) show_main_menu ;;
  esac
}
# $MARK_END
EOF
say "Added Style > Live wallpaper / Match bar to $MENU_EXT"

# ---- 7. start at login (.conf Hyprland, no autostart.lua here)
mkdir -p "$(dirname "$AUTOSTART")"
touch "$AUTOSTART"
backup "$AUTOSTART"
strip_block "$AUTOSTART"
printf '\n# %s\nexec-once = uwsm-app -- %s daemon\n# %s\n' "$MARK_BEGIN" "$BIN" "$MARK_END" >> "$AUTOSTART"
say "Added the background loop to $AUTOSTART"

# ---- 8. start it now
"$BIN" stop >/dev/null 2>&1 || true
sleep 0.5
setsid -f "$BIN" daemon >/dev/null 2>&1 < /dev/null
sleep 3

echo
"$BIN" doctor || true
echo
say "Done. Open the picker with SUPER+SPACE > Style > Live wallpaper (or run: live-wallpaper pick)."
say "Keybinding for 'next scene': add to ~/.config/hypr/bindings.conf:"
say '  bind = SUPER, U, exec, live-wallpaper next'
say "Add your own wallpapers: see $SRC/docs/creating-a-pack.md"
