# Notification ticker

An [Omarchy](https://omarchy.org/) plugin that shows notifications as a news ticker along the bottom of the screen.

Omarchy has one notification daemon. A second plugin cannot listen on that bus, so this plugin is that daemon with the ticker added. Its manifest sets `clonedFrom` to `omarchy.notifications`. Enabling it turns the built-in daemon off. Removing it turns the built-in daemon back on.

The ticker is on by default. New notifications scroll on every screen except a tall narrow one, such as a portrait side panel. Hover pauses the scroll and the timeout. Click the line to drop the oldest notification. The × clears them. A critical notification stays until you dismiss it, and the border turns urgent. Switching the ticker off brings back the usual top-right cards. Do-not-disturb is unchanged.

The preference is stored on this machine at `~/.local/state/omarchy/notifications.json` under `ticker`. History and silenced notifications stay in `~/.local/state/omarchy/notifications/`.

This copy is based on the Omarchy 4.0.5 notification plugin. See `NOTICE.md`.

## Install

The plugin id is `bentcharge.notification-ticker`.

Only one notification daemon can run. If another clone of `omarchy.notifications` is already enabled, remove that clone before enabling this plugin. Removing the clone restores the built-in daemon, and enabling this plugin replaces that daemon again.

```bash
omarchy plugin remove <other-notification-plugin> --yes
```

`omarchy plugin add` installs a git repository whose root is this folder. From a published checkout:

```bash
omarchy plugin add https://github.com/generational-software/notification-ticker.git --enable --yes
omarchy restart shell
```

From this folder before it is published, validate it and copy it into the plugin directory. The shell refuses symlinks inside a plugin.

```bash
omarchy plugin validate .
rm -rf ~/.config/omarchy/plugins/bentcharge.notification-ticker
cp -a . ~/.config/omarchy/plugins/bentcharge.notification-ticker
omarchy plugin enable bentcharge.notification-ticker --yes
omarchy restart shell
```

The service stays loaded, so a later edit needs `omarchy restart shell` before it shows up.

Add the menu row by merging `omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc`. The row is **Toggle → Notification Ticker**.

## Switch

```bash
omarchy-shell notifications toggleTicker
omarchy-shell notifications setTicker on
omarchy-shell notifications setTicker off
omarchy-shell notifications tickerState
```

## Remove

```bash
omarchy plugin remove bentcharge.notification-ticker --yes
omarchy restart shell
```

That deletes `~/.config/omarchy/plugins/bentcharge.notification-ticker` and turns the built-in notification daemon back on. The history and the `ticker` setting under `~/.local/state/omarchy/` stay.

## License

MIT. The notification daemon files are derived from Omarchy. See `NOTICE.md`.
