# Shared helpers for solanum video wallpaper (sourced by other scripts).

SCRIPT_DIR_LIB="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd)"
# shellcheck source=qm-lib.sh
source "${SCRIPT_DIR_LIB}/qm-lib.sh"
QM_ROOT="$(qm_resolve_root "$(cd "${SCRIPT_DIR_LIB}/.." && pwd)")"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/solanum"
MODES_DIR="${QM_ROOT}/modes"

# Game mode marker (features/gamemode.lua, game-mode-resources.sh). The legacy caelestia-* name is still
# written by the live Caelestia shell until the Phase 3 cutover.
qm_game_mode_active() {
  local rt="${XDG_RUNTIME_DIR:-/tmp}"
  [[ -f "${rt}/solanum-game-mode.active" || -f "${rt}/caelestia-game-mode.active" ]]
}

qm_video_sock() {
  printf '%s' "${XDG_RUNTIME_DIR:-/tmp}/solanum-mpvpaper.sock"
}

qm_video_pidfile() {
  printf '%s' "${STATE_DIR}/mpvpaper.pid"
}

qm_repo_root() {
  cd "${QM_ROOT}/.." && pwd
}

qm_is_lfs_pointer() {
  local f="$1"
  [[ -f "${f}" ]] || return 1
  head -c 256 "${f}" 2>/dev/null | grep -q 'git-lfs.github.com'
}

qm_video_file_usable() {
  local f="$1"
  [[ -f "${f}" ]] || return 1
  if qm_is_lfs_pointer "${f}"; then
    return 1
  fi
  if file -b "${f}" 2>/dev/null | grep -qiE 'ISO Media|Matroska|WebM|AVI |video'; then
    return 0
  fi
  local sz
  sz="$(stat -c%s "${f}" 2>/dev/null || echo 0)"
  [[ "${sz}" -gt 1048576 ]]
}

qm_lfs_pull_center_videos() {
  local repo
  repo="$(qm_repo_root)"
  [[ -d "${repo}/.git" ]] || return 1
  command -v git-lfs >/dev/null 2>&1 || return 1
  (cd "${repo}" && git lfs pull --include='solanum/modes/*/wallpapers/center.mp4')
}

qm_ensure_center_video_file() {
  local vid="$1"
  if qm_video_file_usable "${vid}"; then
    return 0
  fi
  if qm_is_lfs_pointer "${vid}"; then
    echo "solanum: center.mp4 is a Git LFS pointer; pulling real videos…" >&2
    qm_lfs_pull_center_videos || true
  fi
  qm_video_file_usable "${vid}"
}

qm_mpvpaper_running() {
  local pf pid comm
  pf="$(qm_video_pidfile)"
  [[ -f "${pf}" ]] || return 1
  pid="$(tr -d '[:space:]' <"${pf}")"
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  comm="$(ps -p "${pid}" -o comm= 2>/dev/null || true)"
  [[ "${comm}" == *mpvpaper* ]]
}

qm_current_slug() {
  local state="${STATE_DIR}/current.json"
  [[ -f "${state}" ]] || return 1
  jq -r '.slug // empty' "${state}" 2>/dev/null
}

qm_sorted_monitors_json() {
  hyprctl monitors -j 2>/dev/null | jq -c 'sort_by(.x, .y)' || echo '[]'
}

qm_center_slot_index() {
  local sorted count idx
  sorted="$(qm_sorted_monitors_json)"
  count="$(echo "${sorted}" | jq 'length // 0')"
  idx=0
  if [[ "${count}" =~ ^[0-9]+$ ]] && [[ "${count}" -ge 2 ]]; then
    idx=1
  fi
  echo "${idx}"
}

qm_center_monitor_name() {
  local sorted idx
  sorted="$(qm_sorted_monitors_json)"
  idx="$(qm_center_slot_index)"
  echo "${sorted}" | jq -r ".[${idx}] | .name // empty"
}

qm_center_monitor_id() {
  local sorted idx
  sorted="$(qm_sorted_monitors_json)"
  idx="$(qm_center_slot_index)"
  echo "${sorted}" | jq -r ".[${idx}] | .id // empty"
}

