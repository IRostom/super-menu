import QtQuick
import qs.Commons

// The status bar along the bottom of the launcher: where you are on the left,
// what Enter does and how to reach the other actions on the right.
Item {
  id: footer

  required property Appearance appearance
  property string contextTitle: ""
  property string contextGlyph: ""
  property string contextId: ""
  property string primaryTitle: ""
  property var primaryKeycaps: []
  property bool hasMoreActions: false
  property var panelKeycaps: []
  property bool panelOpen: false
  // When set, the toast replaces the context on the left.
  property string toastText: ""

  signal primaryClicked()
  signal actionsClicked()

  implicitHeight: appearance.footerHeight

  // Rounded at the bottom only, to sit inside the card's own corners: a
  // rounded rect for the whole footer, squared off along the top.
  Rectangle {
    anchors.fill: parent
    radius: footer.appearance.cornerRadius
    color: footer.appearance.footerBackground
  }

  Rectangle {
    width: parent.width
    height: Math.max(0, parent.height - footer.appearance.cornerRadius)
    color: footer.appearance.footerBackground
  }

  Rectangle {
    anchors.top: parent.top
    width: parent.width
    height: Style.spacing.hairline
    color: footer.appearance.divider
  }

  Row {
    visible: footer.toastText.length > 0
    anchors.left: parent.left
    anchors.leftMargin: footer.appearance.listInset + footer.appearance.rowPaddingX
    anchors.right: buttons.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)
    clip: true

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(10)
      height: width
      radius: width / 2
      color: footer.appearance.success
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: footer.toastText
      color: footer.appearance.foreground
      font.family: footer.appearance.fontFamily
      font.pixelSize: footer.appearance.accessoryFontSize
      elide: Text.ElideRight
    }
  }

  Row {
    visible: footer.toastText.length === 0
    anchors.left: parent.left
    anchors.leftMargin: footer.appearance.listInset + footer.appearance.rowPaddingX
    anchors.right: buttons.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)
    clip: true

    IconTile {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(18)
      height: Style.space(18)
      visible: footer.contextGlyph.length > 0
      appearance: footer.appearance
      glyph: footer.contextGlyph
      hue: footer.appearance.hueFor(footer.contextId)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: footer.contextTitle
      color: footer.appearance.muted
      font.family: footer.appearance.fontFamily
      font.pixelSize: footer.appearance.accessoryFontSize
      elide: Text.ElideRight
    }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: footer.appearance.listInset + Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    FooterButton {
      id: primaryButton
      anchors.verticalCenter: parent.verticalCenter
      visible: footer.primaryTitle.length > 0
      appearance: footer.appearance
      label: footer.primaryTitle
      keycaps: footer.primaryKeycaps
      highlighted: true
      onClicked: footer.primaryClicked()
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: primaryButton.visible && actionsButton.visible
      width: Style.spacing.hairline
      height: Style.space(12)
      color: footer.appearance.muted
      opacity: primaryButton.hovered || actionsButton.hovered || footer.panelOpen ? 0 : 0.5
    }

    FooterButton {
      id: actionsButton
      anchors.verticalCenter: parent.verticalCenter
      visible: footer.hasMoreActions
      appearance: footer.appearance
      label: "Actions"
      keycaps: footer.panelKeycaps
      highlighted: footer.panelOpen
      pressedLook: footer.panelOpen
      onClicked: footer.actionsClicked()
    }
  }
}
