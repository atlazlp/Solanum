#!/usr/bin/env python3
import argparse
import configparser
import datetime
import json
import math
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import unquote, urlparse


_STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
QM_STATE_DIR = _STATE_HOME / "solanum"
LEGACY_STATE_DIR = _STATE_HOME / "caelestia"
SCHEME_FILE = QM_STATE_DIR / "scheme.json"
if not SCHEME_FILE.is_file() and (LEGACY_STATE_DIR / "scheme.json").is_file():
    SCHEME_FILE = LEGACY_STATE_DIR / "scheme.json"
HYPR_SCHEME_CONF = (
    Path.home() / ".local" / "share" / "caelestia" / "hypr" / "scheme" / "current.conf"
)
HYPR_GROUPBAR_CONF = HYPR_SCHEME_CONF.parent / "groupbar.conf"
HYPR_SHADOW_CONF = HYPR_SCHEME_CONF.parent / "shadow.conf"
# Transition: new names are primary, the Caelestia-era names are kept until the Phase 3/5 cleanup.
KDE_SCHEME_KEY = "QuantumMoon"
KDE_SCHEME_FILE = KDE_SCHEME_KEY + ".colors"
LEGACY_KDE_SCHEME_KEY = "CaelestiaQM"
LEGACY_KDE_SCHEME_FILE = LEGACY_KDE_SCHEME_KEY + ".colors"
GENERATED_DIR = Path.home() / ".config" / "solanum" / "generated"
LEGACY_GENERATED_DIR = Path.home() / ".config" / "caelestia" / "generated"  # written only while it exists
GENERATED_CSS = GENERATED_DIR / "qm-libadwaita.css"
GTK4_BLOCK_BEGIN = "/* BEGIN solanum-gtk4 */"
GTK4_BLOCK_END = "/* END solanum-gtk4 */"
GTK4_USER_BLOCK_RE = re.compile(
    re.escape(GTK4_BLOCK_BEGIN) + r".*?" + re.escape(GTK4_BLOCK_END) + r"\s*",
    re.DOTALL,
)
GTK4_LEGACY_IMPORT = re.compile(
    r"^\s*/\*\s*solanum:\s*libadwaita\s*sync\s*\*/\s*\n\s*@import\s+url\([^)]*qm-libadwaita\.css[^)]*\)\s*;\s*\n?",
    re.MULTILINE | re.IGNORECASE,
)
GTK3_IMPORT_LINE = '/* solanum: gtk3 sync */\n@import url("../solanum/generated/qm-gtk3.css");\n'

KITTY_LISTEN_SOCK_NAME = "kitty-solanum.sock"
LEGACY_KITTY_LISTEN_SOCK_NAME = "kitty-caelestia-qm.sock"
KITTY_COLORS_FILE = "colors-solanum.conf"
LEGACY_KITTY_COLORS_FILE = "colors-caelestia-qm.conf"
LISTEN_ON_RE = re.compile(r"^\s*listen_on\s+(.+)$", re.IGNORECASE | re.MULTILINE)

# Pywalfox reads ~/.cache/wal/colors.json; live update goes through its UNIX socket / CLI.
WAL_CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "wal"
PYWALFOX_SOCKET = Path(tempfile.gettempdir()) / f"pywalfox_socket_{os.getuid()}"
PYWALFOX_UPDATE_CMD = "action:update"


def expand_kitty_conf_vars(s: str) -> str:
    def repl(m: re.Match[str]) -> str:
        return os.environ.get(m.group(1), "")

    s = re.sub(r"\$\{([^}]+)\}", repl, s)
    return os.path.expandvars(s)


def default_qm_kitty_listen_address() -> str:
    rd = os.environ.get("XDG_RUNTIME_DIR")
    if not rd:
        rd = f"/run/user/{os.getuid()}"
    return f"unix:{Path(rd) / KITTY_LISTEN_SOCK_NAME}"


