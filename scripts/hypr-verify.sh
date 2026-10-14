#!/usr/bin/env bash
# Verify the Lua Hyprland config and its helper scripts without touching the live session.
#   scripts/hypr-verify.sh
# Runs Hyprland --verify-config, bash -n on hypr/scripts/*.sh, python py_compile on *.py, and when a
# Hyprland session is running: bind count, submap summary and hyprctl configerrors.
set -euo pipefail
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0; fi
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
H="$REPO/hypr"
rc=0
[[ -d "$H" ]] || { echo "hypr-verify: $H missing" >&2; exit 1; }

echo "==> Hyprland --verify-config"
if [[ -f "$H/hyprland.lua" ]]; then
  Hyprland --verify-config -c "$H/hyprland.lua" || rc=1
else
  echo "   no hyprland.lua yet"; rc=1
fi

echo "==> bash -n hypr/scripts"
for f in "$H"/scripts/*; do
  [[ -f "$f" ]] || continue
  case "$(head -c 64 "$f")" in
    *bash*|*'/bin/sh'*) bash -n "$f" && echo "   ok $(basename "$f")" || { echo "   FAIL $(basename "$f")"; rc=1; } ;;
    *python*) python3 -m py_compile "$f" && echo "   ok $(basename "$f") (py)" || { echo "   FAIL $(basename "$f")"; rc=1; } ;;
    *) echo "   skip $(basename "$f")" ;;
  esac
done
if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  shellcheck -S warning "$H"/scripts/*.sh 2>/dev/null || rc=1
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl version >/dev/null 2>&1; then
  echo "==> live session"
  echo "   binds: $(hyprctl binds -j | jq 'length')"
  echo "   submaps: $(hyprctl binds -j | jq -r '[.[].submap] | map(select(length>0)) | group_by(.) | map("\(.[0])=\(length)") | join(" ")')"
  echo "   usingLua: $(hyprctl -j version | jq -r '.usingLua // "n/a"' 2>/dev/null)"
  errs="$(hyprctl configerrors 2>/dev/null || true)"
  if [[ -z "$errs" || "$errs" == "no errors" ]]; then echo "   configerrors: none"; else echo "   configerrors:"; echo "$errs"; rc=1; fi
else
  echo "==> no Hyprland session; skipped live checks"
fi
exit $rc
