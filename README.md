# irostom.menu

A clone of Omarchy's built-in menu (`omarchy.menu`) that can answer the query
you type, not just search for it.

Everything the stock menu does still works — the JSONC menu tree, installed
apps, scored search, `provider` submenus, `when:`/`checked:` guards, and the
dmenu mode other Omarchy scripts rely on. On top of that it adds **query
plugins**: small extensions that turn the typed text into a result row pinned
above the search results.

```
2^10 + 5*3        ->  3072
100 usd to eur    ->  €86.45
100 km to miles   ->  62.137119 mi
```

Enter copies the result. The clipboard gets full precision even though the row
shows a rounded value.

## Installing

The clone declares `omarchy.clonedFrom: "omarchy.menu"`, and the shell routes
every call aimed at the built-in id to the enabled clone
(`PluginRegistry.resolveEnabledId()`). So **SUPER+Space needs no Hyprland
change** — `omarchy-menu toggle` and every dmenu caller reach this plugin
automatically once it is enabled.

```bash
ln -s ~/Work/omarchy-dotfiles/plugins/irostom.menu ~/.config/omarchy/plugins/irostom.menu
omarchy-shell shell rescanPlugins
omarchy plugin enable irostom.menu
```

Requires `qalc` (libqalculate) for the built-in calculator, and `wl-copy` for
copying results. Both ship with Omarchy.

## Writing a query plugin

Drop a `.js` file in `~/.config/omarchy/menu-plugins/`. It is read at startup
and on `omarchy menu refresh`. See `examples/` for working copies.

```js
// ~/.config/omarchy/menu-plugins/uuid.js
descriptor = {
  id: "uuid",
  title: "Generate UUID",
  icon: "󰄿",
  kind: "js",                       // runs in the shell's JS engine, no fork
  trigger: { keywords: ["uuid"] },  // "uuid" or "uuid 5"
  rows: function (match) {
    return [{ value: crypto.randomUUID(), detail: "UUID v4" }]
  }
}
```

A plugin that needs the network, a secret, or a real runtime uses `kind:
"command"` instead — any executable, in any language:

```js
descriptor = {
  id: "weather",
  title: "Weather",
  kind: "command",
  trigger: { keywords: ["weather", "wx"] },
  argv: ["/home/you/.config/omarchy/menu-plugins/weather.sh"],
  queryVia: "env",     // arrives as $OMARCHY_QUERY
  timeout: 2000
}
```

The command prints one JSON object (or an array) on its last non-empty line,
and exits 0. Printing nothing means "no answer" and is not an error.

### Descriptor fields

| Field | Default | Meaning |
|---|---|---|
| `id` | — | Required. A user plugin reusing a built-in id **replaces** it. |
| `title` | `id` | Row subtitle when a result gives no `detail`. |
| `icon` / `iconFont` | `""` | Nerd Font glyph for the icon column. |
| `priority` | `50` | Higher sorts first. An explicit trigger adds 1000. |
| `kind` | `"command"` | `"js"` (in-engine, synchronous) or `"command"`. |
| `trigger` | — | See below. |
| `maxRows` | `1` | Cap on rows this plugin may contribute. |
| `debounce` | `140` | ms of quiet before a `command` runs. Ignored for `js`. |
| `timeout` | `1500` | ms before the process is SIGKILLed. |
| `stealsFocus` | `"explicit"` | `true`, `false`, or `"explicit"` — see below. |
| `argv` | `[]` | `command` only. `{{query}}` is replaced as one whole element. |
| `queryVia` | `"env"` | `"env"` (`$OMARCHY_QUERY`), `"argv"`, or `"stdin"`. |
| `acceptExitCodes` | `[0]` | Any other exit code yields no rows. |

### Triggers

Triggers are checked in this order, and the first that fits wins:

- `prefixes: ["="]` — the prefix is **stripped** from the text the plugin
  receives, and the match counts as explicit.
- `keywords: ["uuid"]` — matches the first word; the rest is the text. Also
  explicit.
- `minLength` (default 2), then `match(query)` (a function returning
  `false` / `true` / `{text, explicit}`), then `gate(query)` (a predicate),
  then `regex` + `regexFlags` (strings, not literals).

A gate should be cheap and strict. `command` plugins fork a process, and a
loose trigger costs one on every keystroke.

### Result rows

