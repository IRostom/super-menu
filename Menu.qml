import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "MenuModel.js" as MenuModel
import "QueryPlugins.js" as QueryPlugins
import "QueryBuiltins.js" as QueryBuiltins
import "Sections.js" as Sections
import "Actions.js" as Actions
import "FileSearch.js" as FileSearch
import "EmojiSearch.js" as EmojiSearch
import "launcher"

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Plugin lifecycle hooks. The host calls open(payloadJson) after
  // `omarchy-shell shell summon omarchy.menu ...` and close() when hidden.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function refresh() {
    defaultMenuFile.reload()
    userMenuFile.reload()
    root.loadAnswerPlugins()
    return "ok"
  }

  // Reports what the query-plugin layer thinks of a query, so the gate and
  // the plugin list can be checked without opening the menu:
  //   omarchy-shell shell call io.github.irostom.super-menu selftest '{"query":"2+2"}'
  function selftest(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    var ids = []
    for (var i = 0; i < root.answerPlugins.length; i++)
      ids.push(root.answerPlugins[i].id + (root.answerPlugins[i].disabled ? "(off)" : ""))

    var query = String(payload.query || "")
    var matched = []
    var matches = QueryPlugins.matchAll(root.answerPlugins, query)
    for (var j = 0; j < matches.length; j++)
      matched.push(matches[j].plugin.id + ":" + matches[j].match.text + (matches[j].match.explicit ? ":explicit" : ""))

    return JSON.stringify({
      dynamicJs: QueryPlugins.dynamicJsAvailable(),
      hostAppLibrary: !!(root.shell && root.shell.appLibrary),
      appCount: root.appLibrary ? root.appLibrary.sortedEntries("").length : -1,
      pluginDir: root.pluginDir,
      plugins: ids,
      query: query,
      matches: matched,
      clipboardEntries: clipboardSource.history.length,
      emojiCount: emojiSource.emojis.length,
      emojiMatches: emojiSource.search(query.replace(/^:/, ""), 5).map(function(e) { return e.e + " " + e.name }),
      fileSearchArgv: FileSearch.argvFor(query, root.homeDir)
    })
  }

  function ping() { return "ok" }

  property alias fontFamily: menuAppearance.fontFamily
  // JSONC menu definitions. The shell parses both at startup and merges
  // the user file on top of the defaults, so the keybind → IPC → visible
  // path doesn't have to shell out to bash + jq on every open.
  property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property bool opened: false
  property alias mode: menuState.mode
  property alias dmenuActive: menuState.dmenuActive
  property alias dmenuPrompt: menuState.dmenuPrompt
  property var dmenuOptions: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property bool rowsLoaded: false
  property alias activeMenu: menuState.activeMenu
  property alias filterText: menuState.filterText
  property alias selectedIndex: menuState.selectedIndex
  property alias cursorActive: menuState.cursorActive
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property alias navStack: menuState.navStack
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  // --- query plugins -------------------------------------------------
  // Answer rows are computed from the typed text rather than matched against
  // the menu tree, and are pinned above the search results. See
  // QueryPlugins.js for the gate that decides when a query has an answer.
  property var answerPlugins: []
  property alias answerRows: menuState.answerRows
  property int answerRevision: 0
  property var answerQueue: []
  property bool answerFocusable: false
  // Distinguishes "the cursor is at 0 because the user is typing" from "the
  // user deliberately moved it". cursorActive cannot: setFilter() sets it true
  // on every keystroke.
  property bool cursorMoved: false
  property alias answerRowHeight: menuAppearance.answerRowHeight
  readonly property string userPluginDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/menu-plugins"
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = decodeURIComponent(url.substring(7))
    return url.replace(/\/$/, "")
  }

  Component.onCompleted: root.loadAnswerPlugins()


  // Shared application engine (entries, hidden filters, icons, launch,
  // removal), owned by the shell and also used by the standalone launcher.
  // The host hands a scoped appLibrary to any plugin declaring kind "menu",
  // but it does not survive for a cloned menu: shell.qml's prunePluginApis()
  // destroys a third-party plugin's scoped APIs whenever isEnabled() reads
  // false, which it transiently does while shell.json is being re-applied,
  // and nothing ever re-injects them. isEnabled() short-circuits to true for
  // first-party plugins, so only clones are affected -- the built-in menu's
  // Apps list works while an identical clone's is empty.
  //
  // So own it instead of borrowing it.
  // AppLibrary.qml and AppSearch.js are verbatim copies (see upstream/); they
  // reach everything they need through $OMARCHY_PATH and the omarchy-shell
  // CLI, so they run unmodified outside the shell tree.
  readonly property var appLibrary: (root.shell && root.shell.appLibrary) ? root.shell.appLibrary : ownAppLibrary

  AppLibrary { id: ownAppLibrary }
  property alias deleteConfirmOpen: menuState.deleteConfirmOpen
  property var deleteTarget: null
  onOpenedChanged: if (!opened) {
    deleteConfirmOpen = false
    deleteTarget = null
    actionPanelOpen = false
    quickAccessDelay.stop()
    quickAccessActive = false
    closeAfterToast.stop()
    closingSoon = false
    toastTimer.stop()
    toastText = ""
    fileDebounce.stop()
    if (fileSearchProc.running) fileSearchProc.signal(9)
  }
  // Visual tokens and view-facing state live in launcher/. The aliases keep
  // the logic below reading and writing them under their old names.
  Appearance { id: menuAppearance }
  LauncherState { id: menuState }
  MenuHistory { id: menuHistory }
  property alias hoveredIndex: menuState.hoveredIndex
  property alias actionPanelOpen: menuState.actionPanelOpen
  property alias toastText: menuState.toastText
  property alias quickAccessActive: menuState.quickAccessActive
  property alias detailVisible: menuState.detailVisible
  property alias background: menuAppearance.background
  property alias foreground: menuAppearance.foreground
  property alias border: menuAppearance.border
  property alias borderSpec: menuAppearance.borderSpec
  property alias scrim: menuAppearance.scrim
  property alias selectedBackground: menuAppearance.selectedBackground
  property alias selectedText: menuAppearance.selectedText
  property alias selectedBorder: menuAppearance.selectedBorder
  property alias selectedBorderSpec: menuAppearance.selectedBorderSpec
  property alias rowReservedBorderLeft: menuAppearance.rowReservedBorderLeft
  property alias rowReservedBorderRight: menuAppearance.rowReservedBorderRight
  property alias cornerRadius: menuAppearance.cornerRadius
  property alias contentMargin: menuAppearance.contentMargin
  property alias contentSpacing: menuAppearance.contentSpacing
  property alias baseRowHeight: menuAppearance.baseRowHeight
  property alias rowPeek: menuAppearance.rowPeek
  property alias rowSpacing: menuAppearance.rowSpacing
  property int layoutSerial: 0
  // The launcher is a fixed window. dmenu callers size their own picker, so
  // dmenu keeps its requested width and grows downward from the same top line.
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : menuAppearance.windowWidth, panel.width - Style.gapsOut * 2)
  readonly property int cardTop: Math.max(Style.gapsOut, Math.round((panel.height - menuAppearance.windowHeight) / 3))
  // Everything in the card that is not rows: border, search bar, the rule
  // under it, and the list's own top and bottom padding.
  readonly property int cardChrome: Math.round(card.borderTop + card.borderBottom) + menuAppearance.searchBarHeight + Style.spacing.hairline + root.contentSpacing + menuAppearance.listInset + menuAppearance.footerHeight
  property int visibleRowsHeight: root.dmenuActive
    ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText)
    : Math.max(0, root.cardHeight - root.cardChrome)
  property int cardHeight: root.dmenuActive
    ? Math.min(root.mode === "input" ? Math.round(card.borderTop + card.borderBottom) + menuAppearance.searchBarHeight : root.cardChrome + visibleRowsHeight, panel.height - Style.gapsOut - root.cardTop)
    : Math.min(menuAppearance.windowHeight, panel.height - Style.gapsOut - root.cardTop)

  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(activeDoneFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    }
    resultProc.running = true
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return

    Util.execDetached(command)
  }


  // Height a dmenu card can devote to rows before running off the screen.
  function availableRowsHeight() {
    var available = panel.height - root.cardTop - Style.gapsOut - root.cardChrome
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    for (var i = 0; i < displayModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += menuAppearance.rowHeightFor(displayModel.get(i).kind, false)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  // ------------------------------------------------------------------
  // JSONC → normalized item array. Mirrors the bash bin's jq pipeline so
  // the on-disk authoring format stays untouched.
  // ------------------------------------------------------------------

  function stripJsonc(raw) {
    return MenuModel.stripJsonc(raw)
  }

  function normalizeAliases(value) {
    return MenuModel.normalizeAliases(value)
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  function parseMenuJsonc(raw) {
    return MenuModel.parseMenuJsonc(raw)
  }

  // Merge defaults + user extension. Later entries override earlier ones
  // on a per-key basis (so the user can tweak label/icon/action without
  // re-declaring the whole row).
  function rebuildItemsFromSources() {
    var mergedMenu = MenuModel.mergeMenuSources(root.defaultMenuItems, root.userMenuItems)
    mergedMenu = MenuModel.insertItems(mergedMenu.items, mergedMenu.itemOrder, root.viewItems(), "apps")
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    root.evaluateGuards()
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Each known provider is a tiny bash one-liner that enumerates a list and
  // emits one tab-delimited row per item: `label\tvalue\tcurrent`. The shell
  // turns those into menu items children of `menuId`. A `volatile` provider
  // re-runs every time its submenu is entered, so a font installed since the
  // shell started shows up without restarting it.
  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "omarchy-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + Util.shellQuote(value) }
    }
  })

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons, launch feedback, and uninstall support like the launcher.
  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        when: "",
        checked: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      root.providersLoaded[id] = true
      root.mergeAppRows()
      return
    }
    var spec = root.providers[entry.provider]
    if (!spec) return

    root.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = root.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = root.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var label = parts[0] || ""
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      // Distinct values can slugify alike — Fira Code and Fira-Code both give
      // fira-code — and a repeated id is dropped, which would silently lose a
      // row from the list. Nudge it until it is the row's own.
      var rowId = menuId + "." + root.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        when: "",
        checked: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, providerRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return

    while (root.providerQueue.length > 0) {
      var id = root.providerQueue.shift()
      var entry = root.item(id)
      if (!entry || !entry.provider || root.providersLoaded[id]) continue

      root.startProviderForMenu(id)
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if (spec && spec.volatile) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    // The clipboard and file views fill themselves; see rebuildDisplay().
    if (root.isViewId(id)) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps") {
      root.startProviderForMenu(id)
      return
    }

    if (providerProc.running) {
      if (root.providerQueue.indexOf(id) < 0) root.providerQueue = root.providerQueue.concat([id])
      return
    }

    root.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry)
  }

  // Label with the ✓ marker baked in when `checked:` evaluated truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  function matchesQuery(entry, query) {
    return MenuModel.matchesQuery(entry, query, root.isVisible(entry))
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query)
  }

  function displayRow(entry, detail, score, section) {
    return MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, entry, detail, score, section)
  }

  function rebuildDmenuDisplay() {
    displayModel.clear()

    if (root.mode === "input") {
      layoutSerial += 1
      return
    }

    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      displayModel.append({
        itemId: "dmenu." + i,
        kind: "dmenu",
        icon: icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        actionArgv: "",
        copyText: "",
        question: "",
        questionLabel: "",
        answerLabel: "",
        filePath: "",
        previewImage: "",
        mime: "",
        historyIndex: -1,
        provider: "",
        score: i,
        section: ""
      })
    }

    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // The root with no query: Favorites and Suggestions (recent launches) from
  // menuHistory above the top-level menus. Rows that no longer exist or whose
  // `when:` guard hides them are skipped, so stale history never shows.
  readonly property int maxSuggestions: 5

  function historyRow(id) {
    var entry = root.item(id)
    if (!entry || entry.id === "root" || !root.isVisible(entry)) return null
    return root.displayRow(entry, root.parentPathFor(entry.id), 0)
  }

  function rootSections(menuRows) {
    var favoriteRows = []
    for (var i = 0; i < menuHistory.favorites.length; i++) {
      var favorite = root.historyRow(menuHistory.favorites[i])
      if (favorite) favoriteRows.push(favorite)
    }

    var suggestionRows = []
    var recentIds = menuHistory.recentIds()
    for (var j = 0; j < recentIds.length && suggestionRows.length < root.maxSuggestions; j++) {
      if (menuHistory.isFavorite(recentIds[j])) continue
      var recent = root.historyRow(recentIds[j])
      if (recent) suggestionRows.push(recent)
    }

    return Sections.root(favoriteRows, suggestionRows, menuRows)
  }

  function rebuildDisplay() {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    // Answers are prepended, so an arriving answer shifts every index below
    // it. Remember the row the cursor is on by id and put it back by id.
    var keepId = ""
    if (root.cursorMoved && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count)
      keepId = displayModel.get(root.selectedIndex).itemId

    displayModel.clear()

    if (!root.rowsLoaded) return

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()

    if (root.inView) {
      if (root.inEmojiView) rows = root.emojiRows(query)
      else rows = root.inClipboardView ? root.clipboardRows(query) : root.fileRows()
    } else if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < root.itemOrder.length; i++) {
        var entry = root.item(root.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!root.isDescendantOf(entry.id, active)) continue
        if (!root.matchesQuery(entry, query)) continue

        var detail = root.parentPathFor(entry.id)
        var row = root.displayRow(entry, detail, root.searchScore(entry, query))
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      rows = Sections.search(currentRows, drilldownRows, active === "root")
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        rows.push(root.displayRow(child, child.description, child.order))
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
    }

    if (!query && active === "root") rows = root.rootSections(rows)

    if (query && root.answerRows.length > 0) {
      rows = Sections.answers(root.answerRows, function(pluginId) {
        var plugin = root.pluginById(pluginId)
        return plugin ? plugin.title : ""
      }).concat(rows)
    }

    // One call: the emoji view is close to two thousand rows.
    if (rows.length > 0) displayModel.append(rows)
    if (!root.inEmojiView && root.emojiLines.length > 0) root.emojiLines = []
    layoutSerial += 1

    var restored = -1
    if (keepId) {
      for (var r = 0; r < displayModel.count; r++) {
        if (displayModel.get(r).itemId === keepId) { restored = r; break }
      }
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (restored >= 0) selectedIndex = restored
    else if (!root.cursorMoved) selectedIndex = root.firstSelectableIndex()
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    if (root.inEmojiView) {
      var line = EmojiSearch.lineOf(root.emojiLines, root.selectedIndex)
      if (line < 0) return
      // The section's header comes along when the cursor is on its first line.
      if (line > 0 && root.emojiLines[line - 1].header !== undefined)
        emojiGrid.positionViewAtIndex(line - 1, ListView.Contain)
      emojiGrid.positionViewAtIndex(line, ListView.Contain)
      return
    }
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (displayModel.count === 0) return

    root.cursorMoved = true
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    revealCursor()
  }

  // --- actions --------------------------------------------------------
  // What the selected row can do (Actions.js). The footer shows the first
  // and the action panel lists them all. The arguments are only there so the
  // binding re-evaluates when the rows, the selection or the history change.
  readonly property var selectedActions: root.actionsForSelection(root.selectedIndex, root.cursorActive, root.layoutSerial, menuHistory.favorites, menuHistory.recents, root.detailVisible, root.viewDetailVisible, menuHistory.emojiPins, menuHistory.emojiRecents)

  function selectedRow() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return null
    return displayModel.get(root.selectedIndex)
  }

  function actionsForSelection() {
    var row = root.selectedRow()
    if (!row) return []
    var list = Actions.actionsFor(row, {
      isFavorite: menuHistory.isFavorite,
      inSuggestions: row.section === "Suggestions",
      canUninstall: !!root.appLibrary,
      detailsShown: root.inView ? root.viewDetailVisible : root.detailVisible,
      isEmojiPinned: menuHistory.isEmojiPinned,
      inEmojiRecents: function(e) { return menuHistory.emojiRecents.indexOf(e) >= 0 }
    })
    for (var i = 0; i < list.length; i++) list[i].keycaps = Actions.keycaps(list[i].keys)
    return list
  }

  function runRowAction(action) {
    root.closeActionPanel()
    var row = root.selectedRow()
    if (!action || !row) return

    if (action.id === "open") {
      root.activateIndex(root.selectedIndex)
    } else if (action.id === "favorite") {
      menuHistory.toggleFavorite(row.itemId)
      root.showToast(menuHistory.isFavorite(row.itemId) ? "Added to Favorites" : "Removed from Favorites")
      // Keep the cursor on the same row when it moves into or out of
      // Favorites; rebuildDisplay() restores it by id.
      root.cursorMoved = true
      root.rebuildDisplay()
    } else if (action.id === "forget") {
      menuHistory.forgetRecent(row.itemId)
      root.showToast("Removed from Suggestions")
      root.rebuildDisplay()
    } else if (action.id === "copy") {
      root.copyAndClose(action.text)
    } else if (action.id === "uninstall") {
      root.requestDeleteSelected()
    } else if (action.id === "details") {
      if (root.inView) root.viewDetailVisible = !root.viewDetailVisible
      else root.detailVisible = !root.detailVisible
    } else if (action.id === "copy-clip") {
      root.copyClip(row)
    } else if (action.id === "open-clip") {
      root.openClip(row)
    } else if (action.id === "remove") {
      root.requestDeleteSelected()
    } else if (action.id === "reveal") {
      root.revealFile(row)
    } else if (action.id === "copy-file") {
      root.copyFile(row)
    } else if (action.id === "copy-emoji") {
      menuHistory.recordEmoji(row.copyText)
      root.copyAndClose(row.copyText)
    } else if (action.id === "pin-emoji") {
      menuHistory.toggleEmojiPin(row.copyText)
      root.showToast(menuHistory.isEmojiPinned(row.copyText) ? "Pinned " + row.copyText : "Unpinned " + row.copyText)
      root.cursorMoved = true
      root.rebuildDisplay()
    } else if (action.id === "forget-emoji") {
      root.forgetEmoji(row)
    }
  }

  function openActionPanel() {
    if (root.selectedActions.length === 0) return
    root.endQuickAccess()
    root.actionPanelOpen = true
    actionPanel.show()
  }

  function closeActionPanel() {
    if (!root.actionPanelOpen) return
    root.actionPanelOpen = false
    Qt.callLater(function() { searchBar.focusInput() })
  }

  function toggleActionPanel() {
    if (root.actionPanelOpen) root.closeActionPanel()
    else root.openActionPanel()
  }

  // Over stdin, because wl-copy has no `--` terminator and would read a value
  // like "-42" as an option, and because the clipboard content never lands in
  // the process table this way. stdin is re-enabled each time: onStarted
  // closes it once the payload is written.
  function copyText(text) {
    clipProc.payload = String(text || "")
    clipProc.stdinEnabled = true
    clipProc.running = true
  }

  // Copy, confirm it in the footer, then close: the toast is the only sign
  // the copy happened, so the launcher stays up long enough to read it.
  function copyAndClose(text, shown) {
    root.copyText(text)
    root.toastAndClose("Copied " + String(shown || text || ""))
  }

  function toastAndClose(message) {
    var text = String(message || "")
    if (text.length > 47) text = text.substring(0, 46) + "…"
    root.showToast(text)
    root.closingSoon = true
    closeAfterToast.restart()
  }

  // Set between a copy and the close that follows it. Keys are ignored then,
  // except Esc, which closes at once.
  property bool closingSoon: false

  function showToast(text) {
    root.toastText = text
    toastTimer.restart()
  }

  Timer {
    id: toastTimer
    interval: 2000
    onTriggered: root.toastText = ""
  }

  Timer {
    id: closeAfterToast
    interval: 900
    onTriggered: root.closeAfterCopy()
  }

  function closeAfterCopy() {
    closeAfterToast.stop()
    root.closingSoon = false
    root.applySerial = root.requestSerial
    root.opened = false
    root.filterText = ""
  }

  // --- details -----------------------------------------------------------
  // The pane beside the list: an app's desktop entry, a clipboard entry's
  // content, a file's preview. It shows while it is switched on and the
  // selected row has details; other rows get the full width back. The
  // clipboard and file views have their own switch, on by default.
  readonly property var selectedDetails: root.detailsFor(root.selectedIndex, root.cursorActive, root.layoutSerial, clipboardSource.history)
  readonly property bool detailShown: !root.dmenuActive && root.selectedDetails !== null
    && (root.inView ? root.viewDetailVisible : root.detailVisible)

  // { name, subtitle, comment, iconSource, glyph, hueId, previewImage,
  //   previewText, fields: [{ label, value }] }
  function detailsFor() {
    var row = root.selectedRow()
    if (!row) return null
    if (row.kind === "app") return root.appDetails(row)
    if (row.kind === "clip") return root.clipDetails(row)
    if (row.kind === "file") return root.fileDetails(row)
    return null
  }

  function details(fields) {
    var d = { name: "", subtitle: "", comment: "", iconSource: "", glyph: "", hueId: "",
      previewImage: "", previewText: "", fields: [] }
    for (var k in fields) d[k] = fields[k]
    return d
  }

  function appDetails(row) {
    var entry = DesktopEntries.byId(row.appId)
    if (!entry) return null
    var join = function(list) {
      try { return list && list.length ? Array.prototype.slice.call(list).join(", ") : "" } catch (e) { return "" }
    }
    var fields = []
    var command = String(entry.execString || "")
    if (command) fields.push({ label: "Command", value: command })
    if (join(entry.categories)) fields.push({ label: "Categories", value: join(entry.categories) })
    if (join(entry.keywords)) fields.push({ label: "Keywords", value: join(entry.keywords) })
    fields.push({ label: "Desktop ID", value: row.appId })
    if (entry.runInTerminal) fields.push({ label: "Runs in", value: "Terminal" })
    return root.details({
      name: row.label,
      subtitle: String(entry.genericName || ""),
      comment: String(entry.comment || ""),
      iconSource: root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : "",
      fields: fields
    })
  }

  function clipDetails(row) {
    var entry = clipboardSource.entry(row.historyIndex)
    if (!entry) return null

    if (entry.type === "image") {
      var fields = [{ label: "Type", value: "Image (" + String(entry.mime || "").replace("image/", "") + ")" }]
      if (entry.capturedAt) fields.push({ label: "Copied", value: entry.capturedAt })
      fields.push({ label: "Stored at", value: FileSearch.compressHome(entry.path, root.homeDir) })
      return root.details({ previewImage: row.previewImage, fields: fields })
    }

    var text = String(entry.text || "")
    if (row.detail === "File") {
      return root.details({
        previewImage: row.previewImage,
        previewText: row.previewImage ? "" : text.replace(/file:\/\//g, ""),
        fields: [{ label: "Type", value: "File" }]
      })
    }

    var size = root.textSize(text)
    return root.details({
      previewText: text.substring(0, 4000),
      fields: [
        { label: "Type", value: "Text" },
        { label: "Characters", value: String(size.chars) },
        { label: "Lines", value: size.lines + (size.more ? "+" : "") }
      ]
    })
  }

  function fileDetails(row) {
    var dir = row.mime === "inode/directory"
    var name = row.label
    var dot = name.lastIndexOf(".")
    var kind = dir ? "Folder" : (dot > 0 ? name.substring(dot + 1).toUpperCase() + " file" : "File")
    return root.details({
      name: name,
      glyph: row.icon,
      hueId: row.itemId,
      previewImage: row.previewImage,
      fields: [
        { label: "Where", value: FileSearch.compressHome(FileSearch.parentDir(row.filePath), root.homeDir) },
        { label: "Kind", value: kind }
      ]
    })
  }

  // --- quick access ------------------------------------------------------
  // Holding Ctrl on its own for a moment shows Ctrl+1..9, Ctrl+0 on the first
  // ten rows; Ctrl+digit runs that row whether or not the keycaps showed.
  Timer {
    id: quickAccessDelay
    interval: 250
    onTriggered: root.quickAccessActive = true
  }

  function endQuickAccess() {
    quickAccessDelay.stop()
    root.quickAccessActive = false
  }

  function handleSearchKeyRelease(event) {
    if (event.key === Qt.Key_Control && !event.isAutoRepeat) root.endQuickAccess()
  }

  readonly property string footerTitle: {
    if (root.dmenuActive) return root.dmenuPrompt
    if (root.activeMenu === "root") return "Omarchy"
    var active = root.item(root.activeMenu)
    var title = active ? (active.title || active.label) : ""
    // The grid has no labels, so the footer names the selected emoji, the
    // way vicinae's navigation title does.
    if (root.inEmojiView) {
      var row = root.selectedActions.length > 0 ? root.selectedRow() : null
      if (row) return title + " · " + row.label
    }
    return title
  }

  readonly property string searchPlaceholder: {
    if (root.dmenuActive) return root.dmenuPrompt + "…"
    if (root.activeMenu === "root") return "Search apps and commands…"
    if (root.inEmojiView) return "Search emojis…"
    var active = root.item(root.activeMenu)
    return "Search " + (active ? (active.title || active.label) : "") + "…"
  }

  // Offered every key before the search input sees it. Takes the keys that
  // drive the list and leaves text editing (typing, cursor movement, paste,
  // Ctrl+Backspace) to the input.
  function handleSearchKey(event, input) {
    if (root.closingSoon) {
      if (event.key === Qt.Key_Escape) root.closeAfterCopy()
      return true
    }

    // Holding Ctrl auto-repeats as release/press pairs; only the first real
    // press and the final real release count.
    if (event.key === Qt.Key_Control) {
      if (!event.isAutoRepeat && !quickAccessDelay.running && !root.quickAccessActive) quickAccessDelay.start()
      return false
    }
    root.endQuickAccess()

    if (event.modifiers === Qt.ControlModifier && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
      var slot = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1
      if (slot < displayModel.count) {
        root.cursorActive = true
        root.selectedIndex = slot
        root.activateIndex(slot)
      }
      return true
    }

    // The dialog owns the keyboard while it is up; nothing may reach the input.
    if (root.deleteConfirmOpen) {
      deleteConfirm.handleKey(event)
      return true
    }

    // Right and Delete only mean "act on the row" once there is no text to
    // their right; before that they move and edit inside the query.
    var atEnd = input.cursorPosition === input.text.length && input.selectedText === ""
    var key = event.key

    if (Actions.matchesAny(event, Actions.TOGGLE_PANEL)) {
      root.toggleActionPanel()
      return true
    }
    // Delete keeps its own rule below: it edits the query until the text
    // cursor reaches the end.
    var shortcut = Actions.forShortcut(root.selectedActions, event)
    if (shortcut && shortcut.keys !== "delete") {
      root.runRowAction(shortcut)
      return true
    }

    if (root.inFileView && (key === Qt.Key_Tab || (key === Qt.Key_Right && atEnd))) {
      if (root.completeFolder(root.selectedRow())) return true
    }
    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) return true
    if (root.inEmojiView && event.modifiers === Qt.NoModifier && root.handleEmojiKey(key)) return true
    if (key === Qt.Key_Delete) {
      if (!atEnd) return false
      root.requestDeleteSelected()
      return true
    }
    if (key === Qt.Key_Escape) {
      if (root.filterText) root.setFilter("")
      else root.cancel()
      return true
    }
    if (key === Qt.Key_U && event.modifiers === Qt.ControlModifier) {
      if (root.filterText) root.setFilter("")
      return true
    }
    if ((key === Qt.Key_Backspace || key === Qt.Key_Left) && !root.filterText) {
      root.goBack()
      return true
    }
    if (key === Qt.Key_Up) { root.select(-1); return true }
    if (key === Qt.Key_Down) { root.select(1); return true }
    if (key === Qt.Key_PageUp) { root.select(-6); return true }
    if (key === Qt.Key_PageDown) { root.select(6); return true }
    if (key === Qt.Key_Return || key === Qt.Key_Enter || (key === Qt.Key_Right && atEnd)) {
      if (root.dmenuActive) {
        if (root.mode === "input") root.applyDmenuSelection(root.filterText)
        else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
      } else if (root.cursorActive) root.activateIndex(root.selectedIndex)
      else if (displayModel.count > 0) root.cursorActive = true
      return true
    }
    return false
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = root.mode !== "input"
    root.cursorMoved = false
    root.disarmPointer()
    if (root.inView) {
      root.scheduleFileSearch()
      root.rebuildDisplay()
      return
    }
    if (!root.dmenuActive && root.filterText.trim()) root.loadProvidersForSearch()
    // Before rebuildDisplay(), so a query that no longer has an answer drops
    // its stale row in the same frame rather than showing a wrong one.
    root.scheduleAnswers()
    root.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.clearAnswers()
    root.scheduleFileSearch()
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.deleteConfirmOpen) return
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      return
    }

    if (index < 0 || index >= displayModel.count) return

    var row = displayModel.get(index)
    if (row.kind === "answer") {
      root.applyAnswer(row)
      return
    }
    if (row.kind === "clip") {
      root.pasteClip(row)
      return
    }
    if (row.kind === "file") {
      root.openFile(row)
      return
    }
    if (row.kind === "emoji") {
      root.pasteEmoji(row)
      return
    }
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app") {
      menuHistory.recordLaunch(row.itemId)
      var appId = row.appId
      var label = row.label
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      menuHistory.recordLaunch(row.itemId)
      root.applySelected(row.itemId, row.action)
    }
  }

  function requestDeleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return
    var row = displayModel.get(root.selectedIndex)
    if (!row) return
    if (row.kind === "emoji") {
      // No dialog: forgetting a recent emoji loses nothing.
      if (menuHistory.emojiRecents.indexOf(row.copyText) >= 0) root.forgetEmoji(row)
      return
    }
    if (row.kind === "clip") root.deleteTarget = { kind: "clip", key: clipboardSource.keyAt(row.historyIndex), label: row.label }
    else if (row.kind === "app") root.deleteTarget = { kind: "app", appId: row.appId, label: row.label }
    else return
    deleteConfirm.selectedIndex = 1
    root.deleteConfirmOpen = true
  }

  function cancelDelete() {
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    deleteConfirm.selectedIndex = 1
    root.disarmPointer()
    Qt.callLater(function() { searchBar.focusInput() })
  }

  function confirmDelete() {
    var target = root.deleteTarget
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    if (!target) return
    if (target.kind === "clip") {
      // By key: a copy made while the dialog was up has shifted the indexes.
      clipboardSource.removeKey(target.key)
      root.showToast("Removed from Clipboard History")
      root.disarmPointer()
      Qt.callLater(function() { searchBar.focusInput() })
      return
    }
    root.cancel()
    if (root.appLibrary) root.appLibrary.remove(target.appId, target.label)
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    filterText = ""
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    filterText = ""
    root.runAction(action)
  }

  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    root.clearAnswers()
    opened = false
    filterText = ""
  }

  function openExistingMenu(initialMenu) {
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = true
    root.clearAnswers()
    root.scheduleFileSearch()
    root.disarmPointer()
    root.evaluateGuards()
    opened = true
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    loadProviderForMenu(activeMenu)
    // The shell may start before first-install packages have finished placing
    // their icons. Refresh here even when the desktop entry list did not change.
    if (root.appLibrary) root.appLibrary.refreshIcons()

    Qt.callLater(function() { searchBar.focusInput() })
  }

  function openDmenu(payload) {
    requestSerial += 1
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? "Input" : "Select"))
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = mode !== "input"
    root.clearAnswers()
    root.disarmPointer()
    opened = true
    rebuildDisplay()

    Qt.callLater(function() { searchBar.focusInput() })
  }
  ListModel { id: displayModel }

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the standard plugin lifecycle:
  // `omarchy-shell shell summon omarchy.menu '{"menu":"system"}'`.
  // Callers may pass a real id (`system`, `setup.power`) or an alias declared
  // in JSONC (`power`, `reminder-set`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `omarchy menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
    root.hoveredIndex = -1
  }

  // Hover highlights the row under a pointer that really moved; it does not
  // select it. Rows sliding under a still pointer (a rebuild, a scroll) are
  // filtered out by pointerGate.
  function hoverFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.hoveredIndex = index
  }

  function clearHover(index) {
    if (root.hoveredIndex === index) root.hoveredIndex = -1
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === root.providerRevision) {
        root.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (root.filterText.trim()) root.loadProvidersForSearch()
      }
      root.startNextProvider()
    }
  }

  // ------------------------------------------------------------------
  // Query plugins
  //
  // A query plugin answers the typed text instead of matching against it.
  // Two kinds: "js" runs in this engine and is synchronous, "command" runs a
  // process and is debounced, cancellable and killable.
  //
  // Three things have to be true before a stale answer can be shown, so each
  // is checked independently: the answer must belong to the current query
  // (revision), the menu must still be open, and it must not be a dmenu.

  function loadAnswerPlugins() {
    var list = []
    var builtins = QueryBuiltins.descriptors(root.pluginDir, {
      omarchyPath: root.omarchyPath,
      searchEmojis: function(query, limit) { return emojiSource.search(query, limit) }
    })

    for (var i = 0; i < builtins.length; i++) {
      var plugin = QueryPlugins.normalizeDescriptor(builtins[i], "builtin")
      if (plugin) list.push(plugin)
    }

    root.answerPlugins = list
    // User plugins arrive asynchronously and are merged on top.
    pluginScanProc.running = true
  }

  function mergeUserAnswerPlugins(rawJson) {
    if (!QueryPlugins.dynamicJsAvailable()) {
      console.warn("super-menu: this QML engine will not build functions at runtime; user .js query plugins are disabled")
      return
    }

    var files = []
    try {
      files = JSON.parse(rawJson || "[]")
    } catch (e) {
      return
    }
    if (!Array.isArray(files)) return

    var merged = root.answerPlugins.slice()

    for (var i = 0; i < files.length; i++) {
      var file = files[i] || ({})
      var name = String(file.path || "")
      var plugin = null

      try {
        plugin = QueryPlugins.normalizeDescriptor(
          QueryPlugins.compileDescriptor(file.source, name, {
            home: Quickshell.env("HOME"),
            dir: root.userPluginDir,
            pluginDir: root.pluginDir
          }), "user")
      } catch (e) {
        console.warn("super-menu: query plugin " + name + " failed to load: " + e)
        continue
      }
      if (!plugin) continue

      // A user plugin claiming a built-in id replaces it rather than racing
      // it, which is how someone swaps out the shipped calculator.
      var replaced = false
      for (var j = 0; j < merged.length; j++) {
        if (merged[j].id === plugin.id) { merged[j] = plugin; replaced = true; break }
      }
      if (!replaced) merged.push(plugin)
    }

    root.answerPlugins = merged
  }

  function clearAnswers() {
    root.answerRevision += 1
    root.answerQueue = []
    root.answerFocusable = false
    answerDebounce.stop()
    answerWatchdog.stop()
    if (answerProc.running) answerProc.signal(9)
    if (root.answerRows.length > 0) root.answerRows = []
  }

  function scheduleAnswers() {
    // dmenu is a caller's list of options, not a place for our answers.
    if (root.dmenuActive || !root.opened) { root.clearAnswers(); return }

    var query = root.filterText.trim()
    if (!query) { root.clearAnswers(); return }

    var matches = QueryPlugins.matchAll(root.answerPlugins, query)
    if (matches.length === 0) { root.clearAnswers(); return }

    // Any answer still on screen belongs to the previous query.
    root.answerRevision += 1
    root.answerQueue = []
    answerWatchdog.stop()
    if (answerProc.running) answerProc.signal(9)
    if (root.answerRows.length > 0) root.answerRows = []

    var revision = root.answerRevision
    var rows = []
    var queue = []
    var debounce = 0

    for (var i = 0; i < matches.length; i++) {
      var plugin = matches[i].plugin
      var match = matches[i].match

      if (plugin.kind === "js") {
        // Synchronous: no debounce, no process, answer in this frame.
        try {
          rows = rows.concat(QueryPlugins.normalizeRows(plugin.rows(match), plugin, match))
        } catch (e) {
          console.warn("super-menu: query plugin " + plugin.id + " threw: " + e)
          plugin.disabled = true
        }
      } else {
        queue.push({ plugin: plugin, match: match })
        debounce = Math.max(debounce, plugin.debounce)
      }

      if (i === 0) root.answerFocusable = QueryPlugins.answerTakesFocus(plugin, match)
    }

    if (rows.length > 0) root.answerRows = rows

    root.answerQueue = queue
    if (queue.length > 0) {
      answerDebounce.revision = revision
      answerDebounce.interval = Math.max(1, debounce)
      answerDebounce.restart()
    }
  }

  function runNextAnswer() {
    if (answerProc.running) return
    if (root.answerQueue.length === 0) return

    var next = root.answerQueue[0]
    root.answerQueue = root.answerQueue.slice(1)

    var plugin = next.plugin
    var text = next.match.text
    var argv = plugin.argv.slice()

    if (plugin.queryVia === "argv") {
      for (var i = 0; i < argv.length; i++) {
        if (argv[i] === "{{query}}") argv[i] = text
      }
    }

    answerProc.pluginId = plugin.id
    answerProc.revision = root.answerRevision
    answerProc.stdinText = plugin.queryVia === "stdin" ? text : ""
    answerProc.stdinEnabled = plugin.queryVia === "stdin"
    // The query goes through the environment or as one whole argv element,
    // never spliced into a shell string.
    answerProc.environment = ({ "OMARCHY_QUERY": text })
    answerWatchdog.interval = Math.max(50, plugin.timeout)
    answerProc.command = argv
    answerProc.running = true
  }

  function pluginById(id) {
    for (var i = 0; i < root.answerPlugins.length; i++) {
      if (root.answerPlugins[i].id === id) return root.answerPlugins[i]
    }
    return null
  }

  function deliverAnswers(pluginId, revision, code, status, text) {
    if (revision !== root.answerRevision) return
    if (!root.opened || root.dmenuActive) return

    var plugin = root.pluginById(pluginId)
    if (!plugin) return

    if (!QueryPlugins.acceptsExit(plugin, code, status)) {
      root.noteAnswerFailure(plugin)
      return
    }

    var payload = QueryPlugins.parseCommandOutput(text)
    if (!payload) return

    plugin.failures = 0
    var rows = QueryPlugins.normalizeRows(payload, plugin, null)
    if (rows.length === 0) return

    root.answerRows = root.answerRows.concat(rows)
    root.rebuildDisplay()
  }

  // A plugin that keeps failing is a plugin that keeps costing a process per
  // query for nothing. Stop asking it until the shell reloads.
  function noteAnswerFailure(plugin) {
    plugin.failures += 1
    if (plugin.failures < 3) return
    plugin.disabled = true
    console.warn("super-menu: query plugin " + plugin.id + " disabled after 3 consecutive failures")
  }

  function applyAnswer(row) {
    var argv = []
    if (row.actionArgv) {
      try { argv = JSON.parse(row.actionArgv) } catch (e) { argv = [] }
    }

    if (argv.length > 0 || row.action) {
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (argv.length > 0) Util.execArgv(argv)
      else Util.execDetached(row.action)
      return
    }

    // The default: put the value on the clipboard. The toast shows the
    // rounded value the row displays; the clipboard gets full precision.
    root.copyAndClose(row.copyText || row.label, row.label)
  }

  // Where the cursor sits when the user has not moved it. An answer only
  // takes row 0 when it was explicitly asked for; otherwise Enter stays
  // aimed at the first real search result.
  function firstSelectableIndex() {
    if (displayModel.count === 0) return 0
    if (root.answerFocusable) return 0

    for (var i = 0; i < displayModel.count; i++) {
      if (displayModel.get(i).kind !== "answer") return i
    }
    return 0
  }

  Timer {
    id: answerDebounce
    property int revision: 0
    repeat: false
    onTriggered: {
      if (answerDebounce.revision !== root.answerRevision) return
      root.runNextAnswer()
    }
  }

  Process {
    id: answerProc
    property string pluginId: ""
    property string stdinText: ""
    property int revision: 0
    stdout: StdioCollector { id: answerOut; waitForEnd: true }
    onStarted: {
      if (answerProc.stdinText) {
        answerProc.write(answerProc.stdinText + "\n")
        answerProc.stdinEnabled = false
      }
      answerWatchdog.restart()
    }
    onExited: function(exitCode, exitStatus) {
      answerWatchdog.stop()
      root.deliverAnswers(answerProc.pluginId, answerProc.revision, exitCode, exitStatus, answerOut.text)
      root.runNextAnswer()
    }
  }

  // A plugin that hangs must not hang the menu. SIGKILL, because a plugin
  // wedged on a network read will not act on anything politer.
  Timer {
    id: answerWatchdog
    repeat: false
    onTriggered: {
      if (!answerProc.running) return
      var plugin = root.pluginById(answerProc.pluginId)
      if (plugin) root.noteAnswerFailure(plugin)
      answerProc.signal(9)
    }
  }

  // ------------------------------------------------------------------
  // Clipboard History and Search Files
  //
  // Two root rows that open views of their own, the way vicinae's commands
  // do. They are ordinary menu items, so search, Favorites, Back and routes
  // (`{"menu":"clipboard-history"}`) all work, but their rows come from the
  // clipboard history file and from fd instead of the menu tree, and the
  // query goes to them instead of to the query plugins.

  readonly property string clipboardView: "clipboard-history"
  readonly property string fileView: "file-search"
  readonly property string emojiView: "emoji"
  readonly property bool inClipboardView: !root.dmenuActive && root.activeMenu === root.clipboardView
  readonly property bool inFileView: !root.dmenuActive && root.activeMenu === root.fileView
  readonly property bool inEmojiView: !root.dmenuActive && root.activeMenu === root.emojiView
  readonly property bool inView: root.inClipboardView || root.inFileView || root.inEmojiView
  readonly property string homeDir: Quickshell.env("HOME")

  // The views open split, like vicinae's. Ctrl+D there toggles this, not the
  // app pane's setting.
  property bool viewDetailVisible: true

  // The last fd run for the file view, [{ path, dir }], and the query it
  // answers. Kept while the next one runs, so typing does not blank the list.
  property var fileResults: []
  property string fileQuery: ""
  property int fileRevision: 0

  // Search results past this are not worth a grid; a longer query narrows them.
  readonly property int maxEmojiResults: 400
  property alias emojiLines: menuState.emojiLines

  EmojiSource {
    id: emojiSource
    onEmojisChanged: if (root.opened && root.inEmojiView) root.rebuildDisplay()
  }

  ClipboardSource {
    id: clipboardSource
    onHistoryChanged: if (root.opened && root.inClipboardView) root.rebuildDisplay()
  }

  function viewItems() {
    return [
      MenuModel.normalizeItem(root.clipboardView, {
        parent: "root", label: "Clipboard History", icon: "󰅌", provider: "clipboard",
        aliases: ["clipboard", "paste", "copied"]
      }),
      MenuModel.normalizeItem(root.fileView, {
        parent: "root", label: "Search Files", icon: "󰍉", provider: "files",
        aliases: ["files", "find", "file"]
      }),
      MenuModel.normalizeItem(root.emojiView, {
        parent: "root", label: "Search Emojis", icon: "󰞅", provider: "emoji",
        aliases: ["emojis", "emoticon", "smiley"]
      })
    ]
  }

  function isViewId(id) {
    return id === root.clipboardView || id === root.fileView || id === root.emojiView
  }

  // From the full entry, not the capped copy displayRows() hands out.
  // Characters are exact; lines are counted over a prefix, so a
  // multi-megabyte paste costs no more than a large one. `more` marks a count
  // that stopped short.
  function textSize(text) {
    var limit = Math.min(text.length, 100000)
    var lines = 1
    for (var at = text.indexOf("\n"); at >= 0 && at < limit; at = text.indexOf("\n", at + 1)) lines++
    return { chars: text.length, lines: lines, more: limit < text.length }
  }

  function clipboardRows(query) {
    var entries = clipboardSource.displayRows(query)
    var rows = []
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      var detail = ""
      if (e.entryType === "image") detail = "Image"
      else if (e.entryType === "file") detail = "File"
      else {
        var entry = clipboardSource.entry(e.index)
        var size = root.textSize(String(entry ? entry.text : e.fullText))
        detail = size.lines > 1 ? size.lines + (size.more ? "+" : "") + " lines" : size.chars + " characters"
      }
      rows.push(MenuModel.viewRow({
        itemId: "clip." + e.index,
        kind: "clip",
        icon: e.entryType === "image" ? "󰋩" : (e.entryType === "file" ? "󰈔" : "󰅍"),
        // One line is all a row shows; the pane has the rest.
        label: e.previewText.trim().substring(0, 300),
        detail: detail,
        previewImage: e.previewImage ? Util.fileUrl(e.previewImage) : "",
        filePath: e.path,
        mime: e.mime,
        historyIndex: e.index
      }))
    }
    return rows
  }

  // Search Emojis. The rows are one flat list, section by section, so the
  // selection, actions and footer work as they do for any view; the grid
  // draws them from emojiLines, which numbers its cells by the same index.
  function emojiRows(query) {
    var sections = query
      ? [{ label: "Results", items: emojiSource.search(query, root.maxEmojiResults) }]
      : EmojiSearch.sections(emojiSource.emojis, menuHistory.emojiPins, menuHistory.emojiRecents)
    root.emojiLines = EmojiSearch.lines(sections, emojiGrid.columns)

    var rows = []
    for (var s = 0; s < sections.length; s++) {
      var items = sections[s].items
      for (var i = 0; i < items.length; i++) {
        rows.push(MenuModel.viewRow({
          // By section too: a pinned or recent emoji is also in its category,
          // and rebuildDisplay() puts the cursor back on the first row with
          // its id.
          itemId: "emoji." + sections[s].label + "." + items[i].e,
          kind: "emoji",
          icon: items[i].e,
          label: items[i].name,
          detail: EmojiSearch.codepoint(items[i].e),
          copyText: items[i].e,
          section: sections[s].label
        }))
      }
    }
    return rows
  }

  // Arrows move through the grid in two dimensions. Left and Right no longer
  // edit the query here, as in vicinae and omarchy.emojis; Backspace on an
  // empty query still goes back.
  function handleEmojiKey(key) {
    var count = displayModel.count
    if (count === 0) return false
    var next = -1
    var page = Math.max(1, Math.floor(emojiGrid.height / Math.max(1, emojiGrid.cellSize)))
    if (key === Qt.Key_Left) next = Math.max(0, root.selectedIndex - 1)
    else if (key === Qt.Key_Right) next = Math.min(count - 1, root.selectedIndex + 1)
    else if (key === Qt.Key_Up) next = EmojiSearch.moveVertical(root.emojiLines, root.selectedIndex, -1)
    else if (key === Qt.Key_Down) next = EmojiSearch.moveVertical(root.emojiLines, root.selectedIndex, 1)
    else if (key === Qt.Key_PageUp) next = EmojiSearch.moveVertical(root.emojiLines, root.selectedIndex, -page)
    else if (key === Qt.Key_PageDown) next = EmojiSearch.moveVertical(root.emojiLines, root.selectedIndex, page)
    else return false

    root.cursorMoved = true
    root.disarmPointer()
    if (!root.cursorActive) {
      root.cursorActive = true
      next = 0
    }
    root.selectedIndex = next
    root.revealCursor()
    return true
  }

  // omarchy.emojis' own helper: copies the emoji, then presses Shift+Insert
  // in the window that had focus once the launcher has let it go.
  function pasteEmoji(row) {
    var emoji = row.copyText
    menuHistory.recordEmoji(emoji)
    root.closeNow()
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-menu-emoji-insert", emoji])
  }

  function forgetEmoji(row) {
    menuHistory.forgetEmoji(row.copyText)
    root.showToast("Removed from Recently Used")
    root.rebuildDisplay()
  }

  function fileRows() {
    var listing = FileSearch.isPathQuery(root.fileQuery)
    var rows = []
    for (var i = 0; i < root.fileResults.length; i++) {
      var r = root.fileResults[i]
      var image = !r.dir && FileSearch.isImagePath(r.path)
      rows.push(MenuModel.viewRow({
        itemId: "file." + r.path,
        kind: "file",
        icon: r.dir ? "󰉋" : (image ? "󰋩" : "󰈔"),
        label: FileSearch.baseName(r.path) || r.path,
        // A listing's folder is already in its section header.
        detail: listing ? "" : FileSearch.compressHome(FileSearch.parentDir(r.path), root.homeDir),
        previewImage: image ? Util.fileUrl(r.path) : "",
        filePath: r.path,
        mime: r.dir ? "inode/directory" : ""
      }))
    }
    var dir = FileSearch.pathQueryParts(root.fileQuery, root.homeDir).dir
    return Sections.labelled(rows, listing ? FileSearch.compressHome(dir, root.homeDir) : "Results")
  }

  // Every keystroke drops the run in flight; the next one starts once typing
  // pauses.
  function scheduleFileSearch() {
    root.fileRevision += 1
    fileDebounce.stop()
    if (fileSearchProc.running) fileSearchProc.signal(9)

    if (!root.inFileView || !root.filterText.trim()) {
      root.fileResults = []
      root.fileQuery = ""
      return
    }
    fileDebounce.restart()
  }

  function runFileSearch() {
    // A killed run may not have exited yet, and Process ignores a new command
    // while it is running. Start again once it has.
    if (fileSearchProc.running) {
      fileSearchProc.rerun = true
      fileSearchProc.signal(9)
      return
    }
    var query = root.filterText.trim()
    var argv = FileSearch.argvFor(query, root.homeDir)
    if (!root.inFileView || argv.length === 0) return

    fileSearchProc.revision = root.fileRevision
    fileSearchProc.query = query
    fileSearchProc.command = argv
    fileSearchProc.running = true
  }

  function deliverFiles(query, status, text) {
    if (!root.opened || !root.inFileView) return
    // fd exits 1 when it could not read some directory, and still prints
    // everything it found. Only a killed run is thrown away.
    if (status !== 0) return
    root.fileResults = FileSearch.results(text, query, root.homeDir)
    root.fileQuery = query
    root.rebuildDisplay()
  }

  Timer {
    id: fileDebounce
    interval: 120
    repeat: false
    onTriggered: root.runFileSearch()
  }

  Process {
    id: fileSearchProc
    property int revision: 0
    property string query: ""
    property bool rerun: false
    stdout: StdioCollector { id: fileSearchOut; waitForEnd: true }
    onStarted: fileWatchdog.restart()
    onExited: function(exitCode, exitStatus) {
      fileWatchdog.stop()
      if (fileSearchProc.rerun) {
        fileSearchProc.rerun = false
        Qt.callLater(root.runFileSearch)
        return
      }
      if (fileSearchProc.revision === root.fileRevision)
        root.deliverFiles(fileSearchProc.query, exitStatus, fileSearchOut.text)
    }
  }

  // A walk that runs this long is into something huge (a network mount);
  // keep what the last run found rather than wait on it.
  Timer {
    id: fileWatchdog
    interval: 1500
    repeat: false
    onTriggered: if (fileSearchProc.running) fileSearchProc.signal(9)
  }

  function closeNow() {
    root.applySerial = root.requestSerial
    root.opened = false
    root.filterText = ""
  }

  // Enter on a clipboard entry pastes it into the window that had focus, the
  // way omarchy.clipboard does; the helpers read the entry back by index so a
  // huge paste never passes through here. They sleep before pressing
  // Shift+Insert, which is time enough for the launcher to let go of focus.
  function clipCommand(row, copyOnly) {
    var bin = root.omarchyPath + "/bin/"
    if (row.mime.indexOf("image/") === 0 && row.filePath) {
      return [bin + "omarchy-clipboard-paste-file"].concat(copyOnly ? ["--copy-only"] : [], [row.mime, row.filePath])
    }
    return [bin + "omarchy-clipboard-paste-text", copyOnly ? "--copy-only" : "--shift-insert", "--history-index", String(row.historyIndex)]
  }

  function pasteClip(row) {
    var argv = root.clipCommand(row, false)
    root.closeNow()
    Quickshell.execDetached(argv)
  }

  function copyClip(row) {
    Quickshell.execDetached(root.clipCommand(row, true))
    root.toastAndClose("Copied " + row.label)
  }

  // A URL goes to the browser, an image to the editor, text to $EDITOR.
  function openClip(row) {
    var argv = [root.omarchyPath + "/bin/omarchy-clipboard-open", "--history-index", String(row.historyIndex)]
    root.closeNow()
    Quickshell.execDetached(argv)
  }

  function openFile(row) {
    var path = row.filePath
    root.closeNow()
    Quickshell.execDetached(["xdg-open", path])
  }

  function revealFile(row) {
    var path = row.filePath
    root.closeNow()
    Quickshell.execDetached(["bash", "-c",
      'if command -v nautilus >/dev/null; then exec nautilus --select "$1"; else exec xdg-open "$(dirname "$1")"; fi',
      "bash", path])
  }

  // As a file, not its path: pasting into a file manager or a chat copies it.
  function copyFile(row) {
    Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", Util.fileUrl(row.filePath)])
    root.toastAndClose("Copied " + row.label)
  }

  // Tab, or → at the end of the query, on a folder: list what is inside it.
  function completeFolder(row) {
    if (!row || row.kind !== "file" || row.mime !== "inode/directory") return false
    root.setFilter(FileSearch.compressHome(row.filePath, root.homeDir) + "/")
    return true
  }

  readonly property string emptyMessage: {
    if (root.inEmojiView && emojiSource.failed) return "No emoji data at " + emojiSource.path
    if (root.inClipboardView && clipboardSource.history.length === 0) return "Clipboard history is empty"
    if (root.inFileView) {
      if (!root.filterText.trim()) return "Type a file name, or a path like ~/Documents/"
      if (fileDebounce.running || fileSearchProc.running) return "Searching…"
    }
    return ""
  }

  Process {
    id: clipProc
    property string payload: ""
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      clipProc.write(clipProc.payload)
      clipProc.stdinEnabled = false
    }
  }

  // One process rather than a FileView per file: the set is small, read once
  // at startup and again on refresh(), and this keeps the whole scan in a
  // single place that is easy to reason about.
  Process {
    id: pluginScanProc
    command: ["bash", "-c",
      'dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/menu-plugins"; '
      + '[ -d "$dir" ] || { echo "[]"; exit 0; }; '
      + 'for f in "$dir"/*.js; do [ -f "$f" ] || continue; '
      + 'jq -n --arg path "$f" --rawfile source "$f" \'{path:$path, source:$source}\'; '
      + 'done | jq -sc .']
    stdout: StdioCollector { id: pluginScanOut; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) root.mergeUserAnswerPlugins(pluginScanOut.text)
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
    path: root.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.defaultMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: root.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.userMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onLoadFailed: { root.userMenuItems = []; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- guards
  //
  // `when:` (visibility) and `checked:` (✓ marker) are bash expressions the
  // shell wasn't allowed to evaluate before the perf rewrite. Now the shell
  // batches them into one bash subprocess per (re)load so the open path
  // never has to wait on them.

  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property bool guardsPending: false

  function evaluateGuards() {
    // Process ignores a command change while it is running, and `collected`
    // belongs to the run in flight, so a second evaluation cannot overwrite
    // the first: it would throw away the lines already read and never start.
    // The surviving tail then lands as the whole answer, and every id lost
    // with it goes back to showing, since a `when:` only hides on an explicit
    // false. Wait for the run in flight and evaluate once it lands instead.
    if (guardProc.running) {
      root.guardsPending = true
      return
    }
    root.guardsPending = false

    var script = MenuModel.guardScript(root.items)
    if (!script) {
      root.whenResults = ({})
      root.checkedResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      // A batch that was killed rather than finished has only told us about
      // the rows it reached, and a row whose `when:` went unanswered shows.
      // Keep the last complete set rather than let a half-read one through.
      // A signal leaves the exit code at 0, so the status is what tells us.
      if (exitCode !== 0 || exitStatus !== 0) {
        if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
      }
      root.whenResults = nextWhen
      root.checkedResults = nextChecked
      if (root.opened) root.rebuildDisplay()
      // Run the evaluation that had to stand aside. Deferred by a turn so the
      // process is settled before its command is set again.
      if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
    }
  }
  PanelWindow {
    id: panel
    visible: root.opened && root.rowsLoaded
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // No scrim: the launcher floats over the desktop on its shadow alone.
    // Clicking anywhere outside it still closes it.
    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    RectangularShadow {
      x: card.x
      y: card.y + menuAppearance.shadowOffset
      width: card.width
      height: card.height
      radius: card.radius
      blur: menuAppearance.shadowBlur
      color: menuAppearance.shadow
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.cardTop
      color: root.background
      borderSpec: root.borderSpec

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        z: root.deleteConfirmOpen ? 20 : 0

        ConfirmDialog {
          id: deleteConfirm

          anchors.fill: parent
          opened: root.deleteConfirmOpen
          z: 10
          message: (root.deleteTarget && root.deleteTarget.kind === "clip")
            ? "Remove this entry from clipboard history?"
            : "Do you want to uninstall " + ((root.deleteTarget && root.deleteTarget.label) || "") + "?"
          confirmText: (root.deleteTarget && root.deleteTarget.kind === "clip") ? "Remove" : "Uninstall"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelDelete()
          onConfirmed: root.confirmDelete()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.borderTop
        anchors.rightMargin: card.borderRight
        anchors.bottomMargin: card.borderBottom
        anchors.leftMargin: card.borderLeft

        SearchBar {
          id: searchBar
          width: parent.width
          height: menuAppearance.searchBarHeight
          appearance: menuAppearance
          launcher: menuState
          placeholder: root.searchPlaceholder
          showBack: !root.dmenuActive && root.activeMenu !== "root"
          keyHandler: root.handleSearchKey
          keyReleaseHandler: root.handleSearchKeyRelease
          onTextEdited: function(text) { root.setFilter(text) }
          onBackRequested: {
            root.goBack()
            searchBar.focusInput()
          }
        }

        LoadingBar {
          width: parent.width
          height: Style.spacing.hairline
          visible: root.mode !== "input"
          appearance: menuAppearance
          loading: providerProc.running || answerProc.running || fileSearchProc.running
        }

        Item {
          width: parent.width
          height: root.contentSpacing
        }

        Item {
          x: menuAppearance.listInset
          width: parent.width - menuAppearance.listInset * 2
          height: root.visibleRowsHeight

          ListView {
            id: resultList
            visible: !root.inEmojiView
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.detailShown ? Math.round(parent.width * 0.45) : parent.width
            model: displayModel
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: SectionHeader {
              appearance: menuAppearance
            }

            delegate: ListRow {
              appearance: menuAppearance
              launcher: menuState
              appLibrary: root.appLibrary
              onPointerMoved: function(index, item, mouse) {
                root.hoverFromPointer(index, item, mouse)
              }
              onPointerLeft: function(index) {
                root.clearHover(index)
              }
              onActivated: function(index) {
                root.cursorActive = true
                root.selectedIndex = index
                root.activateIndex(index, true)
              }
            }
          }

          EmojiGrid {
            id: emojiGrid
            visible: root.inEmojiView
            anchors.fill: parent
            appearance: menuAppearance
            launcher: menuState
            onPointerMoved: function(index, item, mouse) {
              root.hoverFromPointer(index, item, mouse)
            }
            onPointerLeft: function(index) {
              root.clearHover(index)
            }
            onActivated: function(index) {
              root.cursorActive = true
              root.selectedIndex = index
              root.activateIndex(index, true)
            }
          }

          ScrollFades {
            anchors.fill: root.inEmojiView ? emojiGrid : resultList
            list: root.inEmojiView ? emojiGrid : resultList
            background: root.background
          }

          Rectangle {
            visible: root.detailShown
            x: resultList.width + menuAppearance.listInset
            width: Style.spacing.hairline
            height: parent.height
            color: menuAppearance.divider
          }

          DetailPane {
            visible: root.detailShown
            x: resultList.width + menuAppearance.listInset + Style.spacing.hairline
            width: parent.width - x
            height: parent.height
            appearance: menuAppearance
            details: root.selectedDetails
          }

          EmptyState {
            anchors.centerIn: parent
            visible: displayModel.count === 0 && root.mode !== "input"
            appearance: menuAppearance
            filterText: root.filterText
            message: root.emptyMessage
          }
        }

        Item {
          width: parent.width
          height: 0
        }
      }

      Footer {
        id: footer
        visible: root.mode !== "input"
        anchors.left: parent.left
        anchors.leftMargin: card.borderLeft
        anchors.right: parent.right
        anchors.rightMargin: card.borderRight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: card.borderBottom
        height: menuAppearance.footerHeight
        appearance: menuAppearance
        contextTitle: root.footerTitle
        contextGlyph: (!root.dmenuActive && root.item(root.activeMenu)) ? (root.item(root.activeMenu).icon || "") : ""
        contextId: root.activeMenu
        primaryTitle: root.selectedActions.length > 0 ? root.selectedActions[0].title : ""
        primaryKeycaps: ["↵"]
        hasMoreActions: root.selectedActions.length > 1
        panelKeycaps: Actions.keycaps(Actions.TOGGLE_PANEL[0])
        panelOpen: root.actionPanelOpen
        toastText: root.toastText
        onPrimaryClicked: if (root.selectedActions.length > 0) root.runRowAction(root.selectedActions[0])
        onActionsClicked: root.toggleActionPanel()
      }

      // While the panel is open, a click anywhere else in the card closes it
      // rather than reaching the row or button underneath.
      MouseArea {
        anchors.fill: parent
        z: 5
        visible: root.actionPanelOpen
        onClicked: root.closeActionPanel()
      }

      ActionPanel {
        id: actionPanel
        z: 6
        appearance: menuAppearance
        open: root.actionPanelOpen
        actions: root.selectedActions
        width: Math.min(implicitWidth, card.width - menuAppearance.listInset * 2)
        height: Math.min(implicitHeight, Math.round(card.height * 0.6))
        anchors.right: parent.right
        anchors.rightMargin: card.borderRight + menuAppearance.listInset
        anchors.bottom: footer.top
        anchors.bottomMargin: Style.space(6)
        keyHandler: function(event) {
          if (!Actions.matchesAny(event, Actions.TOGGLE_PANEL)) return false
          root.closeActionPanel()
          return true
        }
        onTriggered: function(action) { root.runRowAction(action) }
        onDismissed: root.closeActionPanel()
      }
    }
  }
}
