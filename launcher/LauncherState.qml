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
  property var answerRows: []
  property bool deleteConfirmOpen: false
}
