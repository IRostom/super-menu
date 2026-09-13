// Unix timestamp <-> date. Copy to ~/.config/omarchy/menu-plugins/ to enable.
//
// Shows a `match()` trigger: a plain predicate is not enough here, because the
// plugin wants to accept two different shapes and tell them apart.

descriptor = {
  id: "epoch",
  title: "Unix time",
  icon: "󰔞",
  kind: "js",
  maxRows: 1,

  trigger: {
    keywords: ["epoch", "ts"],
    match: function (query) {
      // A bare 10- or 13-digit number is a timestamp and nothing else.
      if (/^\d{10}$/.test(query) || /^\d{13}$/.test(query)) return { text: query }
      return false
    }
  },

  rows: function (match) {
    var q = match.text.trim()

    if (q === "now" || q === "") {
      var now = Math.floor(Date.now() / 1000)
      return [{ value: String(now), detail: "current unix time" }]
    }

    if (/^\d{10}$/.test(q) || /^\d{13}$/.test(q)) {
      var ms = q.length === 10 ? Number(q) * 1000 : Number(q)
      var d = new Date(ms)
      if (isNaN(d.getTime())) return []
      return [{ value: d.toISOString(), detail: "from " + q, copy: d.toISOString() }]
    }

    return []
  }
}
