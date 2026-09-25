# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Super Menu (`io.github.irostom.super-menu`) is an Omarchy 4.x shell plugin (QML/Quickshell) that replaces the built-in `omarchy.menu`. It declares `omarchy.clonedFrom: "omarchy.menu"`, so the shell routes all calls aimed at the built-in menu, including SUPER+Space and every dmenu caller, to this plugin once it is enabled. Keep the stock menu's behaviour working: the JSONC menu tree, `provider` submenus, `when:`/`checked:` guards, and dmenu `select`/`input` modes. Other Omarchy scripts depend on them.

README.md is the user-facing spec: keybindings, the query-plugin descriptor format, and the file table. Keep it in sync when behaviour changes.

## Development loop

There is no build step, linter or test suite. The repo is symlinked as `~/.config/omarchy/plugins/io.github.irostom.super-menu`, so edits are live after a reload:

```bash
omarchy restart shell                          # reload QML changes
omarchy menu refresh                           # re-read menu JSONC + query plugins only
omarchy plugin validate "$PWD"                 # check manifest.json against the schema
omarchy-shell shell call io.github.irostom.super-menu selftest '{"query":"100 usd to eur"}'
```

`selftest` reports the loaded plugins, whether runtime JS compilation works, the app count, and which plugins match a query, all without opening the menu. `QueryPlugins.js` is pure JS (`.pragma library`, no QML imports) and is written so it can be exercised with node.

## Architecture

- **`Menu.qml`** is the entry point and holds all the logic: IPC hooks (`open`, `close`, `refresh`, `selftest`), menu tree loading, providers, dmenu, query-plugin processes, and keyboard handling. It began as a clone of upstream, and the query-plugin additions are marked in the source.
- **`launcher/`** is the view layer. `Appearance.qml` holds the visual tokens and window size, and `LauncherState.qml` holds the state the views read. `Menu.qml` instantiates both and re-exposes their properties as `property alias` under their original names (`root.filterText`, `root.selectedIndex`, ...), so the cloned logic stays close to upstream while the view components take the state object. Put new view state in `LauncherState` and alias it in `Menu.qml`.
- **`.pragma library` JS modules** have no QML access. `MenuModel.js` holds the model helpers, `QueryPlugins.js` the registry, trigger gate, row normalisation and descriptor compilation, `QueryBuiltins.js` the shipped plugin descriptors, `Actions.js` the per-row actions and shortcuts, and `Sections.js` the section labels. `Actions.js` hard-codes Qt key and modifier values because `Qt.Key_*` isn't reliably reachable from a library.
- **Query plugins** turn the typed text into answer rows pinned above the search results. `kind: "js"` runs synchronously on the UI thread. `kind: "command"` forks a process, which `Menu.qml` debounces, times out, and disables after three failures in a row. User plugins in `~/.config/omarchy/menu-plugins/*.js` can replace a built-in by reusing its `id`.
- **Calculator gate**: `qalc` exits 0 for almost any word (`qalc -t theme` returns a unit expression), so `QueryPlugins.js` forwards a query only if every alphabetic token is a known unit or currency. Anything else needs the `=` prefix. Don't loosen this gate. `query-plugins/calc.sh` points `XDG_CONFIG_HOME` at a private directory and never refreshes rates on a keystroke (`upxrates 0`).
- **Clipboard History / Search Files / Search Emojis** are three menu items that `Menu.qml` adds itself (`viewItems()`, ids `clipboard-history`, `file-search` and `emoji`). While one of them is active, `rebuildDisplay()` takes rows from `ClipboardSource.qml` or from the `fd` run (`fileSearchProc`, with its own debounce, watchdog and revision) instead of from the menu tree, and `setFilter()` skips query plugins. The clipboard is captured by the first-party `omarchy.clipboard` plugin. We only read its history file and act on entries through the `omarchy-clipboard-*` helpers, by history index. `FileSearch.js` is pure JS, like `QueryPlugins.js`. The emoji view reads `omarchy.emojis`' `emojis.json` in place (`EmojiSource.qml`). Its rows stay one flat `displayModel` list (kind `emoji`, no new roles), and `launcher/EmojiGrid.qml` draws them from `emojiLines` (`EmojiSearch.lines()`), which numbers cells by the same index. `EmojiSearch.js` is pure JS too. The `:` query plugin uses the same data.
- **ListModel roles are fixed by the first row appended.** Every row builder must emit the same key set: `MenuModel.displayRow`, `MenuModel.viewRow`, `QueryPlugins.normalizeRows`, and the dmenu rows in `rebuildDmenuDisplay`. A new role goes into all four.
- **`MenuHistory.qml`** stores Favorites and recents in `$XDG_STATE_HOME/omarchy/menu-history.json`. That file and the qalc state directory are the plugin's own. The only other write is Remove in Clipboard History, which rewrites `omarchy.clipboard`'s history file in that plugin's format.
- **`AppLibrary.qml` / `AppSearch.js`** are verbatim copies of the shell's own services. They're vendored because the shell's `prunePluginApis()` destroys a cloned plugin's injected `appLibrary` and never re-injects it. **`ClipboardHistory.js`** is a verbatim copy of `omarchy.clipboard`'s model, so both plugins parse the history file the same way. Don't modify any of them. Refresh them from `$OMARCHY_PATH/shell/services/` and `shell/plugins/clipboard/` instead.

## Upstream merges and releases

`upstream/` holds pristine copies of `omarchy.menu` (version recorded in `upstream/README.md`). Nothing loads them at runtime. To merge a new Omarchy release:

```bash
U=/usr/share/omarchy/shell/plugins/menu
diff3 -m Menu.qml upstream/Menu.qml $U/Menu.qml > Menu.qml.merged
```

After reviewing the merge, refresh `upstream/` and bump `version` in `manifest.json`. The upstream manifest must go in as `upstream/manifest.json.orig`, never as a second `manifest.json`, because the marketplace rejects a repo with two plugin manifests.
