#!/bin/bash
# Runs the plugin against a throwaway HOME with stubbed desktop commands.
# shellcheck disable=SC2016 # the stubs expand their variables when they run
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$ROOT/bin/vivaldi-omarchy
SANDBOX=$(mktemp -d)
trap 'kill "${fake_pid:-}" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
failures=0

pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }
expect() { # message command...
  local message=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$message"; else fail "$message"; fi
}
refuse() { # message command...
  local message=$1
  shift
  if "$@" >/dev/null 2>&1; then fail "$message"; else pass "$message"; fi
}

export HOME=$SANDBOX/home
export XDG_CONFIG_HOME=$HOME/.config
unset HYPRLAND_INSTANCE_SIGNATURE OMARCHY_PATH VIVALDI_OMARCHY_IGNORE_HYPRCHROMA
PROFILE=$XDG_CONFIG_HOME/vivaldi
THEME=$HOME/.local/state/omarchy/current/theme
STATE=$HOME/.local/state/vivaldi-omarchy
HYPR=$XDG_CONFIG_HOME/hypr/hyprland.lua
MENU=$XDG_CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc
FLAGS=$XDG_CONFIG_HOME/vivaldi-stable.conf
PREFS=$PROFILE/Default/Preferences

mkdir -p "$SANDBOX/bin" "$PROFILE/Default" "$THEME" "$(dirname "$HYPR")" "$(dirname "$MENU")"
export PATH=$SANDBOX/bin:$PATH

stub() { printf '#!/bin/bash\n%s\n' "$2" >"$SANDBOX/bin/$1"; chmod +x "$SANDBOX/bin/$1"; }
stub omarchy 'if [[ $1 == hook ]]; then d=$XDG_CONFIG_HOME/omarchy/hooks/$3.d; mkdir -p "$d"; cp "$4" "$d/"; fi'
stub omarchy-notification-send 'echo "$@" >>"$HOME/notifications"'
stub omarchy-cmd-default-browser 'cat "$HOME/default-browser" 2>/dev/null || echo chromium.desktop'
stub xdg-settings 'echo "$3" >"$HOME/default-browser"'
stub xdg-mime '[[ $1 == query ]] && echo omarchy-browser.desktop; exit 0'
stub vivaldi-stable 'exit 0'
stub systemctl 'exit 3'

printf -- '-- user config\nrequire("hypr.input")\n\n-- Omarchy'"'"'s browser rule expects "Vivaldi-stable", but the Wayland class is lowercase.\no.window("vivaldi-stable", { tag = "+chromium-based-browser" })\no.window("vivaldi-stable", { tag = "-default-opacity" })\n' >"$HYPR"
printf '{\n  // a comment\n  "personal": {"icon":"x","label":"Personal"},\n}\n' >"$MENU"
printf '{"profile":{"info_cache":{"Default":{}}}}\n' >"$PROFILE/Local State"
printf '{"keep":1,"vivaldi":{"themes":{"current":"Mine","user":[{"id":"Mine"}]},"theme":{"schedule":{"o_s":{"dark":"Mine","light":"Mine"}}}}}\n' >"$PREFS"
printf 'accent = "#111111"\nbackground = "#222222"\ndark_background = "#333333"\nforeground = "#444444"\n' >"$THEME/colors.toml"
cp "$MENU" "$SANDBOX/menu.orig"
cp "$PREFS" "$SANDBOX/prefs.orig"

menu_json() { sed -E '/^[[:space:]]*\/\//d' "$MENU" | tr '\n' ' ' | sed -E 's/,[[:space:]]*}/}/g'; }
hypr_copy=$SANDBOX/hypr.dry; cp "$HYPR" "$hypr_copy"

"$T" setup --dry-run >"$SANDBOX/dry.out" 2>&1
expect "dry run writes nothing" cmp -s "$HYPR" "$hypr_copy"
refuse "dry run creates no flags file" test -e "$FLAGS"
expect "dry run reports the changes" grep -q 'would change' "$SANDBOX/dry.out"