qm_center_active_workspace_id() {
  local sorted idx
  sorted="$(qm_sorted_monitors_json)"
  idx="$(qm_center_slot_index)"
  echo "${sorted}" | jq -r ".[${idx}] | .activeWorkspace.id // empty"
}

qm_video_stop() {
  mkdir -p "${STATE_DIR}"
  local pf sock center_mon
  pf="$(qm_video_pidfile)"
  sock="$(qm_video_sock)"
  if [[ -f "${pf}" ]]; then
    local pid
    pid="$(cat "${pf}" 2>/dev/null)" || true
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      for _ in $(seq 1 40); do
        kill -0 "${pid}" 2>/dev/null || break
        sleep 0.05
      done
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${pf}"
  fi
  center_mon="$(qm_center_monitor_name 2>/dev/null || true)"
  if [[ -n "${center_mon}" ]]; then
    pkill -f "mpvpaper.*[[:space:]]${center_mon}[[:space:]]" 2>/dev/null || true
  fi
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper 2>/dev/null || true
    for _ in $(seq 1 30); do
      pgrep -x mpvpaper >/dev/null 2>&1 || break
      sleep 0.05
    done
    pkill -9 -x mpvpaper 2>/dev/null || true
  fi
  rm -f "${sock}"
}

qm_mpv_set_pause() {
  local sock="$1" want="$2"
  [[ -S "${sock}" ]] || return 1
  python3 -c '
import json, socket, sys
sock, want = sys.argv[1], sys.argv[2] == "true"
msg = json.dumps({"command": ["set_property", "pause", want]}) + "\n"
s = socket.socket(socket.AF_UNIX)
s.connect(sock)
s.sendall(msg.encode())
s.close()
' "${sock}" "${want}"
}

qm_count_toplevels_on_center_workspace() {
  local ws mid clients
  ws="$(qm_center_active_workspace_id)"
  mid="$(qm_center_monitor_id)"
  [[ -n "${ws}" && "${ws}" != "null" ]] || { echo 0; return 0; }
  [[ -n "${mid}" && "${mid}" != "null" ]] || { echo 0; return 0; }

  if ! clients="$(hyprctl clients -j 2>/dev/null)"; then
    echo 0
    return 0
  fi

  echo "${clients}" | jq --argjson ws "${ws}" --argjson mid "${mid}" '
    [.[] | select(
      (.address != null) and
      (.workspace.id == $ws) and
      (.monitor == $mid) and
      (.mapped != false) and
      (.hidden != true)
    )] | length
  '
}

qm_desktop_visible_on_center() {
  local n
  n="$(qm_count_toplevels_on_center_workspace)"
  [[ "${n}" == "0" ]]
}

# ---- Center wallpaper mode: video (mpvpaper) vs scene (Godot) ----

qm_shell_json() {
  printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}/solanum/shell.json"
}

qm_center_mode() {
  local conf mode
  conf="$(qm_shell_json)"
  mode="scene"
  if [[ -f "${conf}" ]]; then
    mode="$(jq -r '.quantumMoon.background.centerMode // "scene"' "${conf}" 2>/dev/null || echo scene)"
  fi
  case "${mode}" in
    video|scene) printf '%s' "${mode}" ;;
    *) printf '%s' "scene" ;;
  esac
}

