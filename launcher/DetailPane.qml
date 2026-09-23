import QtQuick
import qs.Commons

// App details beside the list (Ctrl+D on an app row), vicinae's split detail
// view: the icon and name up top, then what the desktop entry says about the
// app as label/value pairs.
Item {
  id: pane

  required property Appearance appearance
  // { name, genericName, comment, iconSource, command, categories,
  //   keywords, desktopId, terminal } or null
  property var details: null

  readonly property var fields: {
    var d = pane.details
    if (!d) return []
    var out = []
    if (d.command) out.push({ label: "Command", value: d.command })
    if (d.categories) out.push({ label: "Categories", value: d.categories })
    if (d.keywords) out.push({ label: "Keywords", value: d.keywords })
    out.push({ label: "Desktop ID", value: d.desktopId })
    if (d.terminal) out.push({ label: "Runs in", value: "Terminal" })
    return out
  }

  clip: true

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(14)
    visible: pane.details !== null

    Row {
      width: parent.width
      spacing: Style.space(12)

      IconTile {
        id: bigIcon
        width: Style.space(48)
        height: Style.space(48)
        appearance: pane.appearance
        imageSource: pane.details ? pane.details.iconSource : ""
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
          text: pane.details ? pane.details.genericName : ""
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

    Rectangle {
      width: parent.width
      height: Style.spacing.hairline
      color: pane.appearance.divider
    }

    Repeater {
      model: pane.fields

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
