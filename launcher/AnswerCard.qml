import QtQuick
import qs.Commons

// A query-plugin answer as a two-column card, vicinae's calculator result:
// the question on the left, the answer on the right, an arrow between, each
// captioned with a badge. Shown for rows whose plugin sent a `question`.
Item {
  id: card

  required property Appearance appearance
  property string question: ""
  property string answer: ""
  property string questionLabel: ""
  property string answerLabel: ""
  property bool selected: false

  readonly property color textColor: selected ? appearance.selectedText : appearance.foreground
  readonly property int valueSize: Math.round(appearance.rowFontSize * 1.5)

  // Operators and conversion words in the question are dimmed, so the
  // numbers and units carry the line. Naive, but good enough for a caption.
  function highlight(expr) {
    var escaped = String(expr).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    var tokens = /(\b(?:to|in|as|of|mod|and|or|xor)\b|[+\-*\/^%()=,])/gi
    return escaped.replace(tokens, function(m) { return "<font color=\"" + card.appearance.muted + "\">" + m + "</font>" })
  }

  component Side: Item {
    id: col
    property string value: ""
    property string caption: ""
    property bool styled: false
    property int weight: Font.Medium

    Text {
      width: parent.width
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -Style.space(10)
      horizontalAlignment: Text.AlignHCenter
      textFormat: col.styled ? Text.StyledText : Text.PlainText
      text: col.styled ? card.highlight(col.value) : col.value
      color: card.textColor
      font.family: card.appearance.fontFamily
      font.pixelSize: card.valueSize
      font.weight: col.weight
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    Badge {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(16)
      width: Math.min(implicitWidth, parent.width)
      appearance: card.appearance
      text: col.caption
      contentColor: card.selected ? card.appearance.selectedText : card.appearance.foreground
    }
  }

  Side {
    anchors.left: parent.left
    anchors.right: arrow.left
    anchors.rightMargin: Style.space(12)
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    value: card.question
    caption: card.questionLabel || "Expression"
    styled: true
  }

  // The rule above and below the arrow appears only on the selected card.
  Rectangle {
    visible: card.selected
    width: Style.spacing.hairline
    anchors.top: parent.top
    anchors.bottom: arrow.top
    anchors.bottomMargin: Style.space(4)
    anchors.horizontalCenter: parent.horizontalCenter
    color: card.appearance.divider
  }

  Text {
    id: arrow
    anchors.centerIn: parent
    textFormat: Text.PlainText
    // nf-md-arrow_right
    text: "󰁔"
    color: card.appearance.muted
    font.family: card.appearance.fontFamily
    font.pixelSize: card.appearance.rowFontSize + 2
  }

  Rectangle {
    visible: card.selected
    width: Style.spacing.hairline
    anchors.top: arrow.bottom
    anchors.topMargin: Style.space(4)
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    color: card.appearance.divider
  }

  Side {
    anchors.left: arrow.right
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    value: card.answer
    caption: card.answerLabel || "Result"
    weight: Font.DemiBold
  }
}
