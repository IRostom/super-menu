import QtQuick
import qs.Commons
import qs.Ui

// One result row: icon (glyph or app icon), label, optional detail line and
// a trailing hint for what Enter does. Model roles arrive as required
// properties; everything else is passed in by the list.
BorderSurface {
  id: row

  required property int index
  required property string itemId
  required property string kind
  required property string icon
  required property string iconFont
  required property string appIcon
  required property string appId
  required property string label
  required property string target
  required property string detail
  required property string path
  required property string action
  required property string actionArgv
  required property string copyText
  required property int childCount

  required property Appearance appearance
  required property LauncherState launcher
  property var appLibrary: null

  // The pointer moved over the row, or it was clicked. The owner decides
  // whether that moves the cursor or runs the row.
  signal pointerMoved(int index, var item, var mouse)
  signal activated(int index)

  readonly property bool hasCursor: row.launcher.cursorActive && row.index === row.launcher.selectedIndex
  readonly property bool isApp: row.kind === "app"
  readonly property bool hasIcon: row.icon.length > 0 || row.isApp

  width: ListView.view.width
  height: row.appearance.rowHeightFor(row.detail, row.kind, row.launcher.filterText || row.launcher.dmenuActive)
  radius: row.appearance.cornerRadius
  color: row.hasCursor ? row.appearance.selectedBackground : "transparent"
  borderSpec: row.hasCursor ? row.appearance.selectedBorderSpec : Border.none()

  Rectangle {
    visible: false
    width: Style.space(4)
    height: parent.height - Style.space(18)
    radius: Math.min(row.appearance.cornerRadius, Style.space(4))
    color: row.appearance.selectedBackground
    anchors.left: parent.left
    anchors.leftMargin: row.appearance.rowReservedBorderLeft + Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    id: iconText
    textFormat: Text.PlainText
    visible: row.hasIcon && !row.isApp
    text: row.icon
    color: row.hasCursor ? row.appearance.selectedText : row.appearance.foreground
    font.family: row.iconFont.length > 0 ? row.iconFont : row.appearance.fontFamily
    font.pixelSize: Style.font.iconLarge
    width: Style.space(36)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    anchors.left: parent.left
    anchors.leftMargin: row.appearance.rowReservedBorderLeft + Style.space(8)
    y: contentColumn.y + labelText.y + (labelText.height - height) / 2
  }

  Image {
    id: appIconImage
    visible: row.isApp
    width: Style.font.iconLarge
    height: Style.font.iconLarge
    fillMode: Image.PreserveAspectFit
    // Decode at physical pixels — a logical-size decode leaves
    // PNG icons upscaled and blurry on HiDPI displays.
    sourceSize.width: width * Screen.devicePixelRatio
    sourceSize.height: height * Screen.devicePixelRatio
    source: row.isApp && row.appLibrary ? row.appLibrary.iconSource(row.appIcon) : ""
    asynchronous: true
    anchors.left: parent.left
    anchors.leftMargin: row.appearance.rowReservedBorderLeft + Style.space(8) + (Style.space(36) - width) / 2
    y: contentColumn.y + labelText.y + (labelText.height - height) / 2
  }

  Column {
    id: contentColumn
    anchors.left: row.hasIcon ? iconText.right : parent.left
    anchors.leftMargin: row.hasIcon ? Style.space(6) : row.appearance.rowReservedBorderLeft + Style.space(18)
    anchors.right: trail.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)

    Text {
      id: labelText
      textFormat: Text.PlainText
      width: parent.width
      text: row.label
      color: row.hasCursor ? row.appearance.selectedText : row.appearance.foreground
      font.family: row.appearance.fontFamily
      // An answer is a value, not a name. Give it room.
      font.pixelSize: row.kind === "answer" ? Style.font.display : Style.font.heading
      font.weight: Font.Medium
      elide: Text.ElideRight
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: row.detail
      visible: (row.launcher.filterText || row.kind === "dmenu" || row.kind === "answer") && row.detail.length > 0
      color: row.appearance.foreground
      opacity: 0.52
      font.family: row.appearance.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }

  Row {
    id: trail
    width: Style.space(14)
    anchors.right: parent.right
    anchors.rightMargin: row.appearance.rowReservedBorderRight + Style.space(8)
    y: contentColumn.y + labelText.y + (labelText.height - height) / 2
    spacing: 0

    Text {
      textFormat: Text.PlainText
      visible: false
      text: row.childCount
      color: row.appearance.foreground
      opacity: 0.45
      font.family: row.appearance.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      textFormat: Text.PlainText
      // nf-md-content_copy on answers, saying what Enter will do.
      text: row.kind === "answer" ? "󰆏" : (row.kind === "menu" || row.kind === "link" ? "›" : "")
      color: row.hasCursor ? row.appearance.selectedText : row.appearance.foreground
      opacity: (row.kind === "menu" || row.kind === "link" || row.kind === "answer") ? 0.36 : 0
      font.family: row.appearance.fontFamily
      font.pixelSize: Style.font.heading
      font.weight: Font.Normal
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: row.pointerMoved(row.index, row, {
      x: mouseArea.mouseX,
      y: mouseArea.mouseY
    })
    onPositionChanged: function(mouse) {
      row.pointerMoved(row.index, row, mouse)
    }
    onClicked: row.activated(row.index)
  }
}
