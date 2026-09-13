// Query plugins: turn the typed text itself into answer rows.
//
// The menu's own search asks "which of my rows match this text". A query
// plugin asks the opposite: "what does this text mean". Typing `100 usd to eur`
// has no matching menu row and never will, but it does have an answer.
//
// Everything here is pure JavaScript so it can be reasoned about (and tested
// with node) without a running shell. Menu.qml owns the processes and the
// model; this file owns what to run and what the result means.
//
// The most important function in the file is the gate. qalc will answer almost
// anything you hand it, including ordinary menu words:
//
//     qalc -t theme  ->  30.93650008 kg.m3/ms2   (exit status 0)
//     qalc -t font   ->  1E-24 B.t               (exit status 0)
//
// Exit status cannot tell those from `2+2`, so the gate has to. It is an
// allowlist: a query reaches the calculator only if every alphabetic token in
// it is a unit or a currency we recognize. Anything else needs the `=` prefix.

.pragma library

// ---------------------------------------------------------------- tables ---

var CURRENCIES = ("USD EUR GBP JPY CHF SEK NOK DKK ISK PLN CZK HUF RON BGN "
  + "RUB UAH TRY ILS EGP AED SAR QAR KWD BHD OMR JOD MAD TND DZD "
  + "CAD AUD NZD MXN BRL ARS CLP COP PEN UYU "
  + "CNY HKD TWD SGD KRW INR PKR BDT LKR NPR IDR MYR THB VND PHP "
  + "ZAR NGN KES GHS TZS UGX ETB "
  + "BTC ETH XAU XAG").split(" ")

var CURRENCY_SYMBOLS = {
  "$": "USD",
  "€": "EUR",
  "£": "GBP",
  "¥": "JPY",
  "₿": "BTC",
  "₹": "INR",
  "₩": "KRW",
  "₽": "RUB",
  "₪": "ILS",
  "₺": "TRY"
}

// Curated on purpose. A wider list would start swallowing English words --
// `at` is a unit (technical atmosphere), `in` is inches, `t` is tonnes -- and
// every one of those is also something a person types into a launcher.
var UNITS = ("km m cm mm um nm mi ft yd nmi au ly pc "
  + "kg g mg ug t lb oz st ton tonne "
  + "l ml cl dl hl gal qt pt floz cup tbsp tsp "
  + "c f k celsius fahrenheit kelvin "
  + "s ms us ns min h hr d wk mo yr sec secs minute minutes hour hours "
  + "day days week weeks month months year years "
  + "b kb mb gb tb pb eb kib mib gib tib pib bit bits byte bytes "
  + "hz khz mhz ghz thz "
  + "kmh mph kn knot knots mps "
  + "j kj mj cal kcal wh kwh mwh ev btu "
  + "w kw mw hp "
  + "pa kpa mpa bar mbar psi atm torr mmhg "
  + "v mv kv a ma ka ohm ohms "
  + "n lbf dyn "
  + "rad deg grad arcmin arcsec "
  + "m2 m3 km2 ft2 ft3 acre ha sqft sqm "
  // Long forms, because people type them. `in` and `inch` are both here, but
  // only ever reached with a number in front of them (see looksLikeConversion).
  + "inch mile meter metre kilometer kilometre centimeter centimetre "
  + "millimeter millimetre micrometer nanometer yard foot feet "
  + "gram kilogram milligram pound ounce stone "
  + "liter litre milliliter millilitre gallon quart pint "
  + "degree radian gradian "
  + "second millisecond microsecond nanosecond "
  + "kilobyte megabyte gigabyte terabyte petabyte "
  + "hertz kilohertz megahertz gigahertz "
  + "joule kilojoule calorie kilocalorie watt kilowatt horsepower "
  + "pascal atmosphere volt ampere newton "
  + "mph kph knot lightyear").split(" ")

function toSet(list) {
  var set = ({})
  for (var i = 0; i < list.length; i++) set[String(list[i]).toLowerCase()] = true
  return set
}

var CURRENCY_SET = toSet(CURRENCIES)
var UNIT_SET = toSet(UNITS)

