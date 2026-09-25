.pragma library

// What can be done to a row. actionsFor() lists a row's actions, primary
// first; Menu.qml runs them by id. The footer shows the primary one and the
// action panel (Ctrl+B) lists them all.
//
// Shortcuts are specs like "ctrl+shift+c". They work from the search field
// without opening the panel, and the panel draws them as keycaps.

// Qt key and modifier values. Qt.Key_* is not reliably reachable from a
// .pragma library, and these values are part of Qt's stable ABI. Letter and
// digit keys use their ASCII code.
var KEY = {
  "return": 0x01000004, enter: 0x01000005, "delete": 0x01000007,
  backspace: 0x01000003, escape: 0x01000000
}
var MOD = { shift: 0x02000000, ctrl: 0x04000000, alt: 0x08000000, meta: 0x10000000 }
var MOD_MASK = MOD.shift | MOD.ctrl | MOD.alt | MOD.meta
var CAP = { ctrl: "Ctrl", shift: "⇧", alt: "Alt", meta: "Super", "return": "↵", "delete": "Del", backspace: "⌫", escape: "Esc" }

// Toggles the panel. Ctrl+K as well, because that is Raycast's binding.
var TOGGLE_PANEL = ["ctrl+b", "ctrl+k"]

function parse(spec) {
  var parts = String(spec).toLowerCase().split("+")
  var key = parts.pop()
  var mods = 0
  for (var i = 0; i < parts.length; i++) mods |= (MOD[parts[i]] || 0)
  var code = KEY[key] !== undefined ? KEY[key] : key.toUpperCase().charCodeAt(0)
  return { mods: mods, code: code }
}

function matches(event, spec) {
  if (!spec) return false
  var want = parse(spec)
  var code = event.key === KEY.enter ? KEY["return"] : event.key
  return code === want.code && (event.modifiers & MOD_MASK) === want.mods
}

function matchesAny(event, specs) {
  for (var i = 0; i < specs.length; i++) if (matches(event, specs[i])) return true
  return false
}

// "ctrl+shift+c" -> ["Ctrl", "⇧", "C"]
function keycaps(spec) {
  if (!spec) return []
  return String(spec).toLowerCase().split("+").map(function(part) {
    return CAP[part] || part.toUpperCase()
  })
}

// ctx: { isFavorite(id), inSuggestions, canUninstall, detailsShown }
// Clipboard and file rows are not menu items, so they cannot be pinned.
function actionsFor(row, ctx) {
  if (!row) return []
  var list = []
  var pinnable = row.kind === "app" || row.kind === "action" || row.kind === "menu" || row.kind === "link"

  if (row.kind === "app") list.push({ id: "open", title: "Open Application", icon: "󰏌", keys: "return" })
  else if (row.kind === "action") list.push({ id: "open", title: "Run Command", icon: "󰐊", keys: "return" })
  else if (row.kind === "menu" || row.kind === "link") list.push({ id: "open", title: "Open Menu", icon: "󰍜", keys: "return" })
  else if (row.kind === "answer") {
    list.push(row.action || row.actionArgv
      ? { id: "open", title: "Run", icon: "󰐊", keys: "return" }
      : { id: "open", title: "Copy Answer", icon: "󰆏", keys: "return" })
    if (row.action || row.actionArgv) list.push({ id: "copy", title: "Copy Answer", icon: "󰆏", keys: "ctrl+shift+c", text: row.copyText || row.label })
  }
  else if (row.kind === "dmenu") list.push({ id: "open", title: "Select", icon: "󰄬", keys: "return" })
  else if (row.kind === "clip") {
    list.push({ id: "open", title: "Paste", icon: "󰆒", keys: "return" })
    list.push({ id: "copy-clip", title: "Copy to Clipboard", icon: "󰆏", keys: "ctrl+shift+c" })
    list.push({ id: "open-clip", title: "Open", icon: "󰏌", keys: "ctrl+o" })
    list.push({ id: "details", title: ctx.detailsShown ? "Hide Details" : "Show Details", icon: "󰋼", keys: "ctrl+d" })
    list.push({ id: "remove", title: "Remove from History", icon: "󰆴", keys: "delete", danger: true })
    return list
  }
  else if (row.kind === "file") {
    var folder = row.mime === "inode/directory"
    list.push({ id: "open", title: folder ? "Open Folder" : "Open File", icon: "󰏌", keys: "return" })
    list.push({ id: "reveal", title: "Show in Folder", icon: "󰉋", keys: "ctrl+o" })
    list.push({ id: "details", title: ctx.detailsShown ? "Hide Details" : "Show Details", icon: "󰋼", keys: "ctrl+d" })
    list.push({ id: "copy", title: "Copy Path", icon: "󰆏", keys: "ctrl+shift+c", text: row.filePath })
    list.push({ id: "copy-file", title: "Copy File", icon: "󰈔", keys: "ctrl+alt+c" })
    return list
  }

  if (pinnable) {
    var pinned = ctx.isFavorite(row.itemId)
    list.push({ id: "favorite", title: pinned ? "Remove from Favorites" : "Add to Favorites", icon: pinned ? "󰓒" : "󰓎", keys: "ctrl+shift+f" })
  }
  if (row.kind === "app") list.push({ id: "details", title: ctx.detailsShown ? "Hide Details" : "Show Details", icon: "󰋼", keys: "ctrl+d" })
  if (ctx.inSuggestions) list.push({ id: "forget", title: "Remove from Suggestions", icon: "󰜺", keys: "" })

  if (row.kind === "app") list.push({ id: "copy", title: "Copy Desktop ID", icon: "󰆏", keys: "ctrl+shift+c", text: row.appId })
  else if (row.kind === "action" && row.action) list.push({ id: "copy", title: "Copy Command", icon: "󰆏", keys: "ctrl+shift+c", text: row.action })

  if (row.kind === "app" && ctx.canUninstall) list.push({ id: "uninstall", title: "Uninstall…", icon: "󰆴", keys: "delete", danger: true })

  return list
}

// The action a key press triggers from the search field, or null. Enter is
// left to the list's own handling, so it is never matched here.
function forShortcut(actions, event) {
  for (var i = 0; i < actions.length; i++) {
    var a = actions[i]
    if (a.id === "open" || !a.keys) continue
    if (matches(event, a.keys)) return a
  }
  return null
}
