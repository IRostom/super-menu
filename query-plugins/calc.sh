#!/bin/bash
# Calculator / unit / currency answers for the irostom.menu query-plugin layer.
#
# Reads the query from $OMARCHY_QUERY and prints one JSON row on stdout, or
# nothing at all when the query has no sensible answer. Exiting 0 with empty
# output is the normal "no answer" result; the menu only shows a row when it
# gets valid JSON back.
#
# The caller (QueryPlugins.js) has already decided the query looks like maths,
# a unit conversion, or a currency conversion. That gate is not optional —
# qalc answers almost anything, including plain menu words:
#
#     qalc -t theme   -> 30.93650008 kg·m³/ms²   (exit 0!)
#     qalc -t font    -> 1E−24 B·t               (exit 0!)
#
# so exit status alone can never separate a real answer from noise.

set -uo pipefail

query="${OMARCHY_QUERY-}"
[[ -n ${query//[[:space:]]/} ]] || exit 0

# qalc rewrites its config on exit (save_mode_on_exit=1), so it gets a config
# directory of its own and never touches ~/.config/qalculate/. Exchange rates
# live under XDG_DATA_HOME and stay shared, so this costs us no freshness.
export XDG_CONFIG_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/menu-qalc"
mkdir -p "$XDG_CONFIG_HOME/qalculate" 2>/dev/null || exit 0

#   -t            terse: the result only
#   -m 300        libqalculate's own compute deadline, inside the menu's watchdog
#   -s "conv 0"   no post-conversion. This is what stops "100 km to miles"
#                 coming back as "62 mi + 241 yd + 11.87401575 in".
#   -s "upxrates 0"  never update exchange rates. The default (-1) means "ask",
#                 which can block on the network — unacceptable per keystroke.
raw=$(qalc -t -m 300 -s "conv 0" -s "upxrates 0" -- "$query" 2>/dev/null)
status=$?
(( status == 0 )) || exit 0

# qalc prints U+2212 MINUS and U+00D7 MULTIPLICATION, which are not what anyone
# wants on their clipboard.
raw=${raw//$'−'/-}
raw=${raw//$'×'/*}
raw=$(printf '%s' "$raw" | tr -d '\r' | head -1)
raw=${raw#"${raw%%[![:space:]]*}"}
raw=${raw%"${raw##*[![:space:]]}"}
[[ -n $raw ]] || exit 0

# An answer that merely repeats the question is not an answer: "42" -> "42",
# "in" -> "1 in", "5+" -> "5".
norm() { printf '%s' "${1,,}" | tr -d '[:space:],'; }
[[ $(norm "$raw") == "$(norm "$query")" ]] && exit 0

# Strip surrounding quotes qalc puts on date/string results ("today").
if [[ $raw == \"*\" ]]; then raw=${raw:1:-1}; fi

# The clipboard gets full precision; the row shows something readable. Work on
# the string rather than the number: printf "%g" turns 7006652 into 7.00665e+06,
# and an exponent is never what someone wants back from a calculator.
#   - money (leading symbol or trailing ISO code) -> exactly 2 decimals
#   - an integer                                  -> left alone
#   - anything else                               -> at most 6 decimals,
#                                                    trailing zeros trimmed
display=$(printf '%s' "$raw" | awk '
  match($0, /-?[0-9][0-9]*\.?[0-9]*([eE][-+]?[0-9]+)?/) {
    pre  = substr($0, 1, RSTART - 1)
    num  = substr($0, RSTART, RLENGTH)
    post = substr($0, RSTART + RLENGTH)

    # qalc already chose the exponent here; re-formatting would lose precision.
    if (num ~ /[eE]/) { print $0; found = 1; next }

    money = (pre ~ /[$€£¥₹₿]/) || (post ~ /^ *[A-Z]{3} *$/)
    if (money) {
      out = sprintf("%.2f", num + 0)
    } else if (num !~ /\./) {
      out = num
    } else {
      split(num, parts, ".")
      frac = substr(parts[2], 1, 6)
      sub(/0+$/, "", frac)
      out = (frac == "") ? parts[1] : parts[1] "." frac
    }
    print pre out post
    found = 1
  }
  END { if (!found) print "" }
')
[[ -n ${display//[[:space:]]/} ]] || display=$raw

jq -nc --arg value "$display" --arg detail "= $query" --arg copy "$raw" \
  '{value:$value, detail:$detail, copy:$copy}'