function isCurrency(token) {
  return CURRENCY_SET[String(token || "").toLowerCase()] === true
}

function isUnit(token) {
  var t = String(token || "").toLowerCase()
  if (UNIT_SET[t] === true || CURRENCY_SET[t] === true) return true
  // Plurals, so the table does not have to carry both halves of every pair.
  // Tried last so a real unit ending in `s` (`s`, `secs`, `bits`) still wins
  // on its own entry.
  if (t.length > 2 && t.charAt(t.length - 1) === "s" && UNIT_SET[t.slice(0, -1)] === true) return true
  if (t.length > 3 && t.slice(-2) === "es" && UNIT_SET[t.slice(0, -2)] === true) return true
  return false
}

function symbolCurrency(ch) {
  return CURRENCY_SYMBOLS[ch] || ""
}

// ----------------------------------------------------------------- gates ---

// Scientific notation hides a letter inside a number (`1e3`), which would trip
// the "no stray letters" test below. Fold the exponent marker to a character
// that cannot appear in real input, test, and never show the folded result.
var SCI = String.fromCharCode(1)

function foldSci(q) {
  return String(q || "").replace(/(\d)[eE]([-+]?\d)/g, "$1" + SCI + "$2")
}

var MATH_CHARS = new RegExp("^[\\s0-9" + SCI + "+\\-*/^%().,!]+$")
var HAS_DIGIT = /[0-9]/
// An operator with operands on both sides. `5+` must not qualify: qalc
// silently answers `5`, which is just the question read back.
var BINARY_OP = new RegExp("[0-9).]\\s*(?:\\*\\*|[-+*/^%])\\s*[-+(.\\s" + SCI + "0-9]*[0-9(.]")
var BARE_NUM = new RegExp("^[\\s0-9.,()" + SCI + "]+$")

function looksLikeMath(query) {
  var q = foldSci(query)
  if (!MATH_CHARS.test(q)) return false
  if (!HAS_DIGIT.test(q)) return false
  if (BARE_NUM.test(q)) return false
  return BINARY_OP.test(q)
}

var NUM_SRC = "[0-9][0-9.,]*(?:" + SCI + "[-+]?[0-9]+)?"
var UNIT_SRC = "[A-Za-z°µ][A-Za-z°µ0-9^/·]*"
var SYMS = "$€£¥₿₹₩₽₪₺"
var TO = "(?:to|in|as|->|→)"

// "100 km to miles", "20 c in f", "5 ft -> cm"
var CONV_RE = new RegExp("^\\s*(" + NUM_SRC + ")\\s*(" + UNIT_SRC + ")\\s+" + TO + "\\s+(" + UNIT_SRC + ")\\s*$", "i")
// "$100 to eur"
var SYM_CONV_RE = new RegExp("^\\s*([" + SYMS + "])\\s*(" + NUM_SRC + ")\\s+" + TO + "\\s+([A-Za-z]{3}|[" + SYMS + "])\\s*$", "i")
// "100 usd" -- a bare amount in a foreign currency is worth converting
var BARE_CUR_RE = new RegExp("^\\s*(" + NUM_SRC + ")\\s*([A-Za-z]{3})\\s*$", "i")
var BARE_SYM_RE = new RegExp("^\\s*([" + SYMS + "])\\s*(" + NUM_SRC + ")\\s*$")

function looksLikeConversion(query) {
  var q = foldSci(query)

  var m = CONV_RE.exec(q)
  if (m) return isUnit(m[2]) && isUnit(m[3])

  m = SYM_CONV_RE.exec(q)
  if (m) {
    var target = m[3]
    return !!symbolCurrency(m[1]) && (isCurrency(target) || !!symbolCurrency(target))
  }

  m = BARE_CUR_RE.exec(q)
  if (m) return isCurrency(m[2])

  m = BARE_SYM_RE.exec(q)
  if (m) return !!symbolCurrency(m[1])

  return false
}

function calcGate(query) {
  return looksLikeMath(query) || looksLikeConversion(query)
}

// ------------------------------------------------------------ descriptors ---

