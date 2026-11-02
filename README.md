# Vivaldi for Omarchy

Makes Vivaldi behave like a supported Omarchy browser, without changing anything in `/usr/share/omarchy/`.

- Default, Install and Remove rows in the Omarchy menu
- The same window rules as other Chromium-based browsers: tiling, opacity and Google Meet picture-in-picture
- Omarchy's bundled `copy-url`, `yt-dlp` and `whatsapp-slim` extensions
- Omarchy theme colours, applied the next time Vivaldi starts
- A `doctor` command that checks the setup, and runs after each `omarchy update`

## Install

```bash
omarchy plugin add https://github.com/danXignat/omarchy-vivaldi --enable
~/.config/omarchy/plugins/io.github.danxignat.vivaldi/bin/vivaldi-omarchy setup --default
```

Then restart Vivaldi. Leave out `--default` to keep your current default browser.

Adding a plugin can't run any setup, and this plugin won't edit your config until you ask, so it sends one notification until `setup` has been run. To preview the changes first, run `setup --dry-run`.

## What setup changes

Each edit is a marked block, backed up first as `<file>.bak.<timestamp>`, and running setup again changes nothing further.

| Change | Location |
|---|---|
| Window rules | `~/.config/hypr/hyprland.lua` |
| Menu rows | `~/.config/omarchy/extensions/omarchy-menu.jsonc` |
| Flags and extensions | `~/.config/vivaldi-stable.conf` |
| Hooks | `~/.config/omarchy/hooks/theme-set.d/` and `post-update.d/` |
| Theme | `Preferences` in each Vivaldi profile, only while Vivaldi is closed, backed up as `Preferences.bak.vivaldi-omarchy` |
| Default browser (only with `--default`) | `~/.config/mimeapps.list` |
| Policy (only with `--policy`) | `/etc/vivaldi/policies/managed/omarchy.json` |

## Commands

```
vivaldi-omarchy setup [--default] [--policy] [--dry-run]
vivaldi-omarchy doctor [--quiet]
vivaldi-omarchy default
vivaldi-omarchy theme <sync|apply>
vivaldi-omarchy remove
vivaldi-omarchy uninstall
```

After `omarchy plugin update`, run `doctor`, and re-run `setup` if it reports anything outdated.

## Theme

Vivaldi overwrites `Preferences` when it exits, so a theme can't be applied while it's open. A theme change waits until Vivaldi closes and shows on its next start.

If [Hyprchroma](https://github.com/NobleDoodle/omarchroma) is running with its `browsers` option on, this plugin leaves the theme to it so the two don't conflict.

## Dependencies and privileges

- Requires Omarchy 4, `jq` and the `vivaldi` package (stable channel only). The menu's Install row uses `omarchy-pkg-add`.
- Runs with your user permissions, like every Omarchy plugin.
- Root is only used by `setup --policy`, by `uninstall` to remove that policy file, and by `remove` to drop the package. It uses `sudo` in a terminal and `pkexec` otherwise.
- `systemctl --user is-active` is used read-only, to detect Hyprchroma.
- The service does nothing beyond checking for a queued theme every 10 seconds. It makes no network requests.

## Limits

These need changes in Omarchy itself:

- `omarchy default browser vivaldi` fails. Use the menu row or `vivaldi-omarchy default`.
- `omarchy-cmd-browser-handoff` doesn't support Vivaldi, so links take the normal launch path, which is slightly slower.

`--password-store` is deliberately not set, because changing it could lock Vivaldi out of saved passwords.

## Uninstall

Close Vivaldi first if the plugin has applied its theme.

```bash
~/.config/omarchy/plugins/io.github.danxignat.vivaldi/bin/vivaldi-omarchy uninstall
omarchy plugin remove io.github.danxignat.vivaldi
```

This removes the marked blocks and hooks and restores your previous theme. Your default browser and Vivaldi itself stay as they are; if you want to remove Vivaldi too, run `vivaldi-omarchy remove` before these two commands.

## Development

```bash
tests/run.sh
shellcheck bin/vivaldi-omarchy hooks/* tests/run.sh
omarchy plugin validate .
```

## License

[MIT](LICENSE)
