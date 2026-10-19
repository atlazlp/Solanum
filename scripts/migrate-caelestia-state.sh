#!/usr/bin/env bash
# Copy (never move) Caelestia-era state and config into the solanum paths.
#
#   scripts/migrate-caelestia-state.sh [--dry-run] [--verify] [--force]
#
#   default    copy state files, launcher icons, secrets (mode 600), transform shell.json + monitors
#              into ~/.config/solanum/shell.json (or shell.json.migrated when one exists),
#              rewrite the gtk.css import, rename the kitty colour file, write a marker file
#   --verify   only check that every expected destination exists (exit 1 when something is missing)
#   --force    overwrite destinations that already exist (default: keep them)
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

VERIFY=0; FORCE=0
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    --verify) VERIFY=1 ;;
    --force) FORCE=1 ;;
    *) die "unknown option: $a" ;;
  esac
done

C_CFG="$CFG/caelestia"
C_STATE="$STATE/caelestia"
C_SHARE="$SHARE/caelestia"
MARKER="$QM_STATE/migrated-from-caelestia"
QM_MAIN="${QM_MAIN:-DP-2}"; QM_LEFT="${QM_LEFT:-HDMI-A-1}"; QM_RIGHT="${QM_RIGHT:-DP-3}"

# pairs "src|dst|mode" (only copied when src exists)
pairs=()
add() { pairs+=("$1|$2|${3:-644}"); }
add "$C_STATE/scheme.json"                    "$QM_STATE/scheme.json"
add "$C_STATE/launcher-item-overrides.json"   "$QM_STATE/launcher-item-overrides.json"
add "$C_STATE/apps.sqlite"                    "$QM_STATE/apps.sqlite"
add "$C_STATE/notifs.json"                    "$QM_STATE/notifs.json"
for f in "$C_STATE"/git-watcher-*.json "$C_STATE"/audio-analog-*; do [[ -e "$f" ]] && add "$f" "$QM_STATE/$(basename "$f")"; done
add "$C_CFG/git-watcher.json"                 "$QM_CFG/git-watcher.json" 600
add "$C_CFG/bar-vpn.json"                     "$QM_CFG/vpn.json" 600
add "$C_CFG/nautilus-sidebar-extra"           "$QM_CFG/nautilus-sidebar-extra"
add "$C_CFG/nautilus-drive-icons"             "$QM_CFG/nautilus-drive-icons"
for f in "$C_CFG"/generated/*.css; do [[ -e "$f" ]] && add "$f" "$QM_CFG/generated/$(basename "$f")"; done
add "$CFG/kitty/colors-caelestia-qm.conf"     "$CFG/kitty/colors-solanum.conf"
add "$CFG/qt6ct/colors/CaelestiaQM.conf"      "$CFG/qt6ct/colors/QuantumMoon.conf"
add "$SHARE/color-schemes/CaelestiaQM.colors" "$SHARE/color-schemes/QuantumMoon.colors"

# ---------------------------------------------------------------- verify
if [[ "$VERIFY" == "1" ]]; then
  log "verifying migration destinations"
  rc=0
  for e in "${pairs[@]}"; do
    IFS='|' read -r src dst _ <<<"$e"
    [[ -e "$src" ]] || continue
    if [[ -e "$dst" ]]; then ok "$dst"; else warn "missing $dst (from $src)"; rc=1; fi
  done
  if [[ -d "$C_SHARE/launcher-icons" ]]; then
    if [[ -d "$QM_SHARE/launcher-icons" ]]; then ok "$QM_SHARE/launcher-icons"; else warn "missing $QM_SHARE/launcher-icons"; rc=1; fi
  fi
  if [[ -f "$C_CFG/shell.json" ]]; then
    if [[ -f "$QM_CFG/shell.json" ]]; then ok "$QM_CFG/shell.json"; else warn "missing $QM_CFG/shell.json"; rc=1; fi
  fi
  for m in "$C_CFG"/monitors/*/shell.json; do
    [[ -f "$m" ]] || continue
    n="$(basename "$(dirname "$m")")"
    [[ "$(jq -c 'del(.dashboard.enabled, .sidebar.enabled, .utilities.enabled, .launcher.enabled, .bar.enabled) | with_entries(select(.value != {}))' "$m" 2>/dev/null)" == "{}" ]] && continue
    if [[ -f "$QM_CFG/monitors/$n.json" ]]; then ok "$QM_CFG/monitors/$n.json"; else warn "missing $QM_CFG/monitors/$n.json"; rc=1; fi
  done
  if [[ -f "$CFG/gtk-3.0/gtk.css" ]] && grep -q 'caelestia/generated' "$CFG/gtk-3.0/gtk.css"; then warn "gtk-3.0/gtk.css still imports caelestia/generated"; rc=1; fi
  if [[ -f "$MARKER" ]]; then ok "marker $MARKER"; else warn "missing marker $MARKER"; rc=1; fi
  [[ $rc -eq 0 ]] && ok "migration verified" || warn "migration incomplete: run scripts/migrate-caelestia-state.sh"
  exit $rc