"$T" first-run; "$T" first-run
expect "first run notifies once" test "$(wc -l <"$HOME/notifications")" = 1

"$T" setup >/dev/null
expect "manual Hyprland rules are migrated" test "$(grep -c 'tag = "+chromium-based-browser"' "$HYPR")" = 1
expect "Hyprland config keeps user lines" grep -q 'require("hypr.input")' "$HYPR"
expect "menu stays valid JSON" jq -e '.["setup.default.browser.vivaldi"] and .personal' <<<"$(menu_json)"
expect "flags are written" grep -q -- '--load-extension' "$FLAGS"
expect "hooks are installed" test -x "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/vivaldi-omarchy-theme"
expect "doctor passes after setup" "$T" doctor --quiet

find "$XDG_CONFIG_HOME" -name '*.bak.*' -delete
cp -r "$XDG_CONFIG_HOME" "$SANDBOX/snapshot"
"$T" setup >/dev/null
expect "second setup changes nothing" diff -r -x Preferences -x 'Preferences.bak*' "$XDG_CONFIG_HOME" "$SANDBOX/snapshot"

expect "theme is applied" jq -e '.vivaldi.themes.current == "Omarchy" and (.vivaldi.themes.user[] | select(.id == "Omarchy") | .colorBg == "#222222" and .colorHighlightBg == "#111111")' "$PREFS"
expect "other settings survive" jq -e '.keep == 1' "$PREFS"

cp "$(command -v sleep)" "$SANDBOX/vivaldi-bin"
"$SANDBOX/vivaldi-bin" 60 &
fake_pid=$!
ln -s "host-$fake_pid" "$PROFILE/SingletonLock"
printf 'accent = "#aaaaaa"\nbackground = "#bbbbbb"\nforeground = "#cccccc"\n' >"$THEME/colors.toml"
cp "$PREFS" "$SANDBOX/prefs.open"
"$T" theme sync >/dev/null
expect "an open Vivaldi isn't touched" cmp -s "$PREFS" "$SANDBOX/prefs.open"
expect "the theme stays queued" test -f "$STATE/pending.json"
kill "$fake_pid"; wait "$fake_pid" 2>/dev/null
"$T" theme apply >/dev/null
expect "queued theme applies after close" jq -e '.vivaldi.themes.user[] | select(.id == "Omarchy") | .colorBg == "#bbbbbb"' "$PREFS"
refuse "the queue is cleared" test -f "$STATE/pending.json"
rm -f "$PROFILE/SingletonLock"

mkdir -p "$HOME/.local/state/hyprchroma"
printf '{"frameworks":{"browsers":true}}\n' >"$HOME/.local/state/hyprchroma/settings.json"
stub systemctl 'exit 0'
cp "$PREFS" "$SANDBOX/prefs.hc"
printf 'accent = "#010101"\nbackground = "#020202"\nforeground = "#030303"\n' >"$THEME/colors.toml"
"$T" theme sync >/dev/null
expect "Hyprchroma keeps ownership of the theme" cmp -s "$PREFS" "$SANDBOX/prefs.hc"
stub systemctl 'exit 3'

sed -i 's/--no-default-browser-check/--changed/' "$FLAGS"
refuse "doctor catches outdated flags" "$T" doctor --quiet
"$T" setup >/dev/null

"$T" default
expect "default sets Vivaldi" test "$(cat "$HOME/default-browser")" = vivaldi-stable.desktop

"$T" uninstall >/dev/null
expect "uninstall restores the menu" cmp -s "$MENU" "$SANDBOX/menu.orig"
refuse "uninstall removes Hyprland rules" grep -q vivaldi "$HYPR"
refuse "uninstall removes flags" test -e "$FLAGS"
refuse "uninstall removes hooks" test -e "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/vivaldi-omarchy-theme"
expect "uninstall restores the theme" test "$(jq -cS '.vivaldi' "$PREFS")" = "$(jq -cS '.vivaldi' "$SANDBOX/prefs.orig")"
refuse "uninstall removes state" test -e "$STATE"

echo
if ((failures)); then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
