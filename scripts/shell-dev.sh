#!/usr/bin/env bash
# Run the Quantum Moon shell in dev mode next to a running shell: no NotificationServer,
# no session lock / idle monitors, bar exclusionMode Ignore (see shell/config/DevFlags.qml).
#   scripts/shell-dev.sh [qs args...]      e.g. scripts/shell-dev.sh -v
set -euo pipefail
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0; fi
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
if [[ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/solanum" ]]; then
  echo "shell-dev: ~/.config/quickshell/solanum missing; running from $REPO/shell with -p" >&2
  QM_SHELL_DEV=1 exec qs -p "$REPO/shell" "$@"
fi
QM_SHELL_DEV=1 exec qs -c solanum "$@"
