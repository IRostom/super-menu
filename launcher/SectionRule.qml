import QtQuick
import qs.Commons

// ListView draws a section header above the first row of each group.
// Answers sort first, so the plain "" group's header is exactly where the
// rule under the answers belongs -- and it collapses to nothing when there
// are no answers, leaving the no-answer case pixel-identical to upstream.
Item {
  id: rule

  required property string section
  required property Appearance appearance
  property bool answersPresent: false

  readonly property bool underAnswers: section === "" && answersPresent

  width: ListView.view.width
  height: (section === "drilldown" || underAnswers) ? rule.appearance.dividerHeight : 0
  visible: section === "drilldown" || underAnswers

  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    height: Style.spacing.hairline
    color: Util.alpha(rule.appearance.foreground, 0.2)
  }
}
