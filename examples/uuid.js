// Generate a UUID. Copy to ~/.config/omarchy/menu-plugins/ to enable.
//
// kind "js" runs inside the shell's JS engine: no process, no debounce, the
// row appears on the same frame you finish typing. Keep such plugins fast --
// they run on the UI thread.

descriptor = {
  id: "uuid",
  title: "Generate UUID",
  icon: "󰂧",
  kind: "js",
  trigger: { keywords: ["uuid", "guid"] },
  maxRows: 1,
  stealsFocus: true,

  rows: function (match) {
    // Qt's engine has no crypto.randomUUID(), so build a v4 by hand.
    var hex = "0123456789abcdef"
    var out = ""
    for (var i = 0; i < 36; i++) {
      if (i === 8 || i === 13 || i === 18 || i === 23) { out += "-"; continue }
      if (i === 14) { out += "4"; continue }
      var r = Math.floor(Math.random() * 16)
      if (i === 19) r = (r & 0x3) | 0x8
      out += hex.charAt(r)
    }
    return [{ value: out, detail: "UUID v4 — Enter to copy" }]
  }
}
