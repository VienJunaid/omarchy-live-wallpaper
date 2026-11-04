#!/usr/bin/env bash
# omarchy-live-wallpaper installer.
#
#   curl -fsSL https://raw.githubusercontent.com/VienJunaid/omarchy-live-wallpaper/main/install.sh | bash
#
# or, from a clone:  ./install.sh
#
# Safe to re-run (it updates in place). Every file it edits is backed up first, and every edit is
# wrapped in ">>> omarchy-live-wallpaper" markers so uninstall.sh can take it out again.

set -euo pipefail

REPO_URL="${LW_REPO_URL:-https://github.com/VienJunaid/omarchy-live-wallpaper.git}"
INSTALL_DIR="${LW_INSTALL_DIR:-$HOME/.local/share/omarchy-live-wallpaper}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-live-wallpaper"
PLUGIN_ID="io.github.vienjunaid.live-wallpaper"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
BIN="$HOME/.local/bin/live-wallpaper"
MARK_BEGIN=">>> omarchy-live-wallpaper"
MARK_END="<<< omarchy-live-wallpaper"
STAMP="$(date +%s)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
backup() { [[ -f $1 ]] && cp -a "$1" "$1.bak.$STAMP" || true; }

# ---- 0. this needs Omarchy 4 (Quickshell shell + Lua Hyprland config)
command -v omarchy-shell >/dev/null || die "omarchy-shell not found. This needs Omarchy 4 or newer (https://omarchy.org)."
command -v hyprctl >/dev/null || die "Hyprland not found."

# ---- 1. get the code: use this checkout, or clone/update one
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n $SELF_DIR && -x $SELF_DIR/bin/live-wallpaper && -d $SELF_DIR/plugin ]]; then
  SRC="$SELF_DIR"
  say "Installing from $SRC"
else
  command -v git >/dev/null || omarchy pkg add git
  if [[ -d $INSTALL_DIR/.git ]]; then
    say "Updating $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    say "Downloading to $INSTALL_DIR"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi
  SRC="$INSTALL_DIR"
fi

# ---- 2. dependencies
say "Checking dependencies"
missing=()
for pkg in python ffmpeg; do
  pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
((${#missing[@]})) && omarchy pkg add "${missing[@]}"
if ! command -v mpvpaper >/dev/null; then
  say "Installing mpvpaper from the AUR"
  omarchy pkg aur add mpvpaper || die "Couldn't install mpvpaper. Install it yourself (yay -S mpvpaper) and re-run."
fi

# ---- 3. the command
mkdir -p "$(dirname "$BIN")"
ln -sfn "$SRC/bin/live-wallpaper" "$BIN"
say "Linked $BIN"

# ---- 4. config (kept on re-install)
mkdir -p "$CONFIG_DIR/packs"
if [[ ! -f $CONFIG_DIR/config.json ]]; then
  city="" country=""
  if ! command -v omarchy-prayer >/dev/null && [[ -r /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
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

# ---- 5. the picker (an omarchy-shell overlay plugin)
mkdir -p "$PLUGIN_DIR"
cp -a "$SRC/plugin/." "$PLUGIN_DIR/"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
sleep 1
omarchy-shell shell setPluginEnabled "$PLUGIN_ID" true >/dev/null 2>&1 \
  || warn "Couldn't enable the picker plugin; run: omarchy-shell shell setPluginEnabled $PLUGIN_ID true"
say "Installed the picker plugin"

# Omarchy's own background layer sits on top of mpvpaper; switch it off (uninstall puts it back).
if ! python3 -c "import json,sys; sys.exit(0 if 'omarchy.background' in json.load(open('$HOME/.config/omarchy/shell.json')).get('disabledPlugins',[]) else 1)" 2>/dev/null; then
  omarchy-shell shell setPluginEnabled omarchy.background false >/dev/null 2>&1 || true
  touch "$CONFIG_DIR/.disabled-omarchy-background"
  say "Turned off Omarchy's static background (it would cover the video)"
fi

# ---- 6. menu entries: SUPER+SPACE > Style > Live wallpaper / Bar matches wallpaper
mkdir -p "$(dirname "$MENU_FILE")"
[[ -f $MENU_FILE ]] || printf '{\n}\n' > "$MENU_FILE"
backup "$MENU_FILE"
python3 - "$MENU_FILE" "$MARK_BEGIN" "$MARK_END" <<'PY'
import re, sys
path, begin, end = sys.argv[1:4]
s = open(path, encoding="utf-8").read()
s = re.sub(r"\n?[ \t]*// " + re.escape(begin) + r".*?// " + re.escape(end) + r"[^\n]*", "", s, flags=re.S)
block = (
    f'\n  // {begin} (managed by install.sh - remove with uninstall.sh)\n'
    '  "style.live-wallpaper": {"icon": "\U000f0567", "label": "Live wallpaper", "description": "Preview the live wallpapers and pick one", "aliases": ["live-wallpaper", "wallpaper-video"], "action": "$HOME/.local/bin/live-wallpaper pick"},\n'
    '  "style.live-wallpaper-bar": {"icon": "\U000f03d8", "label": "Bar matches wallpaper", "aliases": ["bar-style"], "action": "$HOME/.local/bin/live-wallpaper bar toggle", "checked": "[ \\"$($HOME/.local/bin/live-wallpaper bar)\\" = match ]"},\n'
    f'  // {end}'
)
i = s.index("{")
# Entries end with a comma; the menu's JSONC reader drops a trailing comma before "}".
s = s[: i + 1] + block + s[i + 1 :]
open(path, "w", encoding="utf-8").write(s)
PY
say "Added the menu entries (Style > Live wallpaper)"

# ---- 7. start at login
HYPR_LUA="$HOME/.config/hypr/autostart.lua"
HYPR_CONF="$HOME/.config/hypr/autostart.conf"
strip_block() { python3 - "$1" "$MARK_BEGIN" "$MARK_END" <<'PY'
import re, sys
path, begin, end = sys.argv[1:4]
s = open(path).read()
s = re.sub(r"\n?[^\n]*" + re.escape(begin) + r".*?" + re.escape(end) + r"[^\n]*", "", s, flags=re.S)
open(path, "w").write(s.rstrip("\n") + "\n")
PY
}
if [[ -f $HYPR_LUA ]]; then
  backup "$HYPR_LUA"; strip_block "$HYPR_LUA"
  printf '\n-- %s\no.launch_on_start(os.getenv("HOME") .. "/.local/bin/live-wallpaper daemon")\n-- %s\n' \
    "$MARK_BEGIN" "$MARK_END" >> "$HYPR_LUA"
  say "Added the background loop to $HYPR_LUA"
else
  touch "$HYPR_CONF"; backup "$HYPR_CONF"; strip_block "$HYPR_CONF"
  printf '\n# %s\nexec-once = uwsm-app -- %s daemon\n# %s\n' "$MARK_BEGIN" "$BIN" "$MARK_END" >> "$HYPR_CONF"
  say "Added the background loop to $HYPR_CONF"
fi

# ---- 8. start it now
pkill -f "live-wallpaper daemon" 2>/dev/null || true
sleep 0.5
setsid -f "$BIN" daemon >/dev/null 2>&1 < /dev/null
sleep 3

echo
"$BIN" doctor || true
echo
say "Done. Open the picker with SUPER+SPACE > Style > Live wallpaper (or run: live-wallpaper)."
say "Add your own wallpapers: see $SRC/docs/creating-a-pack.md"
