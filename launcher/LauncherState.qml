import QtQuick

// The state the launcher's views read. Menu.qml aliases each of these under
// its old name, so the logic keeps writing root.filterText and friends while
// view components take this one object instead of reaching into Menu.qml.
QtObject {
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property string activeMenu: "root"
  property var navStack: []
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  // The row under a pointer that has actually moved, or -1. Separate from
  // selectedIndex: hover highlights a row, it does not select it.
  property int hoveredIndex: -1
  property var answerRows: []
  property bool deleteConfirmOpen: false
  property bool actionPanelOpen: false
  // A short confirmation in the footer ("Copied €86.45"), or "".
  property string toastText: ""
  // Ctrl held on its own: rows show Ctrl+1..9, Ctrl+0 quick-launch keycaps.
  property bool quickAccessActive: false
  // The app detail pane beside the list (Ctrl+D on an app row).
  property bool detailVisible: false
}
