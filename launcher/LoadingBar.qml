import QtQuick
import qs.Commons

// The rule under the search field, which doubles as a progress bar: while a
// provider or query plugin is running, a short accent segment sweeps across
// it. The sweep waits 250ms before showing, so fast work never flickers it,
// and lingers 100ms after, so back-to-back runs read as one.
Item {
  id: bar

  required property Appearance appearance
  property bool loading: false

  property bool active: false

  clip: true

  Rectangle {
    anchors.fill: parent
    color: bar.appearance.divider
  }

  Rectangle {
    id: sweep
    visible: bar.active
    width: Style.space(50)
    height: parent.height
    color: bar.appearance.accent
  }

  NumberAnimation {
    target: sweep
    property: "x"
    from: -sweep.width
    to: bar.width
    duration: Math.max(400, bar.width + sweep.width)
    loops: Animation.Infinite
    running: bar.active && bar.visible
  }

  Timer {
    id: debounce
    onTriggered: bar.active = bar.loading
  }

  onLoadingChanged: {
    debounce.interval = loading ? 250 : 100
    debounce.restart()
  }
}
