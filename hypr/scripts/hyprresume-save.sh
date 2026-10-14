#!/usr/bin/env sh
set -eu
cfg="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/hyprresume.toml"
if hyprctl workspaces -j 2>/dev/null | jq -e 'any(.name | test("lock"))' >/dev/null; then
  echo "hyprresume-save: skip while screen is locked (unlock, arrange desktop, then run again)" >&2
  exit 1
fi
exec hyprresume -c "${cfg}" save "$@"
