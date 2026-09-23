import QtQuick
import qs.Commons

// The launcher's search field: a back chevron while inside a submenu, then a
// real TextInput, so the query has a cursor, selection, paste and IME.
//
// The input keeps focus the whole time the launcher is open. Every key is
// offered to keyHandler first, which takes the ones that drive the list
// (arrows, Enter, Escape, Backspace on an empty query); anything it declines
// is ordinary text editing and goes to the input.
Item {
  id: bar

  required property Appearance appearance
  required property LauncherState launcher
  property string placeholder: ""
  property bool showBack: false
  // function(event, input) -> bool. True when the key was handled.
  property var keyHandler: null
  // function(event), for releases (letting go of Ctrl ends quick access).
  property var keyReleaseHandler: null

  signal textEdited(string text)
  signal backRequested()

  function focusInput() {
    input.forceActiveFocus()
  }

  Text {
    id: back
    visible: bar.showBack
    textFormat: Text.PlainText
    text: "󰅁"
    color: bar.appearance.foreground
    opacity: backArea.containsMouse ? 1 : 0.6
    font.family: bar.appearance.fontFamily
    font.pixelSize: bar.appearance.searchFontSize
    anchors.left: parent.left
    anchors.leftMargin: bar.appearance.contentMargin - Style.space(4)
    anchors.verticalCenter: parent.verticalCenter

    MouseArea {
      id: backArea
      anchors.fill: parent
      anchors.margins: -Style.space(6)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: bar.backRequested()
    }
  }

  TextInput {
    id: input
    anchors.left: back.visible ? back.right : parent.left
    anchors.leftMargin: back.visible ? Style.space(8) : bar.appearance.contentMargin
    anchors.right: parent.right
    anchors.rightMargin: bar.appearance.contentMargin
    anchors.verticalCenter: parent.verticalCenter
    color: bar.appearance.foreground
    selectionColor: Util.alpha(bar.appearance.foreground, 0.25)
    selectedTextColor: bar.appearance.foreground
    font.family: bar.appearance.fontFamily
    font.pixelSize: bar.appearance.searchFontSize
    clip: true
    activeFocusOnTab: false

    Text {
      anchors.fill: parent
      verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText
      visible: !input.text && !input.preeditText
      text: bar.placeholder
      color: bar.appearance.foreground
      opacity: 0.45
      font: input.font
      elide: Text.ElideRight
    }

    onTextEdited: bar.textEdited(text)

    Keys.onPressed: function(event) {
      if (bar.keyHandler && bar.keyHandler(event, input)) event.accepted = true
    }
    Keys.onReleased: function(event) {
      if (bar.keyReleaseHandler) bar.keyReleaseHandler(event)
    }
  }

  // The query also changes from outside: Escape clears it, entering a
  // submenu resets it. Mirror those into the input without echoing them back.
  Connections {
    target: bar.launcher
    function onFilterTextChanged() {
      if (input.text !== bar.launcher.filterText) input.text = bar.launcher.filterText
    }
  }
}