qm_scene_speed() {
  local conf speed
  conf="$(qm_shell_json)"
  speed="4"
  if [[ -f "${conf}" ]]; then
    speed="$(jq -r '.quantumMoon.background.sceneSpeed // 4' "${conf}" 2>/dev/null || echo 4)"
  fi
  if [[ "${speed}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s' "${speed}"
  else
    printf '%s' "4"
  fi
}

qm_godot_root() {
  local conf rootf root shipped
  rootf="${XDG_CONFIG_HOME:-${HOME}/.config}/solanum/godot-root"
  if [[ -f "${rootf}" ]]; then
    root="$(tr -d '[:space:]' <"${rootf}")"
    if [[ -n "${root}" && -f "${root}/project.godot" ]]; then
      printf '%s' "${root}"
      return 0
    fi
  fi
  conf="$(qm_shell_json)"
  if [[ -f "${conf}" ]]; then
    root="$(jq -r '.quantumMoon.background.sceneRoot // empty' "${conf}" 2>/dev/null || true)"
    if [[ -n "${root}" && "${root}" != "null" && -f "${root}/project.godot" ]]; then
      printf '%s' "${root}"
      return 0
    fi
  fi
  shipped="${QM_ROOT}/scene"
  if [[ -f "${shipped}/project.godot" ]]; then
    printf '%s' "$(realpath "${shipped}")"
    return 0
  fi
  # Last resort: the pre-migration checkout on the backup drive.
  for cand in \
    "/mnt/Backup/quantum-moon-wallpaper/godot" \
    "${HOME}/Projects/quantum-moon-wallpaper/godot"
  do
    if [[ -f "${cand}/project.godot" ]]; then
      printf '%s' "$(realpath "${cand}")"
      return 0
    fi
  done
  return 1
}

qm_godot_control_path() {
  printf '%s' "${XDG_RUNTIME_DIR:-/tmp}/solanum/godot-control.json"
}

qm_godot_pidfile() {
  printf '%s' "${STATE_DIR}/godot-wallpaper.pid"
}

qm_godot_sock_note() {
  # Control is a JSON file (not a socket); kept for symmetry with mpv helpers.
  qm_godot_control_path
}

qm_godot_running() {
  local pf pid
  pf="$(qm_godot_pidfile)"
  [[ -f "${pf}" ]] || return 1
  pid="$(tr -d '[:space:]' <"${pf}")"
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  # Accept godot / Godot_v* binaries.
  local comm
  comm="$(ps -p "${pid}" -o comm= 2>/dev/null || true)"
  [[ "${comm}" == *godot* || "${comm}" == *Godot* ]]
}

qm_godot_write_control() {
  # Args as key=value pairs merged into control JSON.
  # One lock and a private temp file: overlapping orbit/menu writes were splicing the JSON.
  local path
  path="$(qm_godot_control_path)"
  mkdir -p "$(dirname "${path}")"
  (
    flock -x 9
    local tmp existing
    existing="{}"
    if [[ -f "${path}" ]] && jq -e . "${path}" >/dev/null 2>&1; then
      existing="$(cat "${path}")"
    fi
    local args=("$@")
  local jq_args=(-n --argjson base "${existing}")
  local filter='$base'
  local i=0
  for kv in "${args[@]}"; do
    local k="${kv%%=*}"
    local v="${kv#*=}"
    case "${k}" in
      pause|game_pause|menu_hold)
        jq_args+=(--argjson "v${i}" "$( [[ "${v}" == "true" ]] && echo true || echo false )")
        filter+=" | .${k} = \$v${i}"
        ;;
      time_scale)
        jq_args+=(--argjson "v${i}" "${v}")
        filter+=" | .time_scale = \$v${i}"
        ;;
      qm_host)
        jq_args+=(--arg "v${i}" "${v}")
        filter+=" | .qm_host = \$v${i}"
        ;;
      supernova_token)
        jq_args+=(--arg "v${i}" "${v}")
        filter+=" | .supernova_token = \$v${i}"
        ;;
      orbit_snap)
        jq_args+=(--argjson "v${i}" "$( [[ "${v}" == "true" ]] && echo true || echo false )")
        filter+=" | .orbit_snap = \$v${i}"
        ;;
      orbit_token|orbit_body|overview_token|video_body|sun_pulse|sun_pulse_token)
        jq_args+=(--arg "v${i}" "${v}")
        filter+=" | .${k} = \$v${i}"
        ;;
      sun_pulse_ms|sun_pulse_start)
        jq_args+=(--argjson "v${i}" "${v}")
        filter+=" | .${k} = \$v${i}"
        ;;
      *)
        continue
        ;;
    esac
    i=$((i + 1))
  done
    filter+=' | .rev = ((.rev // 0) + 1)'
    tmp="$(mktemp "${path}.tmp.XXXXXX")"
    if ! jq "${jq_args[@]}" "${filter}" >"${tmp}"; then
      rm -f "${tmp}"
      exit 1
    fi
    mv -f "${tmp}" "${path}"
  ) 9>"${path}.lock"
}

