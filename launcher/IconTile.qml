import QtQuick
import qs.Commons

// A row's icon. An app shows its own icon as it is. A glyph sits on a tile
// tinted with its menu's hue, the way Raycast gives each command a colored
// square. Corners follow the system radius like everything else.
Item {
  id: tile

  required property Appearance appearance
  property string glyph: ""
  property string glyphFont: ""
  property url imageSource: ""
  property color hue: "transparent"

  implicitWidth: appearance.iconSize
  implicitHeight: appearance.iconSize

  Rectangle {
    anchors.fill: parent
    visible: tile.imageSource.toString() === "" && tile.glyph.length > 0
    radius: Math.min(tile.appearance.cornerRadius, Math.round(tile.width / 4))
    color: Util.alpha(tile.hue, 0.18)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tile.glyph
      color: tile.hue
      font.family: tile.glyphFont.length > 0 ? tile.glyphFont : tile.appearance.fontFamily
      font.pixelSize: Math.round(tile.width * 0.62)
    }
  }

  Image {
    anchors.fill: parent
    visible: tile.imageSource.toString() !== ""
    source: tile.imageSource
    fillMode: Image.PreserveAspectFit
    // Decode at physical pixels — a logical-size decode leaves PNG icons
    // upscaled and blurry on HiDPI displays.
    sourceSize.width: width * Screen.devicePixelRatio
    sourceSize.height: height * Screen.devicePixelRatio
    asynchronous: true
  }
}
