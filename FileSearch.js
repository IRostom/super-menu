.pragma library

// File search for the Search Files view: which fd to run for a query, and
// how to rank what it prints.
//
// vicinae keeps a live SQLite index of the home directory for this. A
// launcher that opens for a few seconds at a time does not need one: fd walks
// $HOME in tens of milliseconds and is never stale. Menu.qml owns the process
// (debounce, watchdog, revision); this file is pure JavaScript so it can be
// exercised with node.

// Directories no one searches for files in. fd already skips hidden and
// gitignored paths, which covers most of vicinae's list (.cache, .cargo,
// .npm, .git, ...); these are the visible ones. A glob with a slash is
// anchored to the search root, which is $HOME.
var EXCLUDES = [
  "node_modules", "__pycache__", "venv", "__MACOSX", "lost+found",
  "anaconda3", "miniconda3", "miniforge3", "go/pkg", "snap",
  "GPUCache", "Code Cache", "CacheStorage", "Service Worker", "blob_storage",
  "DawnGraphiteCache", "DawnWebGPUCache", "ShaderCache", "GrShaderCache"
]

// fd stops after this many hits; ranking happens on what it returns.
var MAX_FD_RESULTS = 300
var MAX_ROWS = 50

var IMAGE_RE = /\.(png|jpe?g|webp|gif|bmp|tiff?|svg|avif)$/i

function words(query) {
  return String(query || "").trim().toLowerCase().split(/\s+/).filter(function(w) { return w.length > 0 })
}

// A query that names a location lists it instead of searching: vicinae's
// explicit-path mode. Relative paths (./, ../) mean nothing in a launcher
// with no working directory, so only absolute and home paths count.
function isPathQuery(query) {
  var q = String(query || "").trim()
  return q.charAt(0) === "/" || q === "~" || q.indexOf("~/") === 0
}

function expandHome(path, home) {
  var p = String(path || "").trim()
  if (p === "~") return home + "/"
  if (p.indexOf("~/") === 0) return home + p.substring(1)
  return p
}

function compressHome(path, home) {
  var p = String(path || "")
  if (home && (p === home || p.indexOf(home + "/") === 0)) return "~" + p.substring(home.length)
  return p
}

// "~/Work/sup" -> { dir: "/home/me/Work/", fragment: "sup" }
function pathQueryParts(query, home) {
  var expanded = expandHome(query, home)
  var slash = expanded.lastIndexOf("/")
  return { dir: expanded.substring(0, slash + 1), fragment: expanded.substring(slash + 1) }
}