function normalizeDescriptor(raw, origin) {
  var d = raw || ({})
  var id = String(d.id || "").trim()
  if (!id) return null

  var trigger = d.trigger || ({})
  var prefixes = Array.isArray(trigger.prefixes) ? trigger.prefixes.slice() : []
  var keywords = []
  var rawKeywords = Array.isArray(trigger.keywords) ? trigger.keywords : []
  for (var i = 0; i < rawKeywords.length; i++) keywords.push(String(rawKeywords[i]).toLowerCase())

  var regex = null
  if (trigger.regex) {
    // A string, not a literal: a descriptor may arrive from JSON, and JSON
    // cannot carry a compiled RegExp.
    try {
      regex = new RegExp(String(trigger.regex), String(trigger.regexFlags || ""))
    } catch (e) {
      regex = null
    }
  }

  return {
    id: id,
    origin: origin || "builtin",
    title: String(d.title || id),
    icon: String(d.icon || ""),
    iconFont: String(d.iconFont || ""),
    priority: typeof d.priority === "number" ? d.priority : 50,
    kind: d.kind === "js" ? "js" : "command",
    minLength: typeof trigger.minLength === "number" ? trigger.minLength : 2,
    prefixes: prefixes,
    keywords: keywords,
    regex: regex,
    gate: typeof trigger.gate === "function" ? trigger.gate : null,
    match: typeof trigger.match === "function" ? trigger.match : null,
    rows: typeof d.rows === "function" ? d.rows : null,
    argv: Array.isArray(d.argv) ? d.argv.slice() : [],
    queryVia: (d.queryVia === "argv" || d.queryVia === "stdin") ? d.queryVia : "env",
    acceptExitCodes: Array.isArray(d.acceptExitCodes) ? d.acceptExitCodes.slice() : [0],
    debounce: typeof d.debounce === "number" ? d.debounce : 140,
    timeout: typeof d.timeout === "number" ? d.timeout : 1500,
    maxRows: typeof d.maxRows === "number" ? d.maxRows : 1,
    stealsFocus: d.stealsFocus === undefined ? "explicit" : d.stealsFocus,
    failures: 0,
    disabled: false
  }
}

// --------------------------------------------------------------- matching ---

// Returns null (no match) or { text, explicit }. `text` is what the plugin is
// actually asked about, which is not always what was typed: the `=` prefix is
// stripped because qalc reads a leading `=` as a comparison and answers
// `false` for `=2+2`.
function matchOne(plugin, query) {
  var trimmed = String(query || "").trim()
  if (!trimmed) return null

  for (var i = 0; i < plugin.prefixes.length; i++) {
    var p = plugin.prefixes[i]
    if (p && trimmed.indexOf(p) === 0) {
      var rest = trimmed.slice(p.length).trim()
      if (!rest) return null
      return { text: rest, explicit: true }
    }
  }

  if (plugin.keywords.length > 0) {
    var space = trimmed.indexOf(" ")
    var head = (space > 0 ? trimmed.slice(0, space) : trimmed).toLowerCase()
    if (plugin.keywords.indexOf(head) >= 0) {
      // The keyword on its own is a complete request ("uuid", "epoch"); the
      // plugin gets an empty text and decides what that means.
      var tail = space > 0 ? trimmed.slice(space + 1).trim() : ""
      return { text: tail, explicit: true }
    }
  }

  if (trimmed.length < plugin.minLength) return null

  if (plugin.match) {
    var custom = null
    try {
      custom = plugin.match(trimmed)
    } catch (e) {
      return null
    }
    if (!custom) return null
    if (custom === true) return { text: trimmed, explicit: false }
    return { text: String(custom.text || trimmed), explicit: !!custom.explicit }
  }

  if (plugin.gate) {
    var ok = false
    try {
      ok = !!plugin.gate(trimmed)
    } catch (e) {
      ok = false
    }
    return ok ? { text: trimmed, explicit: false } : null
  }

  if (plugin.regex && plugin.regex.test(trimmed)) return { text: trimmed, explicit: false }

  return null
}

