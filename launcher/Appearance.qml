import QtQuick
import Quickshell.Io
import qs.Commons

// Visual tokens for the launcher. Colors are bound to the central [menu]
// section in shell.toml via Color.qml. Each color already includes its alpha
// companion (composed in the singleton), so consumers can drop them straight
// into a Rectangle. Sizes derive from Style so they follow the font scale.
QtObject {
  id: appearance

  property string fontFamily: Style.font.menuFamily

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color selectedBorder: Color.menu.selectedBorder
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", selectedBorder, 0)
  readonly property real rowReservedBorderLeft: Border.left(selectedBorderSpec)
  readonly property real rowReservedBorderRight: Border.right(selectedBorderSpec)
  readonly property int cornerRadius: Style.cornerRadius

  // The launcher window. A fixed size, so typing never moves or resizes it;
  // only the list inside changes. Its top sits a third of the way down the
  // screen, the way Raycast and vicinae place it.
  property int windowWidth: Style.space(770)
  property int windowHeight: Style.space(480)
  property int searchBarHeight: Style.space(60)
  property int searchFontSize: Math.round(Style.font.heading * 1.2)
  property color divider: Util.alpha(foreground, 0.1)
  property color shadow: Qt.rgba(0, 0, 0, 0.35)
  property int shadowBlur: Style.space(28)
  property int shadowOffset: Style.space(6)

  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  // Rows sit inset from the card edge; the selection fill spans the inset
  // row, and the row's own padding keeps its content off the fill's edge.
  property int listInset: Style.space(6)
  property int rowPaddingX: Style.space(12)
  property int baseRowHeight: Style.space(38)
  property int answerRowHeight: Math.max(Style.space(66), Style.font.display + Style.font.bodySmall + Style.spacing.rowPaddingX * 2)
  property int iconSize: Style.space(26)
  property int rowFontSize: Style.font.title
  property int accessoryFontSize: Style.font.bodySmall
  property int sectionHeaderHeight: Style.space(30)
  property color muted: Util.alpha(foreground, 0.55)
  property color hoverBackground: Util.alpha(foreground, 0.05)
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: 0

  function rowHeightFor(kind) {
    return kind === "answer" ? appearance.answerRowHeight : appearance.baseRowHeight
  }

  // Icon tiles take their hue from the theme's named colors, so each
  // top-level menu keeps one color and the whole set follows
  // `omarchy theme set`. Anything unmapped hashes onto the same palette.
  readonly property var hueNames: ["blue", "yellow", "orange", "magenta", "green", "red", "cyan"]
  readonly property var groupHues: ({
    apps: "blue", learn: "yellow", trigger: "orange", style: "magenta",
    setup: "blue", install: "green", remove: "red", update: "cyan",
    about: "cyan", system: "red"
  })
  property var palette: ({})

  function hueFor(itemId) {
    var group = String(itemId || "").split(".")[0]
    var name = appearance.groupHues[group]
    if (!name) {
      var hash = 0
      for (var i = 0; i < group.length; i++) hash = (hash * 31 + group.charCodeAt(i)) | 0
      name = appearance.hueNames[Math.abs(hash) % appearance.hueNames.length]
    }
    return appearance.palette[name] || Color.accent
  }

  function loadPalette(raw) {
    var next = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([a-z_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (match) next[match[1]] = match[2]
    }
    appearance.palette = next
  }

  property FileView paletteFile: FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: appearance.loadPalette(text())
  }
}
