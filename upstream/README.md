# Upstream baseline

Pristine copies of the first-party `omarchy.menu` plugin as it shipped, kept so
that local changes can be merged forward with a 3-way diff when Omarchy updates.

    cloned from: omarchy.menu
    omarchy version: 4.0.3-1
    date: 2026-09-13

`AppLibrary.qml` and `AppSearch.js` come from `$OMARCHY_PATH/shell/services/`
rather than the menu plugin folder; the parent README explains why this plugin
carries its own copies.

To merge a newer upstream:

    U=/usr/share/omarchy/shell/plugins/menu
    diff3 -m Menu.qml upstream/Menu.qml $U/Menu.qml > Menu.qml.merged
    # review, then replace Menu.qml and refresh this directory from $U

These files are reference only — nothing loads them at runtime.