function matchAll(plugins, query) {
  var out = []
  var list = Array.isArray(plugins) ? plugins : []

  for (var i = 0; i < list.length; i++) {
    var plugin = list[i]
    if (!plugin || plugin.disabled) continue
    var match = matchOne(plugin, query)
    if (!match) continue
    out.push({
      plugin: plugin,
      match: match,
      rank: plugin.priority + (match.explicit ? 1000 : 0),
      order: i
    })
  }

  out.sort(function (a, b) {
    if (a.rank !== b.rank) return b.rank - a.rank
    return a.order - b.order
  })

  return out
}

// Whether the first answer row may take the cursor. An answer that arrives
// while the user is mid-word must not steal the Enter key from the search
// result they were aiming at, so only an explicit request does.
function answerTakesFocus(plugin, match) {
  if (plugin.stealsFocus === true) return true
  if (plugin.stealsFocus === false) return false
  return !!(match && match.explicit)
}

// ------------------------------------------------------------------ rows ---

function str(v) {
  return (v === undefined || v === null) ? "" : String(v)
}

// Coerce whatever a plugin returned into rows the ListModel can take. Every
// row carries the same key set as MenuModel.displayRow(), because ListModel
// roles are fixed by the first append and the delegate declares them required.
function normalizeRows(rawRows, plugin, match) {
  var list = Array.isArray(rawRows) ? rawRows : (rawRows ? [rawRows] : [])
  var max = Math.max(0, plugin.maxRows)
  var rows = []

  for (var i = 0; i < list.length && rows.length < max; i++) {
    var r = list[i] || ({})
    var value = str(r.value !== undefined ? r.value : r.label)
    if (!value) continue

    var actionArgv = Array.isArray(r.actionArgv) ? r.actionArgv : []
    rows.push({
      itemId: "answer." + plugin.id + "." + i,
      kind: "answer",
      icon: str(r.icon) || plugin.icon,
      iconFont: str(r.iconFont) || plugin.iconFont,
      appIcon: "",
      appId: "",
      label: value,
      target: "",
      detail: str(r.detail) || plugin.title,
      path: "",
      childCount: 0,
      action: str(r.action),
      actionArgv: actionArgv.length > 0 ? JSON.stringify(actionArgv) : "",
      copyText: str(r.copy !== undefined ? r.copy : value),
      provider: plugin.id,
      score: -1,
      section: "answer"
    })
  }

  return rows
}

// Parse a command plugin's stdout. The last non-empty line is the payload,
// matching the convention the shell already uses for module JSON elsewhere.
function parseCommandOutput(text) {
  var lines = String(text || "").split("\n")
  for (var i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].trim()
    if (!line) continue
    try {
      return JSON.parse(line)
    } catch (e) {
      return null
    }
  }
  return null
}

function acceptsExit(plugin, code, status) {
  // A killed process leaves the exit code at 0, so status has to be checked
  // too -- the same trap the menu's own guard process documents.
  if (status !== 0) return false
  return plugin.acceptExitCodes.indexOf(code) >= 0
}

// ------------------------------------------------------------- js sources ---

// Whether this QML engine allows building a function from text at runtime.
// Qt's JavaScript host environment documents no restriction on it, but the
// probe costs nothing and decides whether user .js plugins can load at all.
function dynamicJsAvailable() {
  try {
    return (new Function("return 1 + 1"))() === 2
  } catch (e) {
    return false
  }
}

// A user plugin file is a script whose descriptor is either assigned to
// `descriptor` or exported on `module.exports`.
//
// `ctx` is in scope for the plugin: there is no __dirname here, and a command
// plugin has to name its helper script by absolute path, so it needs at least
// its own directory and $HOME.
function compileDescriptor(source, filename, ctx) {
  var body = "var module = { exports: {} };\nvar exports = module.exports;\nvar descriptor = null;\n"
    + String(source || "")
    + "\n;return (descriptor && descriptor.id) ? descriptor"
    + " : ((module.exports && module.exports.id) ? module.exports : null);"

  var factory = new Function("ctx", body)
  var raw = factory(ctx || ({}))
  if (!raw) throw new Error(String(filename || "plugin") + ": no descriptor returned")
  return raw
}