// The characters fd's regex syntax (Rust's regex crate) gives a meaning to.
function escapeRegex(text) {
  return String(text).replace(/[\\.+*?()|\[\]{}^$#&\-~]/g, "\\$&")
}

// Every order of `list`: [a, b] -> [[a, b], [b, a]].
function permutations(list) {
  if (list.length <= 1) return [list]
  var out = []
  for (var i = 0; i < list.length; i++) {
    var rest = list.slice(0, i).concat(list.slice(i + 1))
    var tails = permutations(rest)
    for (var j = 0; j < tails.length; j++) out.push([list[i]].concat(tails[j]))
  }
  return out
}

// One word is matched against file names only, so `work` finds work.txt
// rather than everything under ~/Work. Several words have to be matched
// against the whole path, since `documents readme` means a readme inside
// Documents: fd gets a pattern that needs every word, in any order (the
// first three; rank() checks the rest). So fd's result cap only ever cuts
// real matches.
function searchArgv(query, home) {
  var list = words(query)
  if (list.length === 0) return []

  var argv = ["fd", "--color=never", "--absolute-path", "--ignore-case",
    "--max-results", String(MAX_FD_RESULTS)]
  for (var i = 0; i < EXCLUDES.length; i++) argv.push("--exclude", EXCLUDES[i])

  if (list.length === 1) return argv.concat(["--fixed-strings", "--", list[0], home])

  var orders = permutations(list.slice(0, 3).map(escapeRegex))
  var pattern = orders.map(function(order) { return order.join(".*") }).join("|")
  return argv.concat(["--full-path", "--", pattern, home])
}

// Lists one directory. An explicit path is a request to see what is there,
// so ignore files do not apply, and dotfiles show once the fragment asks
// for them.
function listArgv(query, home) {
  var parts = pathQueryParts(query, home)
  var argv = ["fd", "--color=never", "--absolute-path", "--no-ignore", "--ignore-case",
    "--max-depth", "1", "--max-results", "1000"]
  if (parts.fragment.charAt(0) === ".") argv.push("--hidden")
  // The fragment goes to fd, so a folder bigger than the cap still finds it.
  var pattern = parts.fragment ? "^" + escapeRegex(parts.fragment) : "."
  return argv.concat(["--", pattern, parts.dir])
}

function argvFor(query, home) {
  return isPathQuery(query) ? listArgv(query, home) : searchArgv(query, home)
}

// fd prints directories with a trailing slash.
function isDirectory(path) {
  return String(path).charAt(String(path).length - 1) === "/"
}

function stripSlash(path) {
  var p = String(path || "")
  return p.length > 1 && isDirectory(p) ? p.substring(0, p.length - 1) : p
}

function baseName(path) {
  var p = stripSlash(path)
  return p.substring(p.lastIndexOf("/") + 1)
}

function parentDir(path) {
  var p = stripSlash(path)
  var slash = p.lastIndexOf("/")
  return slash <= 0 ? "/" : p.substring(0, slash)
}

function isImagePath(path) {
  return IMAGE_RE.test(String(path || ""))
}

// Lower is better: a word is the whole name, the start of the name, inside
// the name, or only somewhere in the path. The best word decides, so the
// readme in `documents readme` ranks by its own name.
function tier(name, list) {
  var best = 3
  for (var i = 0; i < list.length; i++) {
    var word = list[i]
    if (name === word) return 0
    if (name.indexOf(word) === 0) best = Math.min(best, 1)
    else if (name.indexOf(word) >= 0) best = Math.min(best, 2)
  }
  return best
}

// Every query word must appear somewhere in the path. Ties go to the
// shallower path, then the shorter one, so ~/Documents/readme.md beats a
// readme four levels into a project.
function rank(paths, query) {
  var list = words(query)
  var scored = []

  for (var i = 0; i < paths.length; i++) {
    var raw = String(paths[i] || "").trim()
    if (!raw) continue
    var path = stripSlash(raw)
    var lower = path.toLowerCase()
    var name = baseName(lower)

    var all = true
    for (var w = 0; w < list.length; w++) {
      if (lower.indexOf(list[w]) < 0) { all = false; break }
    }
    if (!all) continue

    scored.push({
      path: path,
      dir: isDirectory(raw),
      tier: tier(name, list),
      depth: path.split("/").length,
      length: path.length
    })
  }

  scored.sort(function(a, b) {
    if (a.tier !== b.tier) return a.tier - b.tier
    if (a.depth !== b.depth) return a.depth - b.depth
    if (a.length !== b.length) return a.length - b.length
    return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0)
  })
  return scored.slice(0, MAX_ROWS)
}

// A directory listing keeps what starts with the fragment: folders first,
// then files, each alphabetical.
function listing(paths, query, home) {
  var fragment = pathQueryParts(query, home).fragment.toLowerCase()
  var out = []

  for (var i = 0; i < paths.length; i++) {
    var raw = String(paths[i] || "").trim()
    if (!raw) continue
    var path = stripSlash(raw)
    if (baseName(path).toLowerCase().indexOf(fragment) !== 0) continue
    out.push({ path: path, dir: isDirectory(raw) })
  }

  out.sort(function(a, b) {
    if (a.dir !== b.dir) return a.dir ? -1 : 1
    var an = baseName(a.path).toLowerCase()
    var bn = baseName(b.path).toLowerCase()
    return an < bn ? -1 : (an > bn ? 1 : 0)
  })
  return out.slice(0, 200)
}

function results(output, query, home) {
  var paths = String(output || "").split("\n")
  return isPathQuery(query) ? listing(paths, query, home) : rank(paths, query)
}