qm_godot_stop() {
  mkdir -p "${STATE_DIR}"
  local pf
  pf="$(qm_godot_pidfile)"
  if [[ -f "${pf}" ]]; then
    local pid
    pid="$(cat "${pf}" 2>/dev/null)" || true
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      for _ in $(seq 1 40); do
        kill -0 "${pid}" 2>/dev/null || break
        sleep 0.05
      done
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${pf}"
  fi
  # Class-based cleanup for leftover wallpaper windows
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class=="qm-solar-wallpaper" or .initialClass=="qm-solar-wallpaper") | .address' 2>/dev/null \
      | while read -r addr; do
          [[ -n "${addr}" ]] && hyprctl dispatch closewindow "address:${addr}" >/dev/null 2>&1 || true
        done
  fi
}

# Move qm-solar-wallpaper onto the centre monitor via Hyprland Lua (hyprctl
# dispatch is broken under the Lua config — it tries to parse args as Lua).
qm_godot_place_center() {
  local mon
  mon="$(qm_center_monitor_name)"
  [[ -n "${mon}" ]] || return 1
  command -v hyprctl >/dev/null 2>&1 || return 1
  # shellcheck disable=SC2016
  hyprctl eval "
local monName = [[${mon}]]
local function field(o, k)
  local ok, v = pcall(function() return o[k] end)
  if ok then return v end
  return nil
end
local target
for _, w in ipairs(hl.get_windows()) do
  if field(w, 'class') == 'qm-solar-wallpaper' or field(w, 'initial_class') == 'qm-solar-wallpaper' then
    target = w
    break
  end
end
if not target then return 'no-window' end
local mon = hl.get_monitor(monName)
if not mon then return 'no-mon:' .. monName end
local mx = field(mon, 'x') or 0
local my = field(mon, 'y') or 0
local mw = field(mon, 'width') or 1920
local mh = field(mon, 'height') or 1080
hl.dispatch(hl.dsp.window.move({ x = mx, y = my, window = target }))
hl.dispatch(hl.dsp.window.resize({ x = mw, y = mh, window = target }))
return 'ok:' .. monName
" >/dev/null 2>&1
}

