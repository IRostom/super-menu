import QtQuick
import qs.Commons

// Details beside the list, vicinae's split detail view: Ctrl+D on an app, and
// always in the clipboard and file views. A header (icon and name) when there
// is a name, an image or text preview when there is one, then label/value
// pairs. Menu.qml builds `details` for each kind of row.
Item {
  id: pane

  required property Appearance appearance
  // { name, subtitle, comment, iconSource, glyph, hueId, previewImage,
  //   previewText, fields: [{ label, value }] } or null
  property var details: null

  readonly property bool hasHeader: !!(pane.details && pane.details.name)
  readonly property string previewImage: pane.details ? pane.details.previewImage : ""
  readonly property string previewText: pane.details ? pane.details.previewText : ""

  clip: true

  // Height a preview starting at `y` can take and still leave the fields
  // below it on screen.
  function previewRoom(y) {
    return content.height - y - content.spacing - meta.implicitHeight
  }

  Column {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(14)
    visible: pane.details !== null

    Row {
      width: parent.width
      spacing: Style.space(12)
      visible: pane.hasHeader

      IconTile {
        id: bigIcon
        width: Style.space(48)
        height: Style.space(48)
        appearance: pane.appearance
        imageSource: pane.details ? pane.details.iconSource : ""
        glyph: pane.details ? pane.details.glyph : ""
        hue: pane.appearance.hueFor(pane.details ? pane.details.hueId : "")
      }

      Column {
        anchors.verticalCenter: bigIcon.verticalCenter
        width: parent.width - bigIcon.width - parent.spacing
        spacing: Style.space(2)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: pane.details ? pane.details.name : ""
          color: pane.appearance.foreground
          font.family: pane.appearance.fontFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text.length > 0
          textFormat: Text.PlainText
          text: pane.details ? pane.details.subtitle : ""
          color: pane.appearance.muted
          font.family: pane.appearance.fontFamily
          font.pixelSize: pane.appearance.accessoryFontSize
          elide: Text.ElideRight
        }
      }
    }

    Text {
      width: parent.width
      visible: text.length > 0
      textFormat: Text.PlainText
      text: pane.details ? pane.details.comment : ""
      color: pane.appearance.foreground
      opacity: 0.8
      font.family: pane.appearance.fontFamily
      font.pixelSize: pane.appearance.accessoryFontSize + 1
      wrapMode: Text.Wrap
      maximumLineCount: 4
      elide: Text.ElideRight
    }

    Image {
      id: previewImageItem
      width: parent.width
      height: Math.max(0, Math.min(Math.round(pane.height * 0.5), pane.previewRoom(previewImageItem.y)))
      visible: pane.previewImage.length > 0
      source: pane.previewImage
      fillMode: Image.PreserveAspectFit
      horizontalAlignment: Image.AlignLeft
      sourceSize.width: width * Screen.devicePixelRatio
      sourceSize.height: height * Screen.devicePixelRatio
      asynchronous: true
    }

    // Clipboard text as it was copied: monospace, line breaks kept. It takes
    // what the fields below leave, and clips the rest.
    Rectangle {
      id: previewTextBox
      width: parent.width
      height: Math.max(0, Math.min(previewTextItem.implicitHeight + Style.space(20), pane.previewRoom(previewTextBox.y)))
      visible: pane.previewText.length > 0
      radius: Math.min(pane.appearance.cornerRadius, Style.space(8))
      color: Util.alpha(pane.appearance.foreground, 0.04)
      clip: true

      Text {
        id: previewTextItem
        x: Style.space(10)
        y: Style.space(10)
        width: parent.width - Style.space(20)
        textFormat: Text.PlainText
        text: pane.previewText
        color: pane.appearance.foreground
        font.family: Style.font.family
        font.pixelSize: pane.appearance.accessoryFontSize
        wrapMode: Text.WrapAnywhere
      }
    }

    Column {
      id: meta
      width: parent.width
      spacing: content.spacing

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: pane.appearance.divider
      }

      Repeater {
        model: pane.details ? pane.details.fields : []

        delegate: Column {
          required property var modelData
          width: parent.width
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            text: parent.modelData.label
            color: pane.appearance.muted
            font.family: pane.appearance.fontFamily
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: parent.modelData.value
            color: pane.appearance.foreground
            font.family: pane.appearance.fontFamily
            font.pixelSize: pane.appearance.accessoryFontSize
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
