import QtQuick
import qs.Commons

// A shortcut drawn as keycaps: ["Ctrl", "⇧", "C"]. Each cap is tinted from
// the text color (8% fill, 14% border), vicinae's ShortcutBadge.
Row {
  id: caps

  required property Appearance appearance
  property var tokens: []
  property color contentColor: appearance.foreground

  spacing: Style.space(4)

  Repeater {
    model: caps.tokens

    delegate: Rectangle {
      required property string modelData

      readonly property bool compact: modelData.length <= 2
      height: Style.space(20)
      width: Math.max(compact ? height : 0, label.implicitWidth + Style.space(compact ? 10 : 12))
      radius: Math.min(caps.appearance.cornerRadius, Style.space(6))
      color: Util.alpha(caps.contentColor, 0.08)
      border.width: 1
      border.color: Util.alpha(caps.contentColor, 0.14)

      Text {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: parent.modelData
        color: caps.contentColor
        font.family: caps.appearance.fontFamily
        font.pixelSize: Style.font.caption
        font.weight: Font.Medium
      }
    }
  }
}
