import QtQuick
import QtQuick.Effects
import qs.Commons

// The action panel (Ctrl+B): every action for the selected row, in a popover
// over the bottom-right of the list, above the footer. It has its own filter
// field, which takes the keyboard while the panel is open. Enter runs, Esc
// or Ctrl+B closes, and typing narrows the list.
Item {
  id: panel

  required property Appearance appearance
  // [{ id, title, icon, keys, danger }]
  property var actions: []
  property bool open: false

  // function(event) -> bool, for keys the panel itself doesn't handle
  // (Ctrl+B to close).
  property var keyHandler: null

  signal triggered(var action)
  signal dismissed()

  property string filter: ""
  property int selectedIndex: 0
  property int hoveredIndex: -1

  readonly property var visibleActions: {
    var needle = panel.filter.trim().toLowerCase()
    if (!needle) return panel.actions
    return panel.actions.filter(function(a) { return a.title.toLowerCase().indexOf(needle) >= 0 })
  }
  readonly property int rowHeight: Style.space(32)
  readonly property int filterHeight: Style.space(40)
  readonly property int listPadding: Style.space(6)

  // Reset and take the keyboard. The owner sets `open`.
  function show() {
    filterInput.text = ""
    panel.filter = ""
    panel.selectedIndex = 0
    panel.hoveredIndex = -1
    filterInput.forceActiveFocus()
  }

  function runSelected() {
    if (panel.selectedIndex >= 0 && panel.selectedIndex < panel.visibleActions.length)
      panel.triggered(panel.visibleActions[panel.selectedIndex])
  }

  visible: open
  implicitWidth: appearance.actionPanelWidth
  implicitHeight: Math.max(1, visibleActions.length) * rowHeight + listPadding * 2 + Style.spacing.hairline + filterHeight

  RectangularShadow {
    anchors.fill: surface
    anchors.topMargin: Style.space(4)
    radius: surface.radius
    blur: Style.space(20)
    color: panel.appearance.shadow
  }

  Rectangle {
    id: surface
    anchors.fill: parent
    radius: panel.appearance.cornerRadius
    color: panel.appearance.popoverBackground
    border.width: 1
    border.color: Util.alpha(panel.appearance.foreground, 0.12)

    // Swallow clicks between rows so they don't reach the list below.
    MouseArea { anchors.fill: parent }

    Column {
      anchors.fill: parent
      anchors.margins: 1

      Item {
        width: parent.width
        height: Math.max(1, panel.visibleActions.length) * panel.rowHeight + panel.listPadding * 2

        Text {
          anchors.centerIn: parent
          visible: panel.visibleActions.length === 0
          textFormat: Text.PlainText
          text: "No actions"
          color: panel.appearance.muted
          font.family: panel.appearance.fontFamily
          font.pixelSize: panel.appearance.accessoryFontSize
        }

        Column {
          y: panel.listPadding
          width: parent.width

          Repeater {
            model: panel.visibleActions

            delegate: Item {
              id: actionRow
              required property var modelData
              required property int index

              readonly property bool selected: index === panel.selectedIndex
              readonly property color textColor: modelData.danger
                ? Color.urgent
                : (selected ? panel.appearance.selectedText : panel.appearance.foreground)

              width: parent.width
              height: panel.rowHeight

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: panel.listPadding
                anchors.rightMargin: panel.listPadding
                radius: panel.appearance.cornerRadius
                color: actionRow.selected
                  ? panel.appearance.selectedBackground
                  : (actionRow.index === panel.hoveredIndex ? panel.appearance.hoverBackground : "transparent")
              }

              Text {
                id: actionIcon
                anchors.left: parent.left
                anchors.leftMargin: panel.listPadding + Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: actionRow.modelData.icon || ""
                color: actionRow.textColor
                font.family: panel.appearance.fontFamily
                font.pixelSize: panel.appearance.rowFontSize
              }

              Text {
                anchors.left: actionIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.right: caps.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: actionRow.modelData.title
                color: actionRow.textColor
                font.family: panel.appearance.fontFamily
                font.pixelSize: panel.appearance.accessoryFontSize + 1
                elide: Text.ElideRight
              }

              Keycaps {
                id: caps
                anchors.right: parent.right
                anchors.rightMargin: panel.listPadding + Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                appearance: panel.appearance
                tokens: actionRow.modelData.keycaps || []
                contentColor: actionRow.selected ? panel.appearance.selectedText : panel.appearance.foreground
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: panel.hoveredIndex = actionRow.index
                onExited: if (panel.hoveredIndex === actionRow.index) panel.hoveredIndex = -1
                onClicked: {
                  panel.selectedIndex = actionRow.index
                  panel.runSelected()
                }
              }
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: panel.appearance.divider
      }

      Item {
        width: parent.width
        height: panel.filterHeight

        TextInput {
          id: filterInput
          anchors.left: parent.left
          anchors.leftMargin: panel.listPadding + Style.space(10)
          anchors.right: parent.right
          anchors.rightMargin: panel.listPadding + Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          color: panel.appearance.foreground
          selectionColor: Util.alpha(panel.appearance.foreground, 0.25)
          selectedTextColor: panel.appearance.foreground
          font.family: panel.appearance.fontFamily
          font.pixelSize: panel.appearance.accessoryFontSize + 1
          clip: true
          activeFocusOnTab: false

          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            visible: !filterInput.text && !filterInput.preeditText
            text: "Search actions…"
            color: panel.appearance.muted
            font: filterInput.font
          }

          onTextEdited: {
            panel.filter = text
            panel.selectedIndex = 0
          }

          Keys.onPressed: function(event) {
            var count = panel.visibleActions.length
            if (event.key === Qt.Key_Escape) {
              panel.dismissed()
            } else if (event.key === Qt.Key_Up) {
              if (count > 0) panel.selectedIndex = (panel.selectedIndex - 1 + count) % count
            } else if (event.key === Qt.Key_Down) {
              if (count > 0) panel.selectedIndex = (panel.selectedIndex + 1) % count
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              panel.runSelected()
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              // Keep focus in the panel.
            } else if (panel.keyHandler && panel.keyHandler(event)) {
              // Handled by the owner.
            } else {
              return
            }
            event.accepted = true
          }
        }
      }
    }
  }
}
