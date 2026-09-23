import QtQuick
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
  property int baseRowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int detailRowHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int answerRowHeight: Math.max(Style.space(66), Style.font.display + Style.font.bodySmall + Style.spacing.rowPaddingX * 2)
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: Style.spacing.xs
  property int dividerHeight: Style.space(17)

  // A row grows to fit its detail line only when the detail is shown, which
  // is while searching and in dmenu mode.
  function rowHeightFor(detail, kind, expanded) {
    if (kind === "answer") return appearance.answerRowHeight
    return expanded && detail ? appearance.detailRowHeight : appearance.baseRowHeight
  }
}
