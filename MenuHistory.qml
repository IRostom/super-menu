import QtQuick
import Quickshell
import Quickshell.Io

// Pinned favorites and recently launched rows, for the root view's
// Favorites and Suggestions sections, and the Search Emojis view's Pinned and
// Recently Used emojis. Stored as item ids and emoji strings in
// $XDG_STATE_HOME/omarchy/menu-history.json -- machine state, not config, so
// it lives outside ~/.config and never ends up in a dotfiles repo.
QtObject {
  id: history

  readonly property string path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy/menu-history.json"
  readonly property int maxRecents: 20

  property var favorites: []
  // Newest first: [{ id, at }] with `at` in ms since the epoch.
  property var recents: []

  readonly property int maxEmojiRecents: 32
  property var emojiPins: []
  // Newest first, emoji strings.
  property var emojiRecents: []

  function isFavorite(id) {
    return history.favorites.indexOf(id) >= 0
  }

  function toggleFavorite(id) {
    if (!id) return
    history.favorites = history.isFavorite(id)
      ? history.favorites.filter(function(f) { return f !== id })
      : history.favorites.concat([id])
    history.save()
  }

  function recordLaunch(id) {
    if (!id) return
    var next = [{ id: id, at: Date.now() }]
    for (var i = 0; i < history.recents.length && next.length < history.maxRecents; i++) {
      if (history.recents[i].id !== id) next.push(history.recents[i])
    }
    history.recents = next
    history.save()
  }

  function forgetRecent(id) {
    history.recents = history.recents.filter(function(r) { return r.id !== id })
    history.save()
  }

  function recentIds() {
    return history.recents.map(function(r) { return r.id })
  }

  function isEmojiPinned(emoji) {
    return history.emojiPins.indexOf(emoji) >= 0
  }

  function toggleEmojiPin(emoji) {
    if (!emoji) return
    history.emojiPins = history.isEmojiPinned(emoji)
      ? history.emojiPins.filter(function(e) { return e !== emoji })
      : history.emojiPins.concat([emoji])
    history.save()
  }

  function recordEmoji(emoji) {
    if (!emoji) return
    history.emojiRecents = [emoji].concat(history.emojiRecents.filter(function(e) { return e !== emoji }))
      .slice(0, history.maxEmojiRecents)
    history.save()
  }

  function forgetEmoji(emoji) {
    history.emojiRecents = history.emojiRecents.filter(function(e) { return e !== emoji })
    history.save()
  }

  function load(raw) {
    var data = ({})
    try { data = JSON.parse(raw || "{}") } catch (e) { data = ({}) }
    history.favorites = Array.isArray(data.favorites)
      ? data.favorites.filter(function(f) { return typeof f === "string" && f.length > 0 })
      : []
    history.recents = Array.isArray(data.recents)
      ? data.recents.filter(function(r) { return r && typeof r.id === "string" && r.id.length > 0 })
      : []
    history.emojiPins = history.strings(data.emojiPins)
    history.emojiRecents = history.strings(data.emojiRecents)
  }

  function strings(value) {
    return Array.isArray(value) ? value.filter(function(v) { return typeof v === "string" && v.length > 0 }) : []
  }

  function save() {
    file.setText(JSON.stringify({
      favorites: history.favorites,
      recents: history.recents,
      emojiPins: history.emojiPins,
      emojiRecents: history.emojiRecents
    }, null, 2) + "\n")
  }

  property FileView file: FileView {
    path: history.path
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: history.load(text())
    // A missing or deleted file means no history, not "keep what we had";
    // otherwise the next save would write the stale lists back.
    onLoadFailed: history.load("")
  }
}
