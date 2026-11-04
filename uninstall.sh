#!/usr/bin/env bash
# Removes everything install.sh added. Your config and your own packs in
# ~/.config/omarchy-live-wallpaper are kept unless you pass --purge.
#
#   ~/.local/share/omarchy-live-wallpaper/uninstall.sh [--purge]

set -uo pipefail

INSTALL_DIR="${LW_INSTALL_DIR:-$HOME/.local/share/omarchy-live-wallpaper}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-live-wallpaper"
PLUGIN_ID="io.github.vienjunaid.live-wallpaper"
BIN="$HOME/.local/bin/live-wallpaper"
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

# Bar colours back to the theme's (and any values of yours we had replaced).
[[ -x $BIN ]] && "$BIN" bar clear >/dev/null 2>&1 && say "Restored the bar colours"

[[ -x $BIN ]] && "$BIN" stop --all
pkill -x mpvpaper 2>/dev/null && say "Stopped mpvpaper"

omarchy-shell shell hide "$PLUGIN_ID" >/dev/null 2>&1
omarchy-shell shell setPluginEnabled "$PLUGIN_ID" false >/dev/null 2>&1
rm -rf "$HOME/.config/omarchy/plugins/$PLUGIN_ID" && say "Removed the picker plugin"

if [[ -f $CONFIG_DIR/.disabled-omarchy-background ]]; then
  omarchy-shell shell setPluginEnabled omarchy.background true >/dev/null 2>&1
  rm -f "$CONFIG_DIR/.disabled-omarchy-background"
  say "Turned Omarchy's normal background back on"
fi

strip_block "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
strip_block "$HOME/.config/hypr/autostart.lua"
strip_block "$HOME/.config/hypr/autostart.conf"

[[ -L $BIN ]] && rm -f "$BIN" && say "Removed $BIN"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-live-wallpaper" "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-live-wallpaper" \
  "${XDG_RUNTIME_DIR:-/tmp}/omarchy-live-wallpaper"
[[ -d $INSTALL_DIR/.git ]] && rm -rf "$INSTALL_DIR" && say "Removed $INSTALL_DIR"

if $PURGE; then
  rm -rf "$CONFIG_DIR" && say "Removed $CONFIG_DIR (config and your own packs)"
else
  say "Kept $CONFIG_DIR (config and your own packs). Use --purge to remove it too."
fi
say "Uninstalled."
