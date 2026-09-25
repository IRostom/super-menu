import QtQuick
import Quickshell
import Quickshell.Io
import "EmojiSearch.js" as EmojiSearch

// Emojis for the Search Emojis view and the `:` query plugin. The list is
// the first-party omarchy.emojis plugin's own data file, read in place, so it
// follows Omarchy's releases. Nothing here writes it.
QtObject {
  id: source

  readonly property string path: Quickshell.env("OMARCHY_PATH") + "/shell/plugins/emojis/emojis.json"

  // [{ e, k, name, category, index }] in file order.
  property var emojis: []
  property bool failed: false

  function search(query, limit) {
    return EmojiSearch.search(source.emojis, query, limit)
  }

  property FileView file: FileView {
    path: source.path
    printErrors: false
    onLoaded: {
      source.emojis = EmojiSearch.parse(text())
      source.failed = source.emojis.length === 0
    }
    onLoadFailed: {
      source.emojis = []
      source.failed = true
    }
  }
}
