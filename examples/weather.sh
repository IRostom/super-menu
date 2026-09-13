#!/bin/bash
# Weather for a city, via wttr.in. Copy this plus weather.js to
# ~/.config/omarchy/menu-plugins/ to enable.
#
# This is the shape a `command` plugin takes: read $OMARCHY_QUERY, print one
# JSON object on stdout, exit 0. Printing nothing means "no answer" and is not
# an error. Anything needing the network belongs here rather than in a "js"
# plugin, which would block the UI thread.

set -uo pipefail
query="${OMARCHY_QUERY-}"
[[ -n ${query//[[:space:]]/} ]] || exit 0

out=$(curl -fsS --max-time 3 "https://wttr.in/${query// /+}?format=%C+%t+%w" 2>/dev/null) || exit 0
[[ -n ${out//[[:space:]]/} ]] || exit 0
[[ $out == *"Unknown location"* ]] && exit 0

jq -nc --arg value "$out" --arg detail "weather in $query" \
  '{value:$value, detail:$detail, copy:$value}'
