import QtQuick
import qs.Commons

// "Open Application ↵" / "Actions Ctrl B" in the footer. Clickable, with a
// hover fill; `highlighted` brightens the label for the primary action.
Item {
  id: button

  required property Appearance appearance
  property string label: ""
  property var keycaps: []
  property bool highlighted: false
  property bool pressedLook: false

  readonly property bool hovered: area.containsMouse

  signal clicked()

  implicitWidth: row.implicitWidth + Style.space(16)
  implicitHeight: Style.space(28)

  Rectangle {
    anchors.fill: parent
    visible: button.hovered || button.pressedLook
    radius: Math.min(button.appearance.cornerRadius, Style.space(6))
    color: button.appearance.hoverBackground
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: button.label
      color: button.highlighted ? button.appearance.foreground : button.appearance.muted
      font.family: button.appearance.fontFamily
      font.pixelSize: button.appearance.accessoryFontSize
    }

    Keycaps {
      anchors.verticalCenter: parent.verticalCenter
      appearance: button.appearance
      tokens: button.keycaps
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