def normalize_kitty_listen_address(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        return raw
    if raw.startswith(("unix:", "tcp:")):
        return raw
    if raw.startswith("@"):
        return f"unix:{raw}"
    if raw.startswith("/"):
        return f"unix:{raw}"
    return raw


def _kitty_pids() -> list[int]:
    out: list[int] = []
    proc = Path("/proc")
    try:
        entries = list(proc.iterdir())
    except OSError:
        return []
    for p in entries:
        if not p.name.isdigit():
            continue
        try:
            comm = (p / "comm").read_text().strip()
        except OSError:
            continue
        if comm == "kitty":
            try:
                out.append(int(p.name))
            except ValueError:
                continue
    out.sort()
    return out


def _read_proc_environ(pid: int) -> dict[str, str]:
    raw = Path(f"/proc/{pid}/environ").read_bytes()
    d: dict[str, str] = {}
    for entry in raw.split(b"\0"):
        if b"=" not in entry:
            continue
        k, _, v = entry.partition(b"=")
        d[k.decode("utf-8", errors="ignore")] = v.decode("utf-8", errors="ignore")
    return d


def kitty_rc_candidate_addresses(kitty_conf: Path) -> list[str]:
    order: list[str] = []
    seen: set[str] = set()

    def add(raw: str) -> None:
        addr = normalize_kitty_listen_address(expand_kitty_conf_vars(raw.strip()))
        if not addr or addr in seen:
            return
        seen.add(addr)
        order.append(addr)

    for pid in _kitty_pids():
        try:
            env = _read_proc_environ(pid)
        except OSError:
            continue
        if v := env.get("KITTY_LISTEN_ON"):
            add(v)
        if xdg := env.get("XDG_RUNTIME_DIR"):
            for name in (KITTY_LISTEN_SOCK_NAME, LEGACY_KITTY_LISTEN_SOCK_NAME):
                add(f"unix:{Path(xdg) / name}")

    if kitty_conf.is_file():
        m = LISTEN_ON_RE.search(kitty_conf.read_text(encoding="utf-8"))
        if m:
            add(m.group(1).strip())

    add(default_qm_kitty_listen_address())
    rd = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    for name in (KITTY_LISTEN_SOCK_NAME, LEGACY_KITTY_LISTEN_SOCK_NAME):
        add(f"unix:{rd / name}")
        add(f"unix:{Path(f'/run/user/{os.getuid()}') / name}")
    # whichever socket actually exists goes first
    existing = [a for a in order if a.startswith("unix:/") and Path(a[5:]).exists()]
    return existing + [a for a in order if a not in existing]


def norm_hex(s: str) -> str:
    s = (s or "").strip().lstrip("#")
    if len(s) == 6 and re.fullmatch(r"[0-9a-fA-F]{6}", s):
        return s.lower()
    raise ValueError(f"invalid hex colour: {s!r}")


def hx_to_rgb(h: str) -> tuple[int, int, int]:
    h = norm_hex(h)
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def hx(h: str) -> str:
    return "#" + norm_hex(h)


def _js_round(value: float) -> int:
    """Math.round: half away from zero."""
    if value >= 0:
        return int(math.floor(value + 0.5))
    return int(math.ceil(value - 0.5))


def pywalfox_lighten(hex6: str, lum: float = 1.25) -> str:
    """Pywalfox changeLuminance. The selected tab is this applied to color0."""
    h = norm_hex(hex6)
    if h == "000000" and lum > 0:
        h = "0d0d0d"
    channels: list[int] = []
    for i in range(3):
        c = int(h[i * 2 : i * 2 + 2], 16)
        c = _js_round(min(max(0, c + (c * lum)), 255))
        channels.append(c)
    return "".join(f"{c:02x}" for c in channels)


def pywalfox_frame_for_selected(selected: str, lum: float = 1.25) -> str:
    """Smallest frame color Pywalfox lightens into `selected`."""
    want = hx_to_rgb(selected)
    parts: list[int] = []
    for channel in want:
        hit: int | None = None
        for c in range(256):
            got = _js_round(min(255, c + (c * lum)))
            if got == channel:
                hit = c
                break
        if hit is None:
            return norm_hex(selected)
        parts.append(hit)
    return "".join(f"{c:02x}" for c in parts)


def rgb_csv(h: str) -> str:
    r, g, b = hx_to_rgb(h)
    return f"{r},{g},{b}"


def to_aarrggbb(hex6: str, alpha: int = 255) -> str:
    h = norm_hex(hex6)
    return f"#{alpha:02x}{h}"


def blend_towards(hex6: str, target: str, t: float) -> str:
    a = hx_to_rgb(norm_hex(hex6))
    b = hx_to_rgb(norm_hex(target))
    t = max(0.0, min(1.0, t))
    return norm_hex(
        "".join(f"{int(round(a[i] * (1 - t) + b[i] * t)):02x}" for i in range(3))
    )


def load_colours(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    c = data.get("colours") or data.get("colors")
    if not isinstance(c, dict):
        print("scheme.json: missing colours object", file=sys.stderr)
        sys.exit(1)
    out = {}
    for k, v in c.items():
        if isinstance(v, str) and v.strip():
            try:
                out[k] = norm_hex(v)
            except ValueError:
                continue
    return out


def hypr_scheme_conf(colours: dict[str, str]) -> str:
    return "".join(f"${name} = {colour}\n" for name, colour in colours.items())


def relative_luminance(hex6: str) -> float:
    def channel(value: int) -> float:
        c = value / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = hx_to_rgb(hex6)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(fg: str, bg: str) -> float:
    l1 = relative_luminance(fg)
    l2 = relative_luminance(bg)
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def sort_keys_by_luminance(
    c: dict[str, str], keys: tuple[str, ...], fallback: str, *, reverse: bool = True
) -> tuple[str, ...]:
    return tuple(
        sorted(
            keys,
            key=lambda k: relative_luminance(pick(c, k, fallback)),
            reverse=reverse,
        )
    )


def best_pair(
    c: dict[str, str],
    bg_keys: tuple[str, ...],
    on_keys: tuple[str, ...],
    bg_fallback: str,
    on_fallback: str,
    min_ratio: float = 4.5,
    *,
    lighter_background: bool = False,
) -> tuple[str, str]:
    ordered_bg = (
        sort_keys_by_luminance(c, bg_keys, bg_fallback)
        if lighter_background
        else bg_keys
    )
    bg_key = next((k for k in ordered_bg if c.get(k)), ordered_bg[0])
    bg = pick(c, bg_key, bg_fallback)
    best_on_key = on_keys[0]
    best_on = pick(c, best_on_key, on_fallback)
    best_ratio = contrast_ratio(best_on, bg)
    adequate_key = None
    for on_key in on_keys:
        on = pick(c, on_key, on_fallback)
        ratio = contrast_ratio(on, bg)
        # Prefer the first listed on-colour that already clears WCAG-ish contrast
        # (avoids jumping to pure black onPrimaryFixed when onPrimary is fine).
        if adequate_key is None and ratio >= min_ratio:
            adequate_key = on_key
        if ratio > best_ratio:
            best_ratio = ratio
            best_on = on
            best_on_key = on_key
    if adequate_key is not None:
        return bg_key, adequate_key
    if best_ratio < min_ratio:
        for on_key in ("onSurface", "onPrimary", "onBackground", "inverseSurface"):
            on = pick(c, on_key, on_fallback)
            ratio = contrast_ratio(on, bg)
            if ratio > best_ratio:
                best_ratio = ratio
                best_on = on
                best_on_key = on_key
    return bg_key, best_on_key


def hypr_rgba_var(colour_key: str, alpha: str = "f0") -> str:
    return f"rgba(${colour_key}{alpha})"


def hypr_shadow_tint_hex(colours: dict[str, str]) -> str:
    base = pick(colours, "shadow", "000000")
    tint = pick(colours, "surfaceTint", pick(colours, "primary", "9bd0cc"))
    return blend_towards(base, tint, 0.08)


def hypr_window_glow_vars(colours: dict[str, str]) -> str:
    tint = hypr_shadow_tint_hex(colours)
    border = "primary" if colours.get("primary") else "surfaceTint"
    return f"""$qmShadowTint = {tint}
$shadowColour = rgba($qmShadowTint33)
$shadowRange = 20
$shadowRenderPower = 3
$activeWindowBorderColour = {hypr_rgba_var(border, "ff")} {hypr_rgba_var("tertiary", "cc")} 135deg
$inactiveWindowBorderColour = rgba($outlineVariant88)
"""


def hypr_shadow_decoration_conf() -> str:
    return """decoration {
    shadow {
        range = 28
        render_power = 2
        offset = 0, 8
        color = rgba($qmShadowTint1a)
    }
}
"""


GROUPBAR_PAIRS = (
    # Prefer lighter chips so group titles stay readable on dark planet schemes.
    # Avoid onPrimaryFixed (often pure black) and near-black surfaces for inactive tabs.
    ("active", ("primary", "primaryContainer", "primaryFixed", "primaryDim"), ("onPrimary", "onPrimaryContainer", "onPrimaryFixed"), "ff9066", "581900"),
    (
        "inactive",
        ("outline", "secondaryContainer", "primaryContainer", "outlineVariant", "surfaceContainerHighest"),
        ("onSurface", "onBackground", "onSurfaceVariant"),
        "9e694a",
        "ffdfcf",
    ),
    ("locked_active", ("tertiaryContainer", "tertiaryFixed", "tertiary", "tertiaryDim"), ("onTertiary", "onTertiaryContainer", "onTertiaryFixed"), "fcab24", "5d3b00"),
    ("locked_inactive", ("secondaryContainer", "secondaryFixed", "secondary", "secondaryDim"), ("onSecondaryContainer", "onSecondary", "onSecondaryFixed"), "9b4500", "fff6f2"),
)


def groupbar_pairs(colours: dict[str, str]) -> dict[str, str]:
    """Groupbar role -> scheme colour KEY ({active_bg, active_fg, inactive_bg, ...}), contrast checked."""
    out: dict[str, str] = {}
    for role, bg_keys, on_keys, bg_fb, on_fb in GROUPBAR_PAIRS:
        # Drop near-black candidates so inactive chips never collapse into the window chrome.
        usable = tuple(
            k for k in bg_keys
            if relative_luminance(pick(colours, k, bg_fb)) >= 0.08
        ) or bg_keys
        # Only the focused/locked-active chips chase the lightest bg; inactive stays mid-tone.
        lighter = role in ("active", "locked_active")
        bg, fg = best_pair(colours, usable, on_keys, bg_fb, on_fb, lighter_background=lighter)
        out[f"{role}_bg"] = bg
        out[f"{role}_fg"] = fg
    return out


def hypr_groupbar_conf(colours: dict[str, str]) -> str:
    p = groupbar_pairs(colours)
    return f"""group {{
    groupbar {{
        text_color = rgb(${p["active_fg"]})
        text_color_inactive = rgb(${p["inactive_fg"]})
        text_color_locked_active = rgb(${p["locked_active_fg"]})
        text_color_locked_inactive = rgb(${p["locked_inactive_fg"]})

        col.active = {hypr_rgba_var(p["active_bg"], "f5")}
        col.inactive = {hypr_rgba_var(p["inactive_bg"], "f5")}
        col.locked_active = {hypr_rgba_var(p["locked_active_bg"], "f5")}
        col.locked_inactive = {hypr_rgba_var(p["locked_inactive_bg"], "f5")}
    }}
}}
"""


_LUA_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua_quote(value: str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_key(key: str) -> str:
    return key if _LUA_IDENT.match(key) else f"[{lua_quote(key)}]"


def scheme_lua(colours: dict[str, str], slug: str, night_temperature: int) -> str:
    """Lua table loaded by hypr/lib/scheme.lua via pcall(dofile): slug, night_temperature, colours, shadow_tint, groupbar."""
    lines = [
        "-- Generated by solanum qm-apply (qm-sync-file-manager-theme.py --emit-lua); do not edit.",
        "return {",
        f"  slug = {lua_quote(slug)},",
        f"  night_temperature = {int(night_temperature)},",
        f"  shadow_tint = {lua_quote(hypr_shadow_tint_hex(colours))},",
        "  colours = {",
    ]
    for key in sorted(colours):
        lines.append(f"    {lua_key(key)} = {lua_quote(colours[key])},")
    lines.append("  },")
    lines.append("  groupbar = {")
    for role, key in sorted(groupbar_pairs(colours).items()):
        lines.append(f"    {role} = {lua_quote(key)},")
    lines.append("  },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def write_scheme_lua(path: Path, colours: dict[str, str], slug: str, night_temperature: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(scheme_lua(colours, slug, night_temperature), encoding="utf-8")
    tmp.replace(path)


def hypr_theme_overrides_conf(colours: dict[str, str]) -> str:
    return hypr_window_glow_vars(colours) + "\n" + hypr_groupbar_conf(colours)


def _write_hypr_conf(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".conf.tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)
    mirror = Path.home() / ".config" / "hypr" / "scheme" / path.name
    if mirror != path and mirror.parent.exists():
        tmp2 = mirror.with_suffix(".conf.tmp")
        tmp2.write_text(content, encoding="utf-8")
        tmp2.replace(mirror)


def write_hypr_groupbar_conf(colours: dict[str, str]) -> None:
    _write_hypr_conf(HYPR_GROUPBAR_CONF, hypr_theme_overrides_conf(colours))
    _write_hypr_conf(HYPR_SHADOW_CONF, hypr_shadow_decoration_conf())


def sync_hypr_scheme(colours: dict[str, str]) -> None:
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return
    conf = hypr_scheme_conf(colours)
    HYPR_SCHEME_CONF.parent.mkdir(parents=True, exist_ok=True)
    tmp = HYPR_SCHEME_CONF.with_suffix(".conf.tmp")
    tmp.write_text(conf, encoding="utf-8")
    tmp.replace(HYPR_SCHEME_CONF)
    hypr_cfg = Path.home() / ".config" / "hypr" / "scheme" / "current.conf"
    if hypr_cfg != HYPR_SCHEME_CONF and hypr_cfg.parent.exists():
        tmp_cfg = hypr_cfg.with_suffix(".conf.tmp")
        tmp_cfg.write_text(conf, encoding="utf-8")
        tmp_cfg.replace(hypr_cfg)
    write_hypr_groupbar_conf(colours)
    subprocess.run([hyprctl, "reload"], check=False, capture_output=True, timeout=10)


def pick(c: dict[str, str], key: str, fallback: str) -> str:
    v = c.get(key)
    if v:
        return v
    return norm_hex(fallback)


def qt_palette_strings(c: dict[str, str]) -> tuple[str, str, str]:
    ws = pick(c, "onSurface", "dce8e6")
    ws_m = pick(c, "onSurfaceVariant", "a2adac")
    surf = pick(c, "surface", "0a0f0f")
    s_low = pick(c, "surfaceContainerLow", "0e1514")
    s_mid = pick(c, "surfaceContainer", "131b1a")
    s_hi = pick(c, "surfaceContainerHigh", "192120")
    s_max = pick(c, "surfaceContainerHighest", "1d2827")
    out_v = pick(c, "outlineVariant", "3f4a49")
    sh = pick(c, "shadow", "000000")
    pr = pick(c, "primary", "9bd0cc")
    pc = pick(c, "primaryContainer", "255b58")
    on_pc = pick(c, "onPrimaryContainer", "b8ede9")
    ter = pick(c, "tertiary", "b6e3fe")
    light = blend_towards(s_mid, "ffffff", 0.14)
    dark = blend_towards(surf, "000000", 0.22)
    bright = pick(c, "onError", "ffffff")
    ph = pick(c, "onSurfaceVariant", "a2adac")

    def row(
        window_text: str,
        text: str,
        btn_text: str,
        base_bg: str,
        window_bg: str,
        bright_t: str,
    ) -> list[str]:
        return [
            to_aarrggbb(window_text),
            to_aarrggbb(s_hi),
            to_aarrggbb(light),
            to_aarrggbb(s_mid),
            to_aarrggbb(dark),
            to_aarrggbb(out_v),
            to_aarrggbb(text),
            to_aarrggbb(bright_t),
            to_aarrggbb(btn_text),
            to_aarrggbb(base_bg),
            to_aarrggbb(window_bg),
            to_aarrggbb(sh),
            to_aarrggbb(pc),
            to_aarrggbb(on_pc),
            to_aarrggbb(pr),
            to_aarrggbb(ter),
            to_aarrggbb(s_mid),
            to_aarrggbb(ws),
            to_aarrggbb(s_max),
            to_aarrggbb(ws),
            to_aarrggbb(ph, 128),
        ]

    active = row(ws, ws, ws, surf, s_low, bright)
    inactive = row(ws_m, ws_m, ws_m, blend_towards(surf, "000000", 0.06), blend_towards(s_low, "000000", 0.06), bright)
    disabled = row(ws_m, ws_m, ws_m, blend_towards(surf, "ffffff", 0.04), blend_towards(s_low, "ffffff", 0.04), bright)

    def fmt(lst: list[str]) -> str:
        return ", ".join(lst)

    return fmt(active), fmt(inactive), fmt(disabled)


def write_qtct_colors(c: dict[str, str]) -> Path:
    root = Path.home() / ".config" / "qt6ct"
    conf_name = "qt6ct.conf"
    col_dir = root / "colors"
    col_dir.mkdir(parents=True, exist_ok=True)
    path = col_dir / f"{KDE_SCHEME_KEY}.conf"
    legacy_path = col_dir / f"{LEGACY_KDE_SCHEME_KEY}.conf"
    a, i, d = qt_palette_strings(c)
    body = (
        "[ColorScheme]\n"
        f"active_colors={a}\n"
        f"inactive_colors={i}\n"
        f"disabled_colors={d}\n"
    )
    path.write_text(body, encoding="utf-8")
    legacy_path.write_text(body, encoding="utf-8")
    cfgp = configparser.ConfigParser(interpolation=None)
    cfgp.optionxform = str
    conf = root / conf_name
    cfgp.read(conf, encoding="utf-8")
    if "Appearance" not in cfgp:
        cfgp["Appearance"] = {}
    app = cfgp["Appearance"]
    if not str(app.get("style", "")).strip():
        app["style"] = "Fusion"
    app["custom_palette"] = "true"
    # Point qt6ct at the new scheme only when unset or still on the Caelestia-era one (respect other choices).
    current = str(app.get("color_scheme_path", "")).strip()
    if not current or Path(current).name == legacy_path.name:
        app["color_scheme_path"] = str(path.resolve())
    with conf.open("w", encoding="utf-8") as f:
        cfgp.write(f, space_around_delimiters=False)
    return path


def kitty_conf_from_scheme(c: dict[str, str]) -> str:
    fg = pick(c, "onSurface", "dce8e6")
    bg = pick(c, "surface", "0a0f0f")
    cur = pick(c, "primary", "9bd0cc")
    sel_bg = pick(c, "primaryContainer", "255b58")
    sel_fg = pick(c, "onPrimaryContainer", "b8ede9")
    url = pick(c, "primary", "9bd0cc")
    lines = [
        "# Generated by solanum (Caelestia scheme) — do not edit",
        f"foreground            {hx(fg)}",
        f"background            {hx(bg)}",
        f"selection_foreground  {hx(sel_fg)}",
        f"selection_background  {hx(sel_bg)}",
        f"cursor                  {hx(cur)}",
        f"cursor_text_color       {hx(bg)}",
        f"url_color               {hx(url)}",
    ]
    for n in range(16):
        key = f"term{n}"
        fb = ("000000", "cc0000", "4e9a06", "c4a000", "3465a4", "75507b", "06989a", "d3d7cf",
              "555753", "ef2929", "8ae234", "fce94f", "729fcf", "ad7fa8", "34e2e2", "eeeeec")[n]
        lines.append(f"color{n}                  {hx(pick(c, key, fb))}")
    return "\n".join(lines) + "\n"


def ensure_kitty_include(kitty_dir: Path) -> None:
    """Ensure kitty.conf pulls in solanum.conf (colors + remote control live there)."""
    kitty_dir.mkdir(parents=True, exist_ok=True)
    dest = kitty_dir / "kitty.conf"
    qm_inc = "include solanum.conf"
    block = f"# BEGIN solanum\n{qm_inc}\n# END solanum\n"
    stale_res = [
        re.compile(r"^# solanum: listen_on \+ allow_remote_control so qm-apply can run\n?", re.M),
        re.compile(r"^# kitten @ --to … set-colors without a controlling TTY\.\n?", re.M),
        re.compile(r"^allow_remote_control socket\n?", re.M),
        re.compile(rf"^listen_on unix:\$\{{XDG_RUNTIME_DIR\}}/{re.escape(KITTY_LISTEN_SOCK_NAME)}\n?", re.M),
        re.compile(rf"^listen_on unix:\$\{{XDG_RUNTIME_DIR\}}/{re.escape(LEGACY_KITTY_LISTEN_SOCK_NAME)}\n?", re.M),
        re.compile(rf"^include {re.escape(KITTY_COLORS_FILE)}\n?", re.M),
        re.compile(rf"^include {re.escape(LEGACY_KITTY_COLORS_FILE)}\n?", re.M),
    ]
    if dest.is_file():
        body = dest.read_text(encoding="utf-8")
        cleaned = body
        for rx in stale_res:
            cleaned = rx.sub("", cleaned)
        if qm_inc not in cleaned:
            cleaned = block + cleaned.lstrip("\n")
        if cleaned != body:
            dest.write_text(cleaned, encoding="utf-8")
        return
    dest.write_text(block, encoding="utf-8")


def refresh_kitty_colors(colors_file: Path) -> bool:
    exe = shutil.which("kitten") or shutil.which("kitty")
    if not exe:
        return False
    kitty_conf = Path.home() / ".config" / "kitty" / "kitty.conf"
    addrs = kitty_rc_candidate_addresses(kitty_conf)
    dbg = os.environ.get("CAELESTIA_QM_DEBUG", "").strip() not in ("", "0", "false", "no")
    last_r: subprocess.CompletedProcess[str] | None = None

    def run_rc(args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [exe, "@", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=12,
        )

    for to in addrs:
        last_r = run_rc(
            [
                "--to",
                to,
                "set-colors",
                "--all",
                "--configured",
                str(colors_file),
            ]
        )
        if last_r.returncode == 0:
            return True

    if kitty_conf.is_file():
        kcf = str(kitty_conf.resolve())
        for to in addrs:
            last_r = run_rc(["--to", to, "load-config", kcf])
            if last_r.returncode == 0:
                return True

    if dbg and last_r is not None:
        tail = (last_r.stderr or last_r.stdout or "").strip()
        if tail:
            print(f"solanum: kitty remote control failed: {tail}", file=sys.stderr)
        else:
            first = repr(addrs[0]) if addrs else "none"
            print(
                f"solanum: kitty remote failed (exit {last_r.returncode}, "
                f"tried {len(addrs)} --to address(es); first: {first})",
                file=sys.stderr,
            )
    return False


MODES_DIR = Path(__file__).resolve().parent.parent / "modes"


def flavour_from_scheme(scheme_json: Path | None) -> str:
    if scheme_json is None or not scheme_json.is_file():
        return ""
    try:
        data = json.loads(scheme_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    return str(data.get("flavour") or "").strip()


def wallpaper_for_wal(scheme_json: Path | None = None) -> str:
    """Planet wallpaper for the pywal payload (flavour from scheme.json, else current.json)."""
    flavour = flavour_from_scheme(scheme_json)
    candidates: list[Path] = []
    if flavour:
        mode_dir = MODES_DIR / flavour
        candidates.extend(
            mode_dir / "wallpapers" / name for name in ("slot-1.png", "slot-0.png", "center.png")
        )
        candidates.append(mode_dir / "logo.png")
    for state_dir in (QM_STATE_DIR, LEGACY_STATE_DIR):
        cur = state_dir / "current.json"
        if not cur.is_file():
            continue
        try:
            data = json.loads(cur.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        logo = str(data.get("logo") or "").strip()
        if not logo:
            slug = str(data.get("slug") or "").strip()
            if slug:
                mode_dir = MODES_DIR / slug
                candidates.extend(
                    mode_dir / "wallpapers" / name
                    for name in ("slot-1.png", "slot-0.png", "center.png")
                )
            continue
        mode_dir = Path(logo).parent
        candidates.extend(
            mode_dir / "wallpapers" / name for name in ("slot-1.png", "slot-0.png", "center.png")
        )
        candidates.append(Path(logo))
    for wp in candidates:
        if wp.is_file():
            return str(wp.resolve())
    return ""


def wal_colors_from_scheme(c: dict[str, str], wallpaper: str) -> dict:
    """Pywal palette mapped from planet roles (not static term* from base-scheme).

    Pywalfox dark defaults: background=color0, accentPrimary=color10,
    accentSecondary=color13, text=color15. The selected tab and toolbar are
    lighten(color0, 1.25), not a palette index we can set directly.

    firefoxAccentTertiary is that selected-tab color. When it already matches
    lighten(surface), color0 stays the planet surface. A different value
    (Dark Bramble) becomes the selected tab, and color0 is the frame that
    lightens to it.

    Prefer firefoxAccent / firefoxAccentSecondary when set so browser chrome can
    diverge from shell line/spark. Decorative slots stay on planet hues so base
    Catppuccin cyans never leak into Firefox.
    """
    surface = pick(c, "surface", pick(c, "background", "0a0f0f"))
    bg = surface
    ff3_raw = c.get("firefoxAccentTertiary") or ""
    if ff3_raw:
        ff3 = norm_hex(ff3_raw)
        if ff3 != pywalfox_lighten(surface):
            bg = pywalfox_frame_for_selected(ff3)
    fg = pick(c, "onSurface", pick(c, "text", "dce8e6"))
    primary = pick(c, "primary", "9bd0cc")
    secondary = pick(c, "secondary", "b0ccc9")
    tertiary = pick(c, "tertiary", "b6e3fe")
    ff = pick(c, "firefoxAccent", primary)
    ff2 = pick(c, "firefoxAccentSecondary", tertiary)
    error = pick(c, "error", "fa746f")
    dim = pick(c, "surfaceContainerHigh", pick(c, "outline", "3f4a49"))
    # Planet-local aliases only (fall back to shell accents, never base-scheme teal junk).
    green = pick(c, "green", secondary)
    yellow = pick(c, "yellow", ff2)
    blue = pick(c, "blue", ff)
    mauve = pick(c, "mauve", secondary)
    teal = pick(c, "teal", ff)
    sky = pick(c, "sky", ff2)

    # Indices matter for Pywalfox: 0=bg, 10=primary accent, 13=secondary accent, 15=text.
    slots = (
        bg,  # 0
        error,  # 1
        green,  # 2
        yellow,  # 3
        blue,  # 4
        mauve,  # 5
        teal,  # 6
        fg,  # 7
        dim,  # 8
        error,  # 9
        ff,  # 10 — toolbar icons / accent
        yellow,  # 11
        blue,  # 12
        ff2,  # 13 — attention / secondary accent
        sky,  # 14
        fg,  # 15 — text
    )
    colors = {f"color{n}": hx(slots[n]) for n in range(16)}
    return {
        "wallpaper": wallpaper,
        "alpha": "100",
        "special": {
            "background": hx(bg),
            "foreground": hx(fg),
            "cursor": hx(ff),
        },
        "colors": colors,
    }


def write_wal_colors(c: dict[str, str], scheme_json: Path | None = None) -> Path:
    WAL_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    payload = wal_colors_from_scheme(c, wallpaper_for_wal(scheme_json))
    path = WAL_CACHE_DIR / "colors.json"
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=4) + "\n", encoding="utf-8")
    tmp.replace(path)
    # Plain list some tools still expect alongside colors.json.
    lines = [payload["colors"][f"color{n}"] for n in range(16)]
    (WAL_CACHE_DIR / "colors").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def qm_pywalfox_host_path() -> Path:
    return Path(__file__).resolve().parent / "qm-pywalfox-host"


def ensure_qm_pywalfox_host() -> None:
    """Install our native-messaging manifest unless another Pywalfox host already owns it."""
    host = qm_pywalfox_host_path()
    if not host.is_file():
        return
    try:
        if not os.access(host, os.X_OK):
            host.chmod(host.stat().st_mode | 0o111)
        subprocess.run(
            [str(host), "install"],
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def trigger_pywalfox_update() -> bool:
    """Ask a running Pywalfox native host to push colors into Firefox."""
    if PYWALFOX_SOCKET.exists():
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            try:
                sock.connect(str(PYWALFOX_SOCKET))
                sock.send(PYWALFOX_UPDATE_CMD.encode("utf-8"))
            finally:
                sock.close()
            return True
        except OSError:
            pass
    for exe in (shutil.which("pywalfox"), str(qm_pywalfox_host_path())):
        if not exe or (exe.endswith("qm-pywalfox-host") and not Path(exe).is_file()):
            continue
        try:
            r = subprocess.run(
                [exe, "update"],
                check=False,
                capture_output=True,
                text=True,
                timeout=8,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if r.returncode == 0:
            return True
    return False


def sync_firefox_theme(c: dict[str, str], scheme_json: Path | None = None) -> None:
    """Emit pywal colors and, if Pywalfox is connected, refresh the browser theme."""
    write_wal_colors(c, scheme_json)
    ensure_qm_pywalfox_host()
    # Brief pause so the native host sees a settled colors.json before the push.
    time.sleep(0.05)
    if trigger_pywalfox_update():
        return
    dbg = os.environ.get("CAELESTIA_QM_DEBUG", "").strip() not in ("", "0", "false", "no")
    if dbg:
        print(
            "solanum: Firefox theme colors written; "
            "install the Pywalfox add-on, restart Firefox, and Fetch Pywal colors once",
            file=sys.stderr,
        )


def kde_colors_ini(c: dict[str, str]) -> str:
    win = pick(c, "surfaceContainerLow", "0e1514")
    win_alt = pick(c, "surfaceContainer", "131b1a")
    view = pick(c, "surface", "0a0f0f")
    view_alt = pick(c, "surfaceContainerLow", "0e1514")
    txt = pick(c, "onSurface", "dce8e6")
    txt_muted = pick(c, "onSurfaceVariant", "a2adac")
    sel_bg = pick(c, "primaryContainer", "255b58")
    sel_fg = pick(c, "onPrimaryContainer", "b8ede9")
    link = pick(c, "primary", "9bd0cc")
    visited = pick(c, "tertiary", "b6e3fe")
    neg = pick(c, "error", "c01c28")
    pos = pick(c, "success", "26a269")
    neu = pick(c, "outline", "6d7876")
    active = pick(c, "secondary", "b0ccc9")
    tip_bg = pick(c, "surfaceContainerHighest", "1d2827")
    tip_fg = pick(c, "onSurface", "dce8e6")
    btn = pick(c, "surfaceContainerHigh", "192120")
    deco = pick(c, "outline", "6d7876")
    wm = pick(c, "surfaceContainerLow", "0e1514")
    wm_in = pick(c, "surfaceContainer", "131b1a")
    wm_txt_dim = pick(c, "onSurfaceVariant", "a2adac")

    def block(
        bg_n: str,
        bg_a: str,
        fg: str,
        fg_in: str,
        fg_link: str,
        fg_vis: str,
    ) -> dict[str, str]:
        return {
            "BackgroundNormal": rgb_csv(bg_n),
            "BackgroundAlternate": rgb_csv(bg_a),
            "DecorationFocus": rgb_csv(deco),
            "DecorationHover": rgb_csv(deco),
            "ForegroundActive": rgb_csv(active),
            "ForegroundInactive": rgb_csv(fg_in),
            "ForegroundLink": rgb_csv(fg_link),
            "ForegroundNegative": rgb_csv(neg),
            "ForegroundNeutral": rgb_csv(neu),
            "ForegroundNormal": rgb_csv(fg),
            "ForegroundPositive": rgb_csv(pos),
            "ForegroundVisited": rgb_csv(fg_vis),
        }

    b_win = block(win, win_alt, txt, txt_muted, link, visited)
    b_view = block(view, view_alt, txt, txt_muted, link, visited)
    b_sel = block(sel_bg, sel_bg, sel_fg, txt_muted, link, visited)
    b_btn = block(btn, btn, txt, txt_muted, link, visited)
    b_tip = block(tip_bg, tip_bg, tip_fg, txt_muted, link, visited)
    b_comp = dict(b_win)
    b_header = block(btn, win, txt, txt_muted, link, visited)
    b_header_inactive = block(win, btn, txt, txt_muted, link, visited)

    def emit_section(title: str, d: dict[str, str]) -> list[str]:
        out = [title]
        out.extend(f"{k}={v}" for k, v in d.items())
        out.append("")
        return out

    lines = [
        "[ColorEffects:Disabled]",
        "Color=112,111,110",
        "ColorAmount=0",
        "ColorEffect=0",
        "ContrastAmount=0.65",
        "ContrastEffect=1",
        "IntensityAmount=0.1",
        "IntensityEffect=2",
        "",
        "[ColorEffects:Inactive]",
        "ChangeSelectionColor=true",
        "Color=112,111,110",
        "ColorAmount=0.025",
        "ColorEffect=2",
        "ContrastAmount=0.1",
        "ContrastEffect=2",
        "Enable=false",
        "IntensityAmount=0",
        "IntensityEffect=0",
        "",
    ]
    for title, d in (
        ("[Colors:Button]", b_btn),
        ("[Colors:Complementary]", b_comp),
        ("[Colors:Header]", b_header),
        ("[Colors:Header][Inactive]", b_header_inactive),
        ("[Colors:Selection]", b_sel),
        ("[Colors:Tooltip]", b_tip),
        ("[Colors:View]", b_view),
        ("[Colors:Window]", b_win),
    ):
        lines.extend(emit_section(title, d))
    lines.extend(
        [
            "[General]",
            f"ColorScheme={KDE_SCHEME_KEY}",
            "Name=Caelestia Quantum Moon",
            "shadeSortColumn=true",
            "",
            "[KDE]",
            "contrast=4",
            "",
            "[WM]",
            f"activeBackground={rgb_csv(wm)}",
            f"activeBlend={rgb_csv(txt)}",
            f"activeForeground={rgb_csv(txt)}",
            f"inactiveBackground={rgb_csv(wm_in)}",
            f"inactiveBlend={rgb_csv(wm_txt_dim)}",
            f"inactiveForeground={rgb_csv(wm_txt_dim)}",
            "",
        ]
    )
    return "\n".join(lines)


def libadwaita_root_block(c: dict[str, str], selector: str = ":root") -> str:
    window_bg = pick(c, "surfaceContainerLow", "0e1514")
    window_fg = pick(c, "onSurface", "dce8e6")
    view_bg = pick(c, "surfaceContainer", "131b1a")
    view_fg = pick(c, "onSurface", "dce8e6")
    header_bg = pick(c, "surfaceContainerHigh", "192120")
    sidebar_bg = pick(c, "surfaceContainerLow", "0e1514")
    sidebar_fg = pick(c, "onSurfaceVariant", "a2adac")
    sidebar_back = pick(c, "surfaceContainerLowest", "000000")
    if sidebar_back == sidebar_bg:
        sidebar_back = pick(c, "surfaceDim", "0a0f0f")
    pop_bg = pick(c, "surfaceContainerHighest", "1d2827")
    card_bg = pick(c, "surfaceContainerHigh", "192120")
    accent_bg = pick(c, "primary", "9bd0cc")
    accent_fg = pick(c, "onPrimary", "0d4845")
    accent_standalone = pick(c, "primaryFixedDim", "a9deda")
    destructive_bg = pick(c, "error", "c01c28")
    destructive_fg = pick(c, "onError", "ffffff")
    success_bg = pick(c, "success", "26a269")
    success_fg = pick(c, "onSuccess", "ffffff")
    err_bg = pick(c, "errorContainer", "871f21")
    err_fg = pick(c, "onErrorContainer", "ff9993")

    def v(name: str, colour: str) -> str:
        return f"  {name}: {hx(colour)};\n"

    parts = [
        f"{selector} {{\n",
        v("--window-bg-color", window_bg),
        v("--window-fg-color", window_fg),
        v("--view-bg-color", view_bg),
        v("--view-fg-color", view_fg),
        v("--headerbar-bg-color", header_bg),
        v("--headerbar-fg-color", window_fg),
        v("--headerbar-border-color", pick(c, "outline", "6d7876")),
        v("--headerbar-backdrop-color", window_bg),
        "  --headerbar-shade-color: rgba(0, 0, 0, 0.36);\n",
        "  --headerbar-darker-shade-color: rgba(0, 0, 0, 0.5);\n",
        v("--sidebar-bg-color", sidebar_bg),
        v("--sidebar-fg-color", sidebar_fg),
        v("--sidebar-backdrop-color", sidebar_back),
        "  --sidebar-border-color: rgba(0, 0, 0, 0.36);\n",
        "  --sidebar-shade-color: rgba(0, 0, 0, 0.25);\n",
        v("--secondary-sidebar-bg-color", view_bg),
        v("--secondary-sidebar-fg-color", view_fg),
        v("--secondary-sidebar-backdrop-color", window_bg),
        "  --secondary-sidebar-border-color: rgba(0, 0, 0, 0.36);\n",
        "  --secondary-sidebar-shade-color: rgba(0, 0, 0, 0.25);\n",
        v("--card-bg-color", card_bg),
        v("--card-fg-color", view_fg),
        "  --card-shade-color: rgba(0, 0, 0, 0.36);\n",
        v("--dialog-bg-color", pop_bg),
        v("--dialog-fg-color", window_fg),
        v("--popover-bg-color", pop_bg),
        v("--popover-fg-color", window_fg),
        "  --popover-shade-color: rgba(0, 0, 0, 0.25);\n",
        v("--accent-bg-color", accent_bg),
        v("--accent-fg-color", accent_fg),
        v("--accent-color", accent_standalone),
        v("--destructive-bg-color", destructive_bg),
        v("--destructive-fg-color", destructive_fg),
        v("--destructive-color", pick(c, "error", "c01c28")),
        v("--success-bg-color", success_bg),
        v("--success-fg-color", success_fg),
        v("--success-color", pick(c, "success", "26a269")),
        "  --warning-bg-color: #cd9309;\n",
        "  --warning-fg-color: rgba(0, 0, 0, 0.8);\n",
        "  --warning-color: #ffc252;\n",
        v("--error-bg-color", err_bg),
        v("--error-fg-color", err_fg),
        v("--error-color", pick(c, "error", "c01c28")),
        v("--thumbnail-bg-color", pick(c, "surfaceContainerHighest", "1d2827")),
        v("--thumbnail-fg-color", view_fg),
        "  --shade-color: rgba(0, 0, 0, 0.25);\n",
        "  --scrollbar-outline-color: rgba(255, 255, 255, 0.35);\n",
        "}\n",
    ]
    return "".join(parts)


def nautilus_surfaces_css(c: dict[str, str]) -> str:
    win = hx(pick(c, "surfaceContainerLow", "0e1514"))
    txt = hx(pick(c, "onSurface", "dce8e6"))
    view = hx(pick(c, "surfaceContainer", "131b1a"))
    side = hx(pick(c, "surfaceContainerLow", "0e1514"))
    side_txt = hx(pick(c, "onSurfaceVariant", "a2adac"))
    head = hx(pick(c, "surfaceContainerHigh", "192120"))
    sel_bg = hx(pick(c, "primaryContainer", "255b58"))
    sel_fg = hx(pick(c, "onPrimaryContainer", "b8ede9"))
    primary = hx(pick(c, "primary", "9bd0cc"))
    tertiary = hx(pick(c, "tertiary", "7fc8ff"))
    secondary = hx(pick(c, "secondary", "73f8b7"))
    outline = hx(pick(c, "outlineVariant", "22503a"))
    hdr_row = hx(pick(c, "surfaceContainerHighest", "002c1a"))
    imp = " !important"
    return (
        "/* Nautilus (libadwaita): direct paints + !important (tokens/cache ignore user gtk.css otherwise). */\n"
        "window.nautilus-window,\n"
        ".nautilus-window.background,\n"
        ".nautilus-window.unified {\n"
        f"  background-color: {win}{imp};\n"
        f"  color: {txt}{imp};\n"
        f"  border: 2px solid {primary}{imp};\n"
        "  border-radius: 2px;\n"
        "}\n"
        ".nautilus-window .sidebar-pane,\n"
        ".nautilus-window placessidebar,\n"
        ".nautilus-window placessidebar list,\n"
        ".nautilus-window .navigation-sidebar {\n"
        f"  background-color: {side}{imp};\n"
        f"  color: {side_txt}{imp};\n"
        f"  border-right: 1px solid {outline}{imp};\n"
        "}\n"
        ".nautilus-window .nautilus-list-view.view,\n"
        ".nautilus-window .nautilus-grid-view,\n"
        ".nautilus-window scrolledwindow > viewport > widget {\n"
        f"  background-color: {view}{imp};\n"
        f"  color: {txt}{imp};\n"
        "}\n"
        ".nautilus-window headerbar,\n"
        ".nautilus-window headerbar:backdrop {\n"
        f"  background-color: {head}{imp};\n"
        f"  color: {txt}{imp};\n"
        f"  border-bottom: 1px solid {primary}{imp};\n"
        "  border-radius: 0;\n"
        "  box-shadow: none;\n"
        "}\n"
        ".nautilus-window row:selected {\n"
        f"  background-color: {sel_bg}{imp};\n"
        f"  color: {sel_fg}{imp};\n"
        f"  border-left: 2px solid {tertiary}{imp};\n"
        "  border-radius: 0;\n"
        "}\n"
        ".sidebar.navigation-sidebar {\n"
        f"  background-color: {side}{imp};\n"
        f"  color: {side_txt}{imp};\n"
        "}\n"
        "/* List / places section headers — lighter chip + primary edge + tertiary label. */\n"
        ".nautilus-window listview > row.header,\n"
        ".nautilus-window list view > row.header,\n"
        ".nautilus-window .nautilus-list-view row.header,\n"
        ".nautilus-window row.header,\n"
        ".nautilus-window .list-header,\n"
        ".navigation-sidebar row.sidebar-header,\n"
        ".nautilus-window placessidebar row.sidebar-header {\n"
        f"  background-color: {hx(pick(c, 'surfaceBright', pick(c, 'surfaceContainerHighest', '002c1a')))}{imp};\n"
        f"  color: {tertiary}{imp};\n"
        f"  border: none{imp};\n"
        f"  border-left: 2px solid {primary}{imp};\n"
        f"  border-bottom: 1px solid {outline}{imp};\n"
        "  border-radius: 0;\n"
        "  font-weight: 600;\n"
        "  letter-spacing: 1px;\n"
        "  text-transform: uppercase;\n"
        "  min-height: 28px;\n"
        "  padding-left: 8px;\n"
        "}\n"
        ".nautilus-window listview > row.header label,\n"
        ".nautilus-window row.header label,\n"
        ".navigation-sidebar row.sidebar-header label {\n"
        f"  color: {tertiary}{imp};\n"
        "}\n"
        f".nautilus-window .pathbar,\n"
        f".nautilus-window entry {{\n"
        f"  border: 1px solid {outline}{imp};\n"
        f"  border-radius: 2px;\n"
        f"  outline-color: {secondary};\n"
        f"}}\n"
    )


def gtk4_reorder_imports_first(css: str) -> str:
    lines = css.splitlines()
    imports: list[str] = []
    rest: list[str] = []
    seen: set[str] = set()
    for raw in lines:
        line = raw.strip()
        if line.startswith("@import"):
            if line not in seen:
                seen.add(line)
                imports.append(line)
            continue
        rest.append(raw)
    if not imports:
        return css
    while rest and not rest[0].strip():
        rest.pop(0)
    return "\n".join(imports) + "\n\n" + "\n".join(rest).rstrip() + ("\n" if rest else "")


def rgba(hex6: str, alpha: float) -> str:
    r, g, b = hx_to_rgb(hex6)
    return f"rgba({r}, {g}, {b}, {alpha})"


def gtk3_block(c: dict[str, str]) -> str:
    base = pick(c, "surfaceContainer", "131b1a")
    text = pick(c, "onSurface", "dce8e6")
    sel_bg = pick(c, "primaryContainer", "255b58")
    sel_fg = pick(c, "onPrimaryContainer", "b8ede9")
    return (
        f"@define-color theme_bg_color {hx(base)};\n"
        f"@define-color theme_fg_color {hx(text)};\n"
        f"@define-color theme_base_color {hx(pick(c, 'surface', '0a0f0f'))};\n"
        f"@define-color theme_text_color {hx(text)};\n"
        f"@define-color theme_selected_bg_color {hx(sel_bg)};\n"
        f"@define-color theme_selected_fg_color {hx(sel_fg)};\n"
        f"@define-color insensitive_bg_color {hx(pick(c, 'surfaceContainerLow', '0e1514'))};\n"
        f"@define-color insensitive_fg_color {hx(pick(c, 'onSurfaceVariant', 'a2adac'))};\n"
        f"@define-color insensitive_base_color {hx(pick(c, 'surfaceContainerLow', '0e1514'))};\n"
        f"@define-color insensitive_text_color {hx(pick(c, 'onSurfaceVariant', 'a2adac'))};\n"
        f"@define-color link_color {hx(pick(c, 'primary', '9bd0cc'))};\n"
    )


def gtk4_flatpak_config_dirs() -> list[Path]:
    base = Path.home() / ".var" / "app"
    if not base.is_dir():
        return []
    out: list[Path] = []
    for app_id in ("org.gnome.Nautilus", "org.gnome.Files"):
        if (base / app_id).is_dir():
            out.append(base / app_id / "config" / "gtk-4.0")
    return out


def merge_gtk4_prefer_dark(gtk4_dir: Path, scheme_json: Path) -> None:
    try:
        data = json.loads(scheme_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        prefer_dark = True
    else:
        prefer_dark = str(data.get("mode", "dark")).lower() != "light"
    val = "1" if prefer_dark else "0"
    gtk4_dir.mkdir(parents=True, exist_ok=True)
    ini = gtk4_dir / "settings.ini"
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.optionxform = str
    cfg.read(ini, encoding="utf-8")
    if "Settings" not in cfg:
        cfg["Settings"] = {}
    cfg["Settings"]["gtk-application-prefer-dark-theme"] = val
    with ini.open("w", encoding="utf-8") as f:
        cfg.write(f, space_around_delimiters=False)


def sync_gtk4_everywhere(cfg_home: Path, c: dict[str, str], scheme_json: Path) -> None:
    sync_gtk4_user_css(cfg_home / "gtk-4.0", c)
    merge_gtk4_prefer_dark(cfg_home / "gtk-4.0", scheme_json)
    for fd in gtk4_flatpak_config_dirs():
        sync_gtk4_user_css(fd, c)
        merge_gtk4_prefer_dark(fd, scheme_json)
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "solanum"
    state.mkdir(parents=True, exist_ok=True)
    lines = [
        datetime.datetime.now().isoformat(timespec="seconds"),
        f"host_gtk4={cfg_home / 'gtk-4.0' / 'gtk.css'}",
    ]
    for fd in gtk4_flatpak_config_dirs():
        lines.append(f"flatpak_gtk4={fd / 'gtk.css'}")
    (state / "last-gtk-sync.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def strip_gtk4_managed_blocks(css: str) -> str:
    while True:
        m = GTK4_USER_BLOCK_RE.search(css)
        if not m:
            return css
        css = css[: m.start()] + css[m.end() :]


def strip_gtk4_legacy_import(css: str) -> str:
    prev = None
    while prev != css:
        prev = css
        css = GTK4_LEGACY_IMPORT.sub("", css)
    return css


def gtk4_define_color_block(c: dict[str, str]) -> str:
    pr = pick(c, "primary", "9bd0cc")
    on_pr = pick(c, "onPrimary", "0d4845")
    win_bg = pick(c, "surfaceContainerLow", "0e1514")
    win_fg = pick(c, "onSurface", "dce8e6")
    hdr_bg = pick(c, "surfaceContainerHigh", "192120")
    pop_bg = pick(c, "surfaceContainerHighest", "1d2827")
    view_bg = pick(c, "surfaceContainer", "131b1a")
    card_bg = pick(c, "surfaceContainerHigh", "192120")
    side_bg = pick(c, "surfaceContainerLow", "0e1514")
    side_fg = pick(c, "onSurfaceVariant", "a2adac")
    ol = pick(c, "outline", "6d7876")
    side_back = pick(c, "surfaceDim", "0a0f0f")
    sel_bg = pick(c, "primaryContainer", "255b58")
    sel_fg = pick(c, "onPrimaryContainer", "b8ede9")
    lines = [
        f"@define-color accent_color {hx(pr)};",
        f"@define-color accent_fg_color {hx(on_pr)};",
        f"@define-color accent_bg_color {hx(pr)};",
        f"@define-color window_bg_color {hx(win_bg)};",
        f"@define-color window_fg_color {hx(win_fg)};",
        f"@define-color headerbar_bg_color {hx(hdr_bg)};",
        f"@define-color headerbar_fg_color {hx(win_fg)};",
        f"@define-color popover_bg_color {hx(pop_bg)};",
        f"@define-color popover_fg_color {hx(win_fg)};",
        f"@define-color view_bg_color {hx(view_bg)};",
        f"@define-color view_fg_color {hx(win_fg)};",
        f"@define-color card_bg_color {hx(card_bg)};",
        f"@define-color card_fg_color {hx(win_fg)};",
        f"@define-color sidebar_bg_color {hx(side_bg)};",
        f"@define-color sidebar_fg_color {hx(side_fg)};",
        f"@define-color sidebar_border_color {hx(ol)};",
        f"@define-color sidebar_backdrop_color {hx(side_back)};",
        f"@define-color theme_selected_bg_color {hx(sel_bg)};",
        f"@define-color theme_selected_fg_color {hx(sel_fg)};",
    ]
    return "\n".join(lines)


def sync_gtk4_user_css(gtk4_dir: Path, c: dict[str, str]) -> None:
    gtk4_dir.mkdir(parents=True, exist_ok=True)
    path = gtk4_dir / "gtk.css"
    body = path.read_text(encoding="utf-8") if path.is_file() else ""
    body = strip_gtk4_managed_blocks(body)
    body = strip_gtk4_legacy_import(body)
    body = gtk4_reorder_imports_first(body)
    block = (
        f"{GTK4_BLOCK_BEGIN}\n"
        f"{gtk4_define_color_block(c)}\n"
        f"{libadwaita_root_block(c, ':root')}"
        f"{nautilus_surfaces_css(c)}"
        f"{GTK4_BLOCK_END}\n"
    )
    path.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")


def ensure_gtk3_import(gtk3_dir: Path) -> None:
    gtk3_dir.mkdir(parents=True, exist_ok=True)
    dest = gtk3_dir / "gtk.css"
    marker = "solanum: gtk3 sync"
    if dest.is_file():
        body = dest.read_text(encoding="utf-8")
        if marker in body or "qm-gtk3.css" in body:  # either generated dir counts
            return
        dest.write_text(GTK3_IMPORT_LINE + body, encoding="utf-8")
    else:
        dest.write_text(GTK3_IMPORT_LINE, encoding="utf-8")


def set_kde_color_scheme(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    cfg_dir = path.parent
    fname = path.name
    for bin_name in ("kwriteconfig6", "kwriteconfig5"):
        exe = shutil.which(bin_name)
        if exe:
            subprocess.run(
                [
                    exe,
                    "--file",
                    fname,
                    "--group",
                    "General",
                    "--key",
                    "ColorScheme",
                    KDE_SCHEME_KEY,
                ],
                check=False,
                capture_output=True,
                timeout=5,
                cwd=str(cfg_dir),
            )
            return
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.optionxform = str
    cfg.read(path, encoding="utf-8")
    if "General" not in cfg:
        cfg["General"] = {}
    cfg["General"]["ColorScheme"] = KDE_SCHEME_KEY
    with path.open("w", encoding="utf-8") as f:
        cfg.write(f, space_around_delimiters=False)


def _busctl_filemanager1_property(prop: str) -> dict | None:
    busctl = shutil.which("busctl")
    if not busctl:
        return None
    r = subprocess.run(
        [
            busctl,
            "--json=short",
            "--user",
            "get-property",
            "org.freedesktop.FileManager1",
            "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1",
            prop,
        ],
        capture_output=True,
        text=True,
        timeout=8,
    )
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None


def _hypr_clients() -> list[dict] | None:
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return None
    try:
        r = subprocess.run(
            [hyprctl, "clients", "-j"],
            capture_output=True,
            text=True,
            timeout=6,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, list) else None


def _is_nautilus_client(c: dict) -> bool:
    if not isinstance(c, dict) or not c.get("mapped") or c.get("hidden"):
        return False
    cls = (c.get("class") or "").lower()
    icls = (c.get("initialClass") or "").lower()
    return "nautilus" in cls or "nautilus" in icls


def _addresses_matching(clients: list[dict], match) -> set[str]:
    out: set[str] = set()
    for c in clients:
        if not match(c):
            continue
        addr = c.get("address")
        if addr:
            out.add(str(addr))
    return out


def _geom_from_client(c: dict) -> dict:
    at = c.get("at") or [0, 0]
    sz = c.get("size") or [0, 0]
    ws = c.get("workspace") if isinstance(c.get("workspace"), dict) else {}
    return {
        "at": [int(at[0]), int(at[1])],
        "size": [int(sz[0]), int(sz[1])],
        "workspace_id": ws.get("id"),
        "workspace_name": ws.get("name"),
        "floating": bool(c.get("floating")),
        "pinned": bool(c.get("pinned")),
    }


def _file_uri_path(uri: str) -> str | None:
    if not isinstance(uri, str) or not uri.startswith("file://"):
        return None
    p = urlparse(uri)
    if not p.path:
        return None
    return os.path.normpath(unquote(p.path))


def _title_path_score(title: str, path: str | None) -> int:
    if not path:
        return 0
    t = (title or "").lower()
    pl = path.lower()
    bn = os.path.basename(pl.rstrip(os.sep)).lower()
    score = 0
    if pl and pl in t:
        score += 2000 + min(len(pl), 500)
    if bn and bn in t:
        score += 500 + min(len(bn), 200)
    for part in reversed(pl.split(os.sep)):
        p2 = part.lower()
        if len(p2) >= 2 and p2 in t:
            score += 50
            break
    return score


def _assign_geometry_to_windows(
    windows: list[list[str]], clients: list[dict]
) -> list[dict | None]:
    nclients = [c for c in clients if _is_nautilus_client(c)]
    nclients.sort(
        key=lambda c: (
            (c.get("workspace") or {}).get("id") if isinstance(c.get("workspace"), dict) else 0,
            (c.get("at") or [0, 0])[1],
            (c.get("at") or [0, 0])[0],
            str(c.get("address") or ""),
        )
    )
    used: set[str] = set()
    out: list[dict | None] = []
    for uris in windows:
        path = None
        for u in uris:
            path = _file_uri_path(u)
            if path:
                break
        best_addr: str | None = None
        best_score = -1
        for c in nclients:
            addr = c.get("address")
            if not addr:
                continue
            sa = str(addr)
            if sa in used:
                continue
            title = str(c.get("title") or "")
            sc = _title_path_score(title, path)
            if sc > best_score:
                best_score = sc
                best_addr = str(addr)
        if best_addr is not None and best_score > 0:
            used.add(best_addr)
            c = next(x for x in nclients if str(x.get("address")) == best_addr)
            out.append(_geom_from_client(c))
            continue
        picked: dict | None = None
        for c in nclients:
            addr = c.get("address")
            if not addr:
                continue
            sa = str(addr)
            if sa not in used:
                used.add(sa)
                picked = _geom_from_client(c)
                break
        out.append(picked)
    return out[: len(windows)]


def _hypr_dispatch(arg: str) -> None:
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return
    subprocess.run(
        [hyprctl, "dispatch", arg],
        check=False,
        capture_output=True,
        text=True,
        timeout=5,
    )


def _workspace_moveto_arg(g: dict) -> str | None:
    wid = g.get("workspace_id")
    name = g.get("workspace_name")
    if isinstance(name, str) and name.startswith("special:"):
        return name
    if wid is None:
        return None
    if isinstance(wid, str):
        s = wid.strip()
        if s.startswith("name:") or s.startswith("special:"):
            return s
        return f"name:{s}"
    if isinstance(wid, int) and wid < 0 and isinstance(name, str):
        return name
    return str(wid)


def _restore_client_hypr(address: str, g: dict) -> None:
    warg = _workspace_moveto_arg(g)
    if warg is not None:
        _hypr_dispatch(f"movetoworkspacesilent {warg},address:{address}")
    x, y = g["at"]
    w, h = g["size"]
    if g.get("floating"):
        _hypr_dispatch(f"setfloating,address:{address}")
        _hypr_dispatch(f"resizewindowpixel exact {w} {h},address:{address}")
        _hypr_dispatch(f"movewindowpixel exact {x} {y},address:{address}")
    else:
        _hypr_dispatch(f"settiled,address:{address}")
    if g.get("pinned") and g.get("floating"):
        _hypr_dispatch(f"pin,address:{address}")


def _pick_new_address_by_pid(clients: list[dict], diff: set[str]) -> str:
    best: str | None = None
    best_pid = -1
    for c in clients:
        addr = c.get("address")
        if not addr:
            continue
        sa = str(addr)
        if sa not in diff:
            continue
        try:
            pid = int(c.get("pid") or 0)
        except (TypeError, ValueError):
            pid = 0
        if pid >= best_pid:
            best_pid = pid
            best = sa
    return best if best is not None else sorted(diff)[0]


def _wait_new_client_address(
    prev: set[str],
    want_total: int,
    match,
    timeout: float = 5.0,
) -> str | None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        clients = _hypr_clients()
        if not clients:
            time.sleep(0.05)
            continue
        curr = _addresses_matching(clients, match)
        if len(curr) >= want_total:
            diff = curr - prev
            if diff:
                if len(diff) == 1:
                    return next(iter(diff))
                return _pick_new_address_by_pid(clients, diff)
        time.sleep(0.05)
    return None


def collect_open_nautilus_window_uris() -> list[list[str]]:
    j = _busctl_filemanager1_property("OpenWindowsWithLocations")
    if not j or not isinstance(j.get("data"), dict):
        return []
    data: dict = j["data"]
    if data:
        out: list[list[str]] = []
        for uris in data.values():
            if isinstance(uris, list) and uris:
                row = [str(x) for x in uris if isinstance(x, str) and x]
                if row:
                    out.append(row)
        return out
    j2 = _busctl_filemanager1_property("OpenLocations")
    if j2 and isinstance(j2.get("data"), list):
        locs = [str(x) for x in j2["data"] if isinstance(x, str) and x]
        if locs:
            return [locs]
    return []


def _flatpak_nautilus_app_id() -> str | None:
    if not shutil.which("flatpak"):
        return None
    r = subprocess.run(
        ["flatpak", "list", "--app", "--columns=application"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if r.returncode != 0:
        return None
    apps = {ln.strip() for ln in r.stdout.splitlines() if ln.strip()}
    if "org.gnome.Nautilus" in apps:
        return "org.gnome.Nautilus"
    if "org.gnome.Files" in apps:
        return "org.gnome.Files"
    return None


def kitty_sigusr1_reload_pids() -> list[int]:
    pids = _kitty_pids()
    if not pids:
        return []
    mains: dict[int, None] = {}
    listeners: dict[int, None] = {}
    for pid in pids:
        try:
            env = _read_proc_environ(pid)
        except OSError:
            continue
        if env.get("KITTY_LISTEN_ON"):
            listeners[pid] = None
        kp = env.get("KITTY_PID")
        if kp and str(kp).isdigit():
            mains[int(kp)] = None
    if mains:
        return list(mains.keys())
    if listeners:
        return list(listeners.keys())
    return [min(pids)]


def signal_kitty_reload_config() -> None:
    sig = getattr(signal, "SIGUSR1", None)
    if sig is None:
        return
    for pid in kitty_sigusr1_reload_pids():
        try:
            os.kill(pid, sig)
        except (ProcessLookupError, PermissionError, OSError):
            pass


def reload_kitty_terminals(colors_file: Path) -> None:
    refresh_kitty_colors(colors_file)
    signal_kitty_reload_config()


def _wait_no_nautilus_process(timeout: float = 4.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        r = subprocess.run(
            ["pgrep", "-x", "nautilus"],
            capture_output=True,
            timeout=2,
        )
        if r.returncode != 0:
            return
        time.sleep(0.06)


def _spawn_nautilus_uris(uris: list[str], new_window: bool) -> None:
    if not uris:
        return
    env = os.environ.copy()
    env["GTK_DEBUG"] = "no-css-cache"
    devnull = subprocess.DEVNULL
    nautilus_bin = shutil.which("nautilus")
    if nautilus_bin:
        cmd = [nautilus_bin]
        if new_window:
            cmd.append("--new-window")
        cmd.extend(uris)
        subprocess.Popen(
            cmd,
            env=env,
            stdin=devnull,
            stdout=devnull,
            stderr=devnull,
            start_new_session=True,
        )
        return
    app = _flatpak_nautilus_app_id()
    if not app:
        return
    cmd = [
        "flatpak",
        "run",
        "--env=GTK_DEBUG=no-css-cache",
        app,
        "--",
    ]
    if new_window:
        cmd.append("--new-window")
    cmd.extend(uris)
    subprocess.Popen(
        cmd,
        stdin=devnull,
        stdout=devnull,
        stderr=devnull,
        start_new_session=True,
    )


def stop_nautilus_for_theme_reload() -> None:
    windows = collect_open_nautilus_window_uris()
    geoms: list[dict | None] | None = None
    if windows:
        clients_before = _hypr_clients()
        if clients_before is not None:
            geoms = _assign_geometry_to_windows(windows, clients_before)
    if shutil.which("flatpak"):
        for app in ("org.gnome.Nautilus", "org.gnome.Files"):
            subprocess.run(
                ["flatpak", "kill", app],
                check=False,
                capture_output=True,
                timeout=15,
            )
    if shutil.which("pkill"):
        subprocess.run(
            ["pkill", "-TERM", "-x", "nautilus"],
            check=False,
            capture_output=True,
            timeout=10,
        )
    if not windows:
        return
    _wait_no_nautilus_process()
    use_hypr_restore = bool(
        geoms
        and shutil.which("hyprctl")
        and any(g is not None for g in geoms)
    )
    if use_hypr_restore:
        prev: set[str] = set()
        for i, uris in enumerate(windows):
            _spawn_nautilus_uris(uris, new_window=(i > 0))
            addr = _wait_new_client_address(prev, len(prev) + 1, _is_nautilus_client)
            if addr and i < len(geoms) and geoms[i]:
                _restore_client_hypr(addr, geoms[i])
            if addr:
                prev.add(addr)
    else:
        for i, uris in enumerate(windows):
            _spawn_nautilus_uris(uris, new_window=(i > 0))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("scheme_json", nargs="?", type=Path, default=SCHEME_FILE)
    ap.add_argument("--emit-lua", type=Path, default=None, help="write the Lua scheme table (hypr/lib/scheme.lua input) to PATH and exit")
    ap.add_argument("--meta", type=Path, default=None, help="modes/<slug>/meta.json providing slug + nightTemperature for --emit-lua")
    args = ap.parse_args()
    path: Path = args.scheme_json
    if not path.is_file():
        print(f"missing {path}", file=sys.stderr)
        sys.exit(0)

    c = load_colours(path)

    if args.emit_lua is not None:
        slug, night = "unknown", 4500
        if args.meta is not None and args.meta.is_file():
            meta = json.loads(args.meta.read_text(encoding="utf-8"))
            slug = str(meta.get("slug") or args.meta.parent.name)
            night = int(meta.get("nightTemperature") or 4500)
        write_scheme_lua(args.emit_lua, c, slug, night)
        return

    kde_dir = Path.home() / ".local" / "share" / "color-schemes"
    kde_dir.mkdir(parents=True, exist_ok=True)
    kde_ini = kde_colors_ini(c)
    (kde_dir / KDE_SCHEME_FILE).write_text(kde_ini, encoding="utf-8")
    (kde_dir / LEGACY_KDE_SCHEME_FILE).write_text(kde_ini, encoding="utf-8")

    libadwaita_css = (
        "/* Generated by solanum qm-sync-file-manager-theme — do not edit */\n"
        + libadwaita_root_block(c)
        + nautilus_surfaces_css(c)
    )
    gtk3_css = "/* Generated by solanum — GTK3 companion */\n" + gtk3_block(c)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    for gen_dir in (GENERATED_DIR, LEGACY_GENERATED_DIR):
        if gen_dir != GENERATED_DIR and not gen_dir.is_dir():
            continue  # legacy dir only while it exists (gtk.css import is rewritten by the migration script)
        (gen_dir / "qm-libadwaita.css").write_text(libadwaita_css, encoding="utf-8")
        (gen_dir / "qm-gtk3.css").write_text(gtk3_css, encoding="utf-8")

    cfg_home = Path.home() / ".config"
    sync_gtk4_everywhere(cfg_home, c, path)
    ensure_gtk3_import(cfg_home / "gtk-3.0")

    set_kde_color_scheme(cfg_home / "kdeglobals")

    kdir = cfg_home / "kitty"
    kitty_conf_text = kitty_conf_from_scheme(c)
    kitty_colors = kdir / KITTY_COLORS_FILE
    kdir.mkdir(parents=True, exist_ok=True)
    kitty_colors.write_text(kitty_conf_text, encoding="utf-8")
    (kdir / LEGACY_KITTY_COLORS_FILE).write_text(kitty_conf_text, encoding="utf-8")
    ensure_kitty_include(kdir)
    reload_kitty_terminals(kitty_colors)

    sync_firefox_theme(c, path)

    write_qtct_colors(c)

    for cmd in (
        ["plasma-apply-colorscheme", KDE_SCHEME_KEY],
        ["kapplycolorscheme", KDE_SCHEME_KEY],
    ):
        if shutil.which(cmd[0]):
            subprocess.run(cmd, check=False, capture_output=True, timeout=5)

    stop_nautilus_for_theme_reload()
    if (Path.home() / ".config" / "hypr" / "hyprland.lua").exists():
        # Lua config: colours come from scheme.lua (qm-apply --emit-lua + hyprctl reload); hyprlang writers are skipped.
        return
    sync_hypr_scheme(c)


if __name__ == "__main__":
    main()
