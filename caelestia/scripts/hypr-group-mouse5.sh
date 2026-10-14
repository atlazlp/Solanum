#!/usr/bin/env bash
set -euo pipefail

aw="$(hyprctl activewindow -j 2>/dev/null)" || exit 0
class="$(jq -r '.class // empty' <<<"${aw}")"
if [[ "${class}" == steam_app_* ]]; then
  exit 0
fi

count="$(jq -r 'if (.grouped | type) == "array" then (.grouped | length) else 0 end' <<<"${aw}" 2>/dev/null || echo 0)"

if [[ "${count}" -gt 0 ]]; then
  hyprctl dispatch moveoutofgroup
else
  hyprctl dispatch togglegroup
fi
