import QtQuick
import qs.Commons
import qs.Ui

// One result row, laid out like vicinae's ListItemDelegate: icon tile, title
// with its subtitle inline on the same baseline, and a type label on the
// right. Query-plugin answers keep a taller layout with the value large.
//
// Selection (keyboard) and hover (pointer) are separate fills: pointing at a
// row highlights it without moving the cursor that Enter acts on.
BorderSurface {
  id: row

  required property int index
  required property string itemId
  required property string kind
  required property string icon
  required property string iconFont
  required property string appIcon
  required property string label
  required property string detail

  required property Appearance appearance
  required property LauncherState launcher
  property var appLibrary: null

  // The pointer moved over the row or left it, or the row was clicked. The
  // owner decides what that does to hover and selection.
  signal pointerMoved(int index, var item, var mouse)
  signal pointerLeft(int index)
  signal activated(int index)

  readonly property bool hasCursor: row.launcher.cursorActive && row.index === row.launcher.selectedIndex
  readonly property bool hovered: !row.hasCursor && row.index === row.launcher.hoveredIndex && mouseArea.containsMouse
  readonly property bool isApp: row.kind === "app"
  readonly property bool isAnswer: row.kind === "answer"
  readonly property color textColor: row.hasCursor ? row.appearance.selectedText : row.appearance.foreground
  readonly property string accessory: {
    if (row.kind === "app") return "Application"
    if (row.kind === "menu" || row.kind === "link") return "Menu"
    if (row.kind === "action") return "Command"
    return ""
  }

  width: ListView.view.width
  height: row.appearance.rowHeightFor(row.kind)
  radius: row.appearance.cornerRadius
  color: row.hasCursor ? row.appearance.selectedBackground : (row.hovered ? row.appearance.hoverBackground : "transparent")
  borderSpec: row.hasCursor ? row.appearance.selectedBorderSpec : Border.none()

  IconTile {
    id: iconTile
    appearance: row.appearance
    anchors.left: parent.left
    anchors.leftMargin: row.appearance.rowReservedBorderLeft + row.appearance.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    glyph: row.isApp ? "" : row.icon
    glyphFont: row.iconFont
    imageSource: row.isApp && row.appLibrary ? row.appLibrary.iconSource(row.appIcon) : ""
    hue: row.appearance.hueFor(row.itemId)
  }

  // --- ordinary rows: title · subtitle ······ accessory ----------------
  Item {
    id: textRow
    visible: !row.isAnswer
    anchors.left: iconTile.right
    anchors.leftMargin: Style.space(10)
    anchors.right: accessoryText.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    height: titleText.implicitHeight

    readonly property real gap: Style.space(8)
    // The subtitle may claim up to half the width before the title starts
    // eliding; after that the title keeps the rest.
    readonly property real subtitleReserved: subtitleText.text ? Math.min(subtitleText.implicitWidth + gap, width * 0.5) : 0

    Text {
      id: titleText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, textRow.width - textRow.subtitleReserved)
      textFormat: Text.PlainText
      text: row.label
      color: row.textColor
      font.family: row.appearance.fontFamily
      font.pixelSize: row.appearance.rowFontSize
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    Text {
      id: subtitleText
      anchors.left: titleText.right
      anchors.leftMargin: textRow.gap
      anchors.baseline: titleText.baseline
      width: Math.max(0, Math.min(implicitWidth, textRow.width - titleText.width - textRow.gap))
      textFormat: Text.PlainText
      text: row.detail
      color: row.hasCursor ? Util.alpha(row.appearance.selectedText, 0.6) : row.appearance.muted
      font.family: row.appearance.fontFamily
      font.pixelSize: row.appearance.rowFontSize
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  Text {
    id: accessoryText
    visible: !row.isAnswer
    anchors.right: parent.right
    anchors.rightMargin: row.appearance.rowReservedBorderRight + row.appearance.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: row.accessory
    color: row.appearance.muted
    font.family: row.appearance.fontFamily
    font.pixelSize: row.appearance.accessoryFontSize
  }

  // --- answers: the value large, what it answers underneath ------------
  Column {
    visible: row.isAnswer
    anchors.left: iconTile.right
    anchors.leftMargin: Style.space(10)
    anchors.right: copyHint.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.label
      color: row.textColor
      font.family: row.appearance.fontFamily
      // An answer is a value, not a name. Give it room.
      font.pixelSize: Style.font.display
      font.weight: Font.Medium
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: row.detail.length > 0
      textFormat: Text.PlainText
      text: row.detail
      color: row.appearance.muted
      font.family: row.appearance.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }

  Text {
    id: copyHint
    visible: row.isAnswer
    anchors.right: parent.right
    anchors.rightMargin: row.appearance.rowReservedBorderRight + row.appearance.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    // nf-md-content_copy, saying what Enter will do.
    text: "󰆏"
    color: row.appearance.muted
    font.family: row.appearance.fontFamily
    font.pixelSize: Style.font.heading
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
    onExited: row.pointerLeft(row.index)
    onClicked: row.activated(row.index)
  }
}
