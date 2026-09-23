import QtQuick
import qs.Commons

// Scroll scrims. The clipped row already marks the fold at rest; these keep
// both edges honest once the list has been scrolled, when content hides
// above the card top as well as below. Strength tracks the distance still
// hidden past each edge rather than animating on a clock, so a programmatic
// jump — wrapping from the last row back to the first — lands with the fade
// already applied.
Item {
  id: fades

  required property Flickable list
  required property color background

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Math.min(Style.space(28), parent.height / 2)
    visible: opacity > 0
    opacity: fades.list.contentHeight > fades.list.height
      ? Math.max(0, Math.min(1, (fades.list.contentY - fades.list.originY) / height))
      : 0
    gradient: Gradient {
      GradientStop { position: 0; color: fades.background }
      GradientStop { position: 1; color: Util.alpha(fades.background, 0) }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.min(Style.space(28), parent.height / 2)
    visible: opacity > 0
    opacity: fades.list.contentHeight > fades.list.height
      ? Math.max(0, Math.min(1, (fades.list.originY + fades.list.contentHeight - fades.list.height - fades.list.contentY) / height))
      : 0
    gradient: Gradient {
      GradientStop { position: 0; color: Util.alpha(fades.background, 0) }
      GradientStop { position: 1; color: fades.background }
    }
  }
}