```js
{
  value:  "€86.45",          // the big line; required
  detail: "= 100 usd to eur",// small line under it
  copy:   "€86.45283998",    // what Enter copies; defaults to value
  action: "",                // shell string to run instead of copying
  actionArgv: [],            // preferred: argv, run without a shell
  icon:   ""                 // defaults to the descriptor's icon
}
```

Enter runs `actionArgv` if set, else `action`, else copies `copy`.

### Focus

An answer that arrives while you are still typing must not steal the Enter key
from the search result you were aiming at. That is what `stealsFocus` governs,
and the default `"explicit"` means the answer takes the cursor only when it was
explicitly asked for — `=2+2` puts Enter on the answer, plain `2+2` leaves it on
the first search result. Moving the cursor yourself always wins: the selected
row is restored by identity across a rebuild, so a late answer cannot move it.

### Failure handling

A plugin that throws, times out, or returns an unusable exit code three times in
a row is disabled for the rest of the shell session, with a warning in the log.
A `kind: "js"` plugin runs on the UI thread — an infinite loop there freezes the
menu, so put anything slow in a `command` plugin.

## The built-in calculator

`query-plugins/calc.sh` wraps `qalc`, covering arithmetic, unit conversion and
currency in one call. Two details worth knowing:

**The gate is not optional.** `qalc` answers almost anything, including ordinary
menu words, and with a successful exit status:

```
qalc -t theme  ->  30.93650008 kg·m³/ms²   (exit 0)
qalc -t font   ->  1E−24 B·t               (exit 0)
```

So exit status can never separate a real answer from noise. `QueryPlugins.js`
gates on an allowlist instead: a query is only forwarded if every alphabetic
token in it is a known unit or currency. Anything else needs the `=` prefix.

**It never touches your qalc config.** `qalc` rewrites its config on exit
(`save_mode_on_exit=1`), so the script points `XDG_CONFIG_HOME` at a private
directory under `~/.local/state/omarchy/menu-qalc`. Exchange rates still come
from the shared cache under `XDG_DATA_HOME`, so nothing is duplicated.

Rates are **never** refreshed from the keystroke path — `-s "upxrates 0"`
guarantees it, because the qalc default is "ask", which can block on the
network. To refresh them by hand:

```bash
qalc -e -t 1
```

## Files

| File | Role |
|---|---|
| `Menu.qml` | Cloned menu UI. Query-plugin hooks are marked in the source. |
| `MenuModel.js` | Cloned model helpers, plus the `copyText`/`actionArgv` roles. |
| `QueryPlugins.js` | Registry, trigger gate, row normalization, JS compilation. |
| `QueryBuiltins.js` | Descriptors for the shipped plugins. |
| `query-plugins/calc.sh` | The calculator/converter. |
| `AppLibrary.qml`, `AppSearch.js` | Verbatim copies of the shell's own — see below. |
| `examples/` | Sample query plugins. Not loaded; copy them to use them. |
| `upstream/` | Pristine originals for 3-way merges on Omarchy updates. |

### Why the app library is vendored

The shell hands a scoped `appLibrary` to any plugin declaring `kind: "menu"`,
but it does not survive for a *cloned* menu. `shell.qml`'s `prunePluginApis()`
destroys a third-party plugin's scoped APIs whenever `isEnabled()` reads false,
which it transiently does while `shell.json` is being re-applied — and nothing
ever re-injects them. `isEnabled()` short-circuits to `true` for first-party
plugins, so only clones are affected: the built-in menu's Apps list works while
an identical clone's is empty.

So this plugin owns its app library instead of borrowing one, the same way
`irostom.logimouse` owns its Solaar service rather than going through the
shell's service bridge. `AppLibrary.qml` and `AppSearch.js` are unmodified
copies; they reach everything they need through `$OMARCHY_PATH` and the
`omarchy-shell` CLI, so they run fine outside the shell tree.

## Diagnostics

```bash
omarchy-shell shell call irostom.menu selftest '{"query":"100 usd to eur"}'
```

Reports which plugins loaded, whether the engine allows runtime JS compilation,
how many apps are visible, and which plugins match a given query — without
opening the menu.

## Keeping up with upstream

`upstream/` holds the files as they shipped, with the Omarchy version they came
from. When Omarchy updates the menu:

```bash
U=/usr/share/omarchy/shell/plugins/menu
diff3 -m Menu.qml upstream/Menu.qml $U/Menu.qml > Menu.qml.merged
```

Review, replace, then refresh `upstream/` and bump `version` in `manifest.json`.