fi

# ---------------------------------------------------------------- copy
[[ -d "$C_CFG" || -d "$C_STATE" ]] || { warn "no Caelestia config/state found; nothing to migrate"; exit 0; }
log "copying state/config (never moving)"
run mkdir -p "$QM_STATE" "$QM_CFG/monitors" "$QM_CFG/generated" "$QM_SHARE"
for e in "${pairs[@]}"; do
  IFS='|' read -r src dst mode <<<"$e"
  [[ -e "$src" ]] || continue
  if [[ -e "$dst" && "$FORCE" == "0" ]]; then ok "kept existing $dst"; continue; fi
  run install -D -m "$mode" "$src" "$dst"
done
if [[ -d "$C_SHARE/launcher-icons" ]]; then
  if [[ -d "$QM_SHARE/launcher-icons" && "$FORCE" == "0" ]]; then
    run_sh "cp -an '$C_SHARE/launcher-icons/.' '$QM_SHARE/launcher-icons/'"
  else
    run cp -a "$C_SHARE/launcher-icons" "$QM_SHARE/launcher-icons"
  fi
fi

# ---------------------------------------------------------------- shell.json transform
if [[ -f "$C_CFG/shell.json" ]]; then
  log "transforming shell.json (roles main=$QM_MAIN left=$QM_LEFT right=$QM_RIGHT)"
  dst="$QM_CFG/shell.json"
  if [[ -f "$dst" && "$FORCE" == "0" ]]; then dst="$QM_CFG/shell.json.migrated"; info "shell.json exists; writing $dst"; fi
  mon_json() { local f="$C_CFG/monitors/$1/shell.json"; if [[ -f "$f" ]]; then cat "$f"; else echo '{}'; fi; }
  out="$(jq -n \
    --slurpfile tpl "$REPO/config/solanum/shell.json.example" \
    --slurpfile old "$C_CFG/shell.json" \
    --argjson mon_main "$(mon_json "$QM_MAIN")" --argjson mon_left "$(mon_json "$QM_LEFT")" --argjson mon_right "$(mon_json "$QM_RIGHT")" \
    --arg main "$QM_MAIN" --arg left "$QM_LEFT" --arg right "$QM_RIGHT" --arg root "$REPO/solanum" '
    def deepmerge(a; b): a as $a | b as $b |
      if ($a|type) == "object" and ($b|type) == "object" then
        reduce ($b|keys_unsorted[]) as $k ($a; .[$k] = deepmerge($a[$k]; $b[$k]))
      else $b end;
    $tpl[0] as $t | $old[0] as $o |
    {main: $mon_main, left: $mon_left, right: $mon_right} as $mons |
    ["main","left","right"] as $roles |
    {main: $main, left: $left, right: $right} as $names |
    def enabled_roles(mod): [ $roles[] as $r | $r
      | select(($mons[$r][mod] | if type == "object" and has("enabled") then .enabled else true end) == true) ];
    def roles_or_star(r): if (r|length) == 3 then ["*"] else r end;
    def bar_roles: [ $roles[] as $r | $r | select((($o.bar.excludedScreens // []) | index($names[$r])) == null) ];
    def cmd(c): if c == ["caelestia","shell","lock","lock"] then ["qm-lock"] else c end;
    $t
    | .screens.roles = $names
    | .modules.bar = (bar_roles | if length == 0 then ["main"] else . end)
    | .modules.dashboard = enabled_roles("dashboard")
    | .modules.sidebar = enabled_roles("sidebar")
    | .modules.utilities = enabled_roles("utilities")
    | .modules.launcher = roles_or_star(enabled_roles("launcher"))
    | .appearance = deepmerge(.appearance; ($o.appearance // {}))
    | .general.idle = deepmerge(.general.idle; ($o.general.idle // {}))
    | .general.showOverFullscreen = ($o.general.showOverFullscreen // .general.showOverFullscreen)
    | .bar.entries = ($o.bar.entries // .bar.entries)
    | .bar.status = deepmerge(.bar.status; ($o.bar.status // {}))
    | .bar.tray.iconSubs = ($o.bar.tray.iconSubs // [])
    | .bar.tray.hiddenIcons = ($o.bar.tray.hiddenIcons // [])
    | .bar.showOnHover = ($o.bar.showOnHover // false)
    | .bar.activeWindow = deepmerge(.bar.activeWindow; ($o.bar.activeWindow // {}))
    | .bar.popouts = deepmerge(.bar.popouts; ($o.bar.popouts // {}))
    | .bar.workspaces = deepmerge(.bar.workspaces; ($o.bar.workspaces // {}))
    | .launcher.showOnHover = ($o.launcher.showOnHover // false)
    | .notifs = deepmerge(.notifs; ($o.notifs // {}))
    | .utilities.toasts = deepmerge(.utilities.toasts; ($o.utilities.toasts // {}))
    | .session.icons = deepmerge(.session.icons; ($o.session.icons // {}))
    | .session.commands = deepmerge(.session.commands; (($o.session.commands // {}) | with_entries(.value |= cmd(.))))
    | .qm.root = $root
    ')" || die "shell.json transform failed"
  printf '%s\n' "$out" | write_file "$dst" 644
  for m in "$C_CFG"/monitors/*/shell.json; do
    [[ -f "$m" ]] || continue
    n="$(basename "$(dirname "$m")")"
    mdst="$QM_CFG/monitors/$n.json"
    if [[ -f "$mdst" && "$FORCE" == "0" ]]; then ok "kept existing $mdst"; continue; fi
    # per-monitor enable flags became the modules matrix; keep only the remaining overrides
    mout="$(jq 'del(.dashboard.enabled, .sidebar.enabled, .utilities.enabled, .launcher.enabled, .bar.enabled)
        | with_entries(select(.value != {}))' "$m")" || die "monitor transform failed: $m"
    if [[ "$mout" == "{}" ]]; then ok "no per-monitor overrides left for $n"; continue; fi
    printf '%s\n' "$mout" | write_file "$mdst" 644
  done
fi

# ---------------------------------------------------------------- gtk.css import rewrite
g3="$CFG/gtk-3.0/gtk.css"
if [[ -f "$g3" ]] && grep -q '\.\./caelestia/generated/' "$g3"; then
  log "rewriting gtk-3.0/gtk.css import"
  run cp -a "$g3" "$g3.bak.$STAMP"
  run sed -i 's#\.\./caelestia/generated/#../solanum/generated/#g' "$g3"
fi
g4="$CFG/gtk-4.0/gtk.css"
if [[ -f "$g4" ]] && grep -q 'caelestia-nautilus-sidebar' "$g4"; then
  log "renaming the nautilus sidebar marker in gtk-4.0/gtk.css"
  run cp -a "$g4" "$g4.bak.$STAMP"
  run sed -i 's/caelestia-nautilus-sidebar/solanum-nautilus-sidebar/g' "$g4"
fi

# ---------------------------------------------------------------- kitty
kc="$CFG/kitty/kitty.conf"
if [[ -f "$kc" ]] && grep -q 'kitty-caelestia-qm.sock\|colors-caelestia-qm.conf' "$kc"; then
  log "rewriting kitty.conf socket/include names"
  run cp -a "$kc" "$kc.bak.$STAMP"
  run sed -i -e 's#kitty-caelestia-qm.sock#kitty-solanum.sock#g' -e 's#colors-caelestia-qm.conf#colors-solanum.conf#g' "$kc"
fi

# ---------------------------------------------------------------- marker
printf 'migrated %s from %s\n' "$STAMP" "$C_CFG" | write_file "$MARKER" 644
ok "migration done (sources left untouched under ~/.config/caelestia, ~/.local/state/caelestia)"
