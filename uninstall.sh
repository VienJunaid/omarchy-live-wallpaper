#!/usr/bin/env bash
# Removes everything install.sh (legacy port) added. Your config and your own packs in
# ~/.config/omarchy-live-wallpaper are kept unless you pass --purge.
#
#   ~/.local/share/omarchy-live-wallpaper/uninstall.sh [--purge]

set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-live-wallpaper"
BIN="$HOME/.local/bin/live-wallpaper"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
AUTOSTART="$HOME/.config/hypr/autostart.conf"
MENU_EXT="$HOME/.config/omarchy/extensions/menu.sh"
MARK_BEGIN=">>> omarchy-live-wallpaper"
MARK_END="<<< omarchy-live-wallpaper"
STAMP="$(date +%s)"
PURGE=false; [[ ${1:-} == --purge ]] && PURGE=true

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

strip_block() { # file
  [[ -f $1 ]] || return 0
  grep -q "$MARK_BEGIN" "$1" || return 0
  cp -a "$1" "$1.bak.$STAMP"
  python3 - "$1" "$MARK_BEGIN" "$MARK_END" <<'PY'
import re, sys
path, begin, end = sys.argv[1:4]
s = open(path, encoding="utf-8").read()
s = re.sub(r"\n?[^\n]*" + re.escape(begin) + r".*?" + re.escape(end) + r"[^\n]*", "", s, flags=re.S)
open(path, "w", encoding="utf-8").write(s.rstrip("\n") + "\n")
PY
  say "Cleaned $1"
}

# Bar colours back to the theme's, and waybar restarted to drop the override.
[[ -x $BIN ]] && "$BIN" bar clear >/dev/null 2>&1
command -v omarchy-restart-waybar >/dev/null && omarchy-restart-waybar >/dev/null 2>&1 \
  || { pkill -x waybar 2>/dev/null; setsid uwsm-app -- waybar >/dev/null 2>&1 & disown; }
say "Restored the bar colours"

[[ -x $BIN ]] && "$BIN" stop --all
pkill -x mpvpaper 2>/dev/null && say "Stopped mpvpaper"

strip_block "$WAYBAR_STYLE"
strip_block "$MENU_EXT"
strip_block "$AUTOSTART"

[[ -L $BIN ]] && rm -f "$BIN" && say "Removed $BIN"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-live-wallpaper" "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-live-wallpaper" \
  "${XDG_RUNTIME_DIR:-/tmp}/omarchy-live-wallpaper"

if $PURGE; then
  rm -rf "$CONFIG_DIR" && say "Removed $CONFIG_DIR (config and your own packs)"
else
  say "Kept $CONFIG_DIR (config and your own packs). Use --purge to remove it too."
fi
say "Uninstalled."