qm_godot_start() {
  local slug="$1"
  local root speed mon w h godot_bin LOG
  root="$(qm_godot_root)" || {
    echo "qm-scene: Godot project not found (expected ${QM_ROOT}/scene, or set sceneRoot / the godot-root file)" >&2
    printf '%s\n' "missing:godot-project" >"${STATE_DIR}/last-video.path"
    return 1
  }
  godot_bin="$(command -v godot || true)"
  [[ -n "${godot_bin}" ]] || godot_bin="$(command -v godot4 || true)"
  [[ -n "${godot_bin}" ]] || {
    echo "qm-scene: godot binary not found in PATH" >&2
    printf '%s\n' "no-godot" >"${STATE_DIR}/last-video.path"
    return 1
  }
  speed="$(qm_scene_speed)"
  mon=""
  for __retry in {1..20}; do
    mon="$(qm_center_monitor_name)"
    [[ -n "${mon}" ]] && break
    sleep 0.06
  done
  [[ -n "${mon}" ]] || {
    printf '%s\n' "no-monitor" >"${STATE_DIR}/last-video.path"
    return 1
  }
  local sorted idx
  sorted="$(qm_sorted_monitors_json)"
  idx="$(qm_center_slot_index)"
  w="$(echo "${sorted}" | jq -r ".[${idx}].width // 1920")"
  h="$(echo "${sorted}" | jq -r ".[${idx}].height // 1080")"

  qm_godot_write_control "pause=false" "game_pause=false" "menu_hold=false" "time_scale=${speed}" "qm_host=${slug}"

  LOG="${STATE_DIR}/godot-wallpaper.log"
  : >"${LOG}"
  mkdir -p "${STATE_DIR}"
  # Forward Hyprland IPC so Godot can poll cursorpos / clients for hover-pause.
  local his="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  if [[ -z "${his}" && -d "${XDG_RUNTIME_DIR:-/tmp}/hypr" ]]; then
    his="$(basename "$(find "${XDG_RUNTIME_DIR}/hypr" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)")"
  fi
  local run_env=(
    "QM_WALLPAPER=1"
    "QM_TIME_SCALE=${speed}"
  )
  if [[ -n "${his}" ]]; then
    run_env+=("HYPRLAND_INSTANCE_SIGNATURE=${his}")
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid env "${run_env[@]}" \
      "${godot_bin}" --path "${root}" --display-driver wayland \
      --resolution "${w}x${h}" \
      </dev/null >>"${LOG}" 2>&1 &
  else
    nohup env "${run_env[@]}" \
      "${godot_bin}" --path "${root}" --display-driver wayland \
      --resolution "${w}x${h}" \
      </dev/null >>"${LOG}" 2>&1 &
  fi
  echo $! >"$(qm_godot_pidfile)"
  disown || true

  sleep 0.6
  if ! qm_godot_running; then
    echo "qm-scene: Godot exited immediately; see ${LOG}" >&2
    tail -n 30 "${LOG}" >&2 || true
    printf '%s\n' "godot-exit:${root}" >"${STATE_DIR}/last-video.path"
    return 1
  fi

  # Wait for the window, then force it onto the centre monitor. hyprwinwrap
  # also has monitor=<centre> so later opens stay put.
  local placed=0
  for __retry in {1..40}; do
    if qm_godot_place_center; then
      # Confirm it actually landed on the centre output.
      local mid
      mid="$(hyprctl clients -j 2>/dev/null | jq -r '
        .[] | select(.class == "qm-solar-wallpaper") | .monitor
      ' | head -n1)"
      local want_id
      want_id="$(echo "${sorted}" | jq -r ".[${idx}].id")"
      if [[ -n "${mid}" && "${mid}" == "${want_id}" ]]; then
        placed=1
        break
      fi
    fi
    sleep 0.15
  done
  if [[ "${placed}" -ne 1 ]]; then
    echo "qm-scene: could not confirm wallpaper on ${mon} (hyprwinwrap monitor=${mon})" >&2
  fi

  printf '%s\n' "scene:${root}" >"${STATE_DIR}/last-video.path"
  hyprctl hyprpaper reload >/dev/null 2>&1 || true
}

qm_uses_scene_for_slug() {
  local slug="$1" mode
  mode="$(qm_center_mode)"
  [[ "${mode}" == "scene" ]] || return 1
  [[ "${slug}" != "eye-of-the-universe" ]]
}

qm_body_slug() {
  case "$1" in
    hourglass_twins) printf '%s' "hourglass-twins" ;;
    timber_hearth) printf '%s' "timber-hearth" ;;
    brittle_hollow) printf '%s' "brittle-hollow" ;;
    giants_deep) printf '%s' "giants-deep" ;;
    dark_bramble) printf '%s' "dark-bramble" ;;
    *) return 1 ;;
  esac
}

qm_slug_to_body() {
  case "$1" in
    hourglass-twins|ember-twin|hourglass_twins) printf '%s' "hourglass_twins" ;;
    timber-hearth|timber_hearth) printf '%s' "timber_hearth" ;;
    brittle-hollow|brittle_hollow) printf '%s' "brittle_hollow" ;;
    giants-deep|giants_deep) printf '%s' "giants_deep" ;;
    dark-bramble|dark_bramble) printf '%s' "dark_bramble" ;;
    *) return 1 ;;
  esac
}

qm_live_orbit_body() {
  local solar orbit
  solar="${XDG_RUNTIME_DIR:-/tmp}/solanum/solar.json"
  [[ -f "${solar}" ]] || return 1
  orbit="$(jq -r '.orbit_body // empty' "${solar}" 2>/dev/null || true)"
  [[ -n "${orbit}" ]] || return 1
  printf '%s' "${orbit}"
}

qm_planet_video_state() {
  printf '%s' "${STATE_DIR}/planet-video.body"
}

