import QtQuick
import qs.Commons
import qs.Ui

// The Search Emojis view, laid out like vicinae's EmojiGridView: square
// cells in sections, a header above each. launcher.emojiLines comes from
// EmojiSearch.lines(). A cell's number is its row in the launcher's flat
// model, so selection, actions and the footer treat it like any list row.
ListView {
  id: grid

  required property Appearance appearance
  required property LauncherState launcher
  property int columns: 8
  readonly property int cellSize: Math.floor(width / columns)

  // Same contract as ListRow's: the owner decides what hover and clicks do.
  signal pointerMoved(int index, var item, var mouse)
  signal pointerLeft(int index)
  signal activated(int index)

  model: grid.launcher.emojiLines
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  delegate: Item {
    id: line

    required property var modelData
    readonly property bool isHeader: line.modelData.header !== undefined

    width: grid.width
    height: line.isHeader ? grid.appearance.sectionHeaderHeight : grid.cellSize

    SectionHeader {
      visible: line.isHeader
      appearance: grid.appearance
      section: line.isHeader ? line.modelData.header : ""
    }

    Row {
      visible: !line.isHeader

      Repeater {
        model: line.isHeader ? [] : line.modelData.glyphs

        delegate: Item {
          id: cell

          required property string modelData
          required property int index
          readonly property int cellIndex: line.modelData.start + cell.index
          readonly property bool hasCursor: grid.launcher.cursorActive && cell.cellIndex === grid.launcher.selectedIndex
          readonly property bool hovered: !cell.hasCursor && cell.cellIndex === grid.launcher.hoveredIndex && mouseArea.containsMouse

          width: grid.cellSize
          height: grid.cellSize

          BorderSurface {
            anchors.fill: parent
            anchors.margins: Style.space(3)
            radius: grid.appearance.cornerRadius
            color: cell.hasCursor ? grid.appearance.selectedBackground : (cell.hovered ? grid.appearance.hoverBackground : "transparent")
            borderSpec: cell.hasCursor ? grid.appearance.selectedBorderSpec : Border.none()
          }

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: cell.modelData
            font.family: grid.appearance.fontFamily
            font.pixelSize: Math.round(grid.cellSize * 0.46)
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: grid.pointerMoved(cell.cellIndex, cell, { x: mouseArea.mouseX, y: mouseArea.mouseY })
            onPositionChanged: function(mouse) { grid.pointerMoved(cell.cellIndex, cell, mouse) }
            onExited: grid.pointerLeft(cell.cellIndex)
            onClicked: grid.activated(cell.cellIndex)
          }
        }
      }
    }
  }
}
