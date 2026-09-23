import QtQuick
import qs.Commons

// A small caption pill, tinted from its text color: 8% fill, 14% border.
Rectangle {
  id: badge

  required property Appearance appearance
  property string text: ""
  property color contentColor: appearance.muted

  implicitWidth: label.implicitWidth + Style.space(12)
  implicitHeight: Style.space(20)
  radius: Math.min(appearance.cornerRadius, Style.space(6))
  color: Util.alpha(contentColor, 0.08)
  border.width: 1
  border.color: Util.alpha(contentColor, 0.14)

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, badge.width - Style.space(12))
    textFormat: Text.PlainText
    text: badge.text
    color: badge.contentColor
    font.family: badge.appearance.fontFamily
    font.pixelSize: Style.font.caption
    font.weight: Font.Medium
    elide: Text.ElideRight
  }
}
