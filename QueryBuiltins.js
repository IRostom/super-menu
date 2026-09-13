// Built-in query plugins.
//
// These are ordinary descriptors -- they go through the same normalize, gate,
// run and row pipeline a user plugin does. The only privilege they have is
// being written in a file that is statically imported, so their triggers can
// be real functions rather than regex strings.
//
// Keeping the shipped plugins on the public contract is deliberate: if the
// calculator needs something the contract cannot express, that is a hole in
// the contract, and it should be fixed there rather than special-cased here.

.pragma library

.import "QueryPlugins.js" as QueryPlugins

// scriptDir is the plugin's own directory as a plain filesystem path, passed
// in by Menu.qml (which resolves it from Qt.resolvedUrl). Nothing here can
// discover it alone, and hardcoding a path would break the moment the folder
// is cloned or renamed.
function descriptors(scriptDir) {
  return [
    {
      id: "calc",
      title: "Calculator",
      // nf-md-calculator, rendered in the existing icon column.
      icon: "󰃬",
      priority: 60,
      kind: "command",

      trigger: {
        minLength: 2,
        // `=` forces evaluation of anything the heuristic declined, and is
        // stripped before the query reaches qalc -- a leading `=` reads as a
        // comparison there, so `=2+2` would come back as `false`.
        prefixes: ["="],
        gate: QueryPlugins.calcGate
      },

      argv: [scriptDir + "/query-plugins/calc.sh"],
      queryVia: "env",
      acceptExitCodes: [0],

      debounce: 130,
      timeout: 1500,
      maxRows: 1,
      // Typing `2+2` shows the answer but leaves Enter aimed at the top search
      // result; `=2+2` hands Enter to the answer. An answer arriving mid-word
      // should never take a keystroke the user had aimed somewhere else.
      stealsFocus: "explicit"
    }
  ]
}
