.pragma library

// Emoji data for the Search Emojis view and the `:` query plugin: parsing,
// categories, ranking, and the grid layout the view draws.
//
// The data is omarchy.emojis' own emojis.json, read from $OMARCHY_PATH at
// runtime, so the list follows Omarchy. Each entry is { e, k }: the emoji and
// a keyword string. It carries no categories, but it is in Unicode's
// emoji-test.txt order, so each category starts at a known emoji. This file
// is pure JavaScript so it can be exercised with node.

// First emoji of each category, in file order. vicinae shows the same
// sections from its own tables.
var CATEGORIES = [
  { first: "😀", label: "Smileys & Emotion" },
  { first: "👋", label: "People & Body" },
  { first: "🐵", label: "Animals & Nature" },
  { first: "🍇", label: "Food & Drink" },
  { first: "🌍", label: "Travel & Places" },
  { first: "🎃", label: "Activities" },
  { first: "👓", label: "Objects" },
  { first: "🏧", label: "Symbols" },
  { first: "🏁", label: "Flags" }
]

// [{ e, k, name, category, index }]
function parse(raw) {
  var data = []
  try { data = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!Array.isArray(data)) return []

  var out = []
  var category = CATEGORIES[0].label
  var next = 1
  for (var i = 0; i < data.length; i++) {
    var item = data[i]
    if (!item || !item.e) continue
    var e = String(item.e)
    if (next < CATEGORIES.length && e === CATEGORIES[next].first) category = CATEGORIES[next++].label
    var k = String(item.k || "")
    out.push({ e: e, k: k.toLowerCase(), name: displayName(k), category: category, index: out.length })
  }
  return out
}

// The keywords mix names with gemoji aliases: "heart_on_fire heart on fire",
// "sun with face summer sun_with_face". Drop an alias that repeats the words
// around it, and read the rest with spaces.
function displayName(k) {
  var tokens = String(k || "").trim().split(/\s+/)
  var plain = " " + tokens.filter(function(t) { return t.indexOf("_") < 0 }).join(" ") + " "
  var seen = {}
  var out = []
  for (var i = 0; i < tokens.length; i++) {
    var t = tokens[i]
    if (!t) continue
    if (t.indexOf("_") >= 0) {
      var spaced = t.replace(/_/g, " ")
      if (plain.indexOf(" " + spaced + " ") >= 0) continue
      t = spaced
    }
    if (seen[t]) continue
    seen[t] = true
    out.push(t)
  }
  return out.join(" ")
}

function words(text) {
  return String(text || "").toLowerCase().split(/[\s_]+/).filter(function(w) { return w.length > 0 })
}

// Every term has to match. Per term, a whole keyword beats a keyword prefix,
// which beats a match inside a word. Ties go to the entry whose match comes
// earlier in its keywords (❤️ "red heart" before 💗 "heartpulse growing
// heart"), then to the one with fewer keywords (🔥 "fire burn" before 🚒
// "fire engine"), then to file order.
function search(emojis, query, limit) {
  var terms = words(query)
  var list = Array.isArray(emojis) ? emojis : []
  if (terms.length === 0) return list.slice(0, limit === undefined ? list.length : limit)

  var scored = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    var itemWords = words(item.k)
    var score = 0
    var position = 0
    for (var t = 0; t < terms.length && score >= 0; t++) {
      var term = terms[t]
      var best = -1
      var at = itemWords.length
      for (var w = 0; w < itemWords.length; w++) {
        if (itemWords[w] === term) { best = 0; at = w; break }
        if (best < 0 && itemWords[w].indexOf(term) === 0) { best = 1; at = w }
      }
      if (best < 0 && item.k.indexOf(term) >= 0) best = 2
      score = best < 0 ? -1 : score + best
      position += at
    }
    if (score >= 0) scored.push({ item: item, score: score, position: position, size: itemWords.length })
  }

  scored.sort(function(a, b) {
    if (a.score !== b.score) return a.score - b.score
    if (a.position !== b.position) return a.position - b.position
    if (a.size !== b.size) return a.size - b.size
    return a.item.index - b.item.index
  })

  var max = limit === undefined ? scored.length : Math.max(0, limit)
  var out = []
  for (var j = 0; j < scored.length && out.length < max; j++) out.push(scored[j].item)
  return out
}

// With no query: Pinned, Recently Used, then one section per category.
// `pinned` and `recents` are emoji strings; ones the data no longer has are
// skipped. Empty sections are dropped. [{ label, items }]
function sections(emojis, pinned, recents) {
  var list = Array.isArray(emojis) ? emojis : []
  var byEmoji = {}
  for (var i = 0; i < list.length; i++) byEmoji[list[i].e] = list[i]

  var lookup = function(values) {
    var out = []
    for (var j = 0; j < (values || []).length; j++) {
      var found = byEmoji[values[j]]
      if (found) out.push(found)
    }
    return out
  }

  var out = [
    { label: "Pinned", items: lookup(pinned) },
    { label: "Recently Used", items: lookup(recents) }
  ]
  var current = null
  for (var k = 0; k < list.length; k++) {
    if (!current || current.label !== list[k].category) {
      current = { label: list[k].category, items: [] }
      out.push(current)
    }
    current.items.push(list[k])
  }
  return out.filter(function(s) { return s.items.length > 0 })
}

// The grid, as the lines the view draws: a header line per section, then
// its emojis `columns` to a line. Cells are numbered across the whole grid,
// which is their row index in the flat model.
// [{ header } | { start, count, glyphs }]
function lines(sectionList, columns) {
  var cols = Math.max(1, columns | 0)
  var out = []
  var start = 0
  for (var s = 0; s < sectionList.length; s++) {
    var items = sectionList[s].items
    if (sectionList[s].label) out.push({ header: sectionList[s].label })
    for (var i = 0; i < items.length; i += cols) {
      var glyphs = []
      for (var j = i; j < Math.min(i + cols, items.length); j++) glyphs.push(items[j].e)
      out.push({ start: start + i, count: glyphs.length, glyphs: glyphs })
    }
    start += items.length
  }
  return out
}

// The line that holds cell `index`, or -1.
function lineOf(gridLines, index) {
  for (var i = 0; i < gridLines.length; i++) {
    var line = gridLines[i]
    if (line.header !== undefined) continue
    if (index >= line.start && index < line.start + line.count) return i
  }
  return -1
}

// Up or down `delta` lines, keeping the column. A shorter line (the last one
// of a section) takes its last cell. Past either end the cursor goes as far
// as it can.
function moveVertical(gridLines, index, delta) {
  var at = lineOf(gridLines, index)
  if (at < 0 || delta === 0) return index
  var column = index - gridLines[at].start
  var step = delta < 0 ? -1 : 1
  var remaining = Math.abs(delta)
  var target = at
  for (var i = at + step; i >= 0 && i < gridLines.length && remaining > 0; i += step) {
    if (gridLines[i].header !== undefined) continue
    target = i
    remaining--
  }
  var line = gridLines[target]
  return line.start + Math.min(column, line.count - 1)
}

// "U+1F44D", or "U+2764 U+FE0F U+200D U+1F525" for a sequence.
function codepoint(e) {
  var out = []
  var text = String(e || "")
  for (var i = 0; i < text.length; i++) {
    var cp = text.codePointAt(i)
    if (cp > 0xffff) i++
    var hex = cp.toString(16).toUpperCase()
    while (hex.length < 4) hex = "0" + hex
    out.push("U+" + hex)
  }
  return out.join(" ")
}
