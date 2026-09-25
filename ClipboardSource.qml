import QtQuick
import Quickshell
import Quickshell.Io
import "ClipboardHistory.js" as ClipboardHistory

// Clipboard history for the Clipboard History view. The first-party
// omarchy.clipboard plugin captures the clipboard (wl-paste --watch) into this
// file and owns it; this only reads it, so there is one capture process, not
// two. The omarchy-clipboard-* helpers act on an entry by its index in the
// same file. ClipboardHistory.js is a verbatim copy of that plugin's own
// model (see upstream/).
QtObject {
  id: source

  // Not $XDG_STATE_HOME: the plugin and the helpers all hard-code this path.
  readonly property string path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
  readonly property int maxRows: 100

  // Newest first, as the plugin stores it.
  property var history: []

  // [{ entryType, fullText, previewText, previewImage, path, mime, index }]
  function displayRows(query) {
    return ClipboardHistory.displayRows(source.history, query, source.maxRows)
  }

  function entry(index) {
    return index >= 0 && index < source.history.length ? source.history[index] : null
  }

  // What identifies an entry across captures. Its index does not: every new
  // copy shifts all of them down by one.
  function keyAt(index) {
    return ClipboardHistory.entryKey(source.entry(index))
  }

  // The one write. omarchy.clipboard reloads the file when it changes, so the
  // entry leaves its picker too. A capture landing in the same instant can
  // lose one of the two writes; both are atomic, so the file stays valid.
  function removeKey(key) {
    for (var i = 0; i < source.history.length; i++) {
      if (ClipboardHistory.entryKey(source.history[i]) !== key) continue
      source.history = ClipboardHistory.removeEntryAt(source.history, i)
      file.setText(JSON.stringify(source.history, null, 2) + "\n")
      return true
    }
    return false
  }

  property FileView file: FileView {
    path: source.path
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: source.history = ClipboardHistory.parseHistory(text())
    onLoadFailed: source.history = []
  }
}
