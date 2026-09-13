// Descriptor for weather.sh. Both files go in ~/.config/omarchy/menu-plugins/.
//
// `ctx` is provided by the loader: there is no __dirname in this scope, and a
// command plugin must name its helper by absolute path, so use ctx.dir (this
// directory) rather than hardcoding a home directory.

descriptor = {
  id: "weather",
  title: "Weather",
  icon: "󰔊",
  kind: "command",
  trigger: { keywords: ["weather", "wx"] },

  argv: [ctx.dir + "/weather.sh"],
  queryVia: "env",          // arrives as $OMARCHY_QUERY

  // Network work deserves a longer quiet period than a local calculation, and
  // a timeout well under the point where the menu would feel stuck.
  debounce: 400,
  timeout: 4000,
  maxRows: 1,
  stealsFocus: true
}
