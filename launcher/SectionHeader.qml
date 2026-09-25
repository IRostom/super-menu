import QtQuick
import qs.Commons

// The label above each group of rows: Favorites, Suggestions, Results, and
// so on. Rows with no section ("") get no header at all.
Item {
  id: header

  required property string section
  required property Appearance appearance

  // Inside the emoji grid it is a line's child, not the delegate itself, and
  // has no ListView attached.
  width: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
  height: section ? appearance.sectionHeaderHeight : 0
  visible: section.length > 0

  Text {
    anchors.left: parent.left
    anchors.leftMargin: header.appearance.rowPaddingX
    anchors.right: parent.right
    anchors.rightMargin: header.appearance.rowPaddingX
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(6)
    textFormat: Text.PlainText
    text: header.section
    color: header.appearance.muted
    font.family: header.appearance.fontFamily
    font.pixelSize: header.appearance.accessoryFontSize
    font.weight: Font.DemiBold
    elide: Text.ElideRight
  }
}