# Play modes/<slug>/wallpapers/center.mp4 on the centre monitor.
# Does not stop Godot and does not change last-video.slug.
qm_start_center_video() {
  local slug="$1"
  local mode_dir vid mon abs sock LOG
  mode_dir="${MODES_DIR}/${slug}"
  vid="${mode_dir}/wallpapers/center.mp4"
  if [[ ! -f "${vid}" ]]; then
    printf '%s\n' "missing:${vid}" >"${STATE_DIR}/last-video.path"
    echo "qm-video: missing ${vid}" >&2
    return 1
  fi
  if ! command -v mpvpaper >/dev/null 2>&1; then
    echo "qm-video: mpvpaper not found" >&2
    printf '%s\n' "no-mpvpaper" >"${STATE_DIR}/last-video.path"
    return 1
  fi
  if ! qm_ensure_center_video_file "${vid}"; then
    printf '%s\n' "lfs-pointer:${vid}" >"${STATE_DIR}/last-video.path"
    return 1
  fi
  mon=""
  for __retry in {1..20}; do
    mon="$(qm_center_monitor_name)"
    [[ -n "${mon}" ]] && break
    sleep 0.06
  done
  [[ -n "${mon}" ]] || {
    printf '%s\n' "no-monitor" >"${STATE_DIR}/last-video.path"
    return 1
  }
  abs="$(realpath "${vid}")"
  printf '%s\n' "${abs}" >"${STATE_DIR}/last-video.path"
  sock="$(qm_video_sock)"
  mkdir -p "$(dirname "${sock}")"
  rm -f "${sock}"
  local mpv_opts="--no-audio --loop-file=inf --really-quiet --hwdec=auto --profile=fast --interpolation=no --input-ipc-server=${sock} --pause=no --background=#000000"
  LOG="${STATE_DIR}/mpvpaper.log"
  : >"${LOG}"
  if command -v setsid >/dev/null 2>&1; then
    setsid mpvpaper -l background -o "${mpv_opts}" "${mon}" "${abs}" </dev/null >>"${LOG}" 2>&1 &
  else
    nohup mpvpaper -l background -o "${mpv_opts}" "${mon}" "${abs}" </dev/null >>"${LOG}" 2>&1 &
  fi
  echo $! >"$(qm_video_pidfile)"
  disown || true
  sleep 0.2
  if ! qm_mpvpaper_running; then
    echo "solanum: mpvpaper exited immediately; see ${LOG}" >&2
    tail -n 20 "${LOG}" >&2 || true
    printf '%s\n' "mpvpaper-exit:${abs}" >"${STATE_DIR}/last-video.path"
    return 1
  fi
  hyprctl hyprpaper reload >/dev/null 2>&1 || true
}

qm_planet_video_begin() {
  local body="$1" slug
  slug="$(qm_body_slug "${body}")" || {
    echo "qm-planet-video: unknown body ${body}" >&2
    return 2
  }
  mkdir -p "${STATE_DIR}"
  printf '%s\n' "${body}" >"$(qm_planet_video_state)"
  qm_godot_stop
  if ! qm_start_center_video "${slug}"; then
    rm -f "$(qm_planet_video_state)"
    local host
    host="$(tr -d '[:space:]' <"${STATE_DIR}/last-video.slug" 2>/dev/null || true)"
    [[ -n "${host}" ]] && qm_godot_start "${host}" || true
    return 1
  fi
}

qm_planet_video_restore() {
  local how="${1:-overview}" body slug
  body="$(tr -d '[:space:]' <"$(qm_planet_video_state)" 2>/dev/null || true)"
  rm -f "$(qm_planet_video_state)"
  qm_video_stop
  slug="$(tr -d '[:space:]' <"${STATE_DIR}/last-video.slug" 2>/dev/null || true)"
  [[ -n "${slug}" ]] || slug="$(qm_current_slug)"
  if [[ "${how}" == "orbit" && -n "${body}" ]]; then
    # Written before Godot boots so the first frame is already the orbit pose.
    qm_godot_write_control "video_body=" "orbit_body=${body}" "orbit_snap=true" "orbit_token=$(date +%s%N)"
  else
    qm_godot_write_control "video_body=" "orbit_snap=false"
  fi
  qm_godot_start "${slug}" || return 1
}
