import QtQuick
import qs.Commons

// Shown in place of the list when nothing matches, or a menu has no rows.
Column {
  id: empty

  required property Appearance appearance
  property string filterText: ""
  // Overrides the default text: a view's own hint ("Clipboard history is
  // empty", "Searching…").
  property string message: ""

  spacing: Style.space(8)

  Text {
    text: "󰈉"
    color: empty.appearance.selectedText
    opacity: 0.8
    font.family: empty.appearance.fontFamily
    font.pixelSize: Style.font.displayLarge
    horizontalAlignment: Text.AlignHCenter
    width: Style.space(320)
  }

  Text {
    textFormat: Text.PlainText
    text: empty.message || (empty.filterText ? "No matches for “" + empty.filterText + "”" : "Nothing here yet")
    color: empty.appearance.foreground
    opacity: 0.7
    font.family: empty.appearance.fontFamily
    font.pixelSize: Style.font.title
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    width: Style.space(320)
  }
}
