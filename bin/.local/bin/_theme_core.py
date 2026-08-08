#!/usr/bin/env python3
"""Shared SSOT theme engine: extract → match → build → helpers."""
from __future__ import annotations

import colorsys
import json
import math
import os
import re
import tomllib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CFG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
THEME_DIR = CFG / "theme"
# Prefer stowed harmonies; fall back to repo-relative next to this file
DOTFILES_HARMONIES = (
    Path(__file__).resolve().parents[3] / "theme/.config/theme/harmonies.toml"
)
HARMONIES_PATHS = (
    THEME_DIR / "harmonies.toml",
    CFG / "theme" / "harmonies.toml",
    DOTFILES_HARMONIES,
    Path.home() / "dotfiles/theme/.config/theme/harmonies.toml",
)


def ensure_theme_dir() -> Path:
    THEME_DIR.mkdir(parents=True, exist_ok=True)
    return THEME_DIR


def parse_hex(s: str) -> tuple[float, float, float]:
    s = s.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    r, g, b = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)
    return r / 255.0, g / 255.0, b / 255.0


def to_hex(rgb: tuple[float, float, float]) -> str:
    r, g, b = [max(0, min(255, int(round(c * 255)))) for c in rgb]
    return f"#{r:02x}{g:02x}{b:02x}"


def rgb_to_hsl(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    r, g, b = rgb
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0, s, l


def hsl_to_rgb(h: float, s: float, l: float) -> tuple[float, float, float]:
    return colorsys.hls_to_rgb((h % 360.0) / 360.0, l, s)


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rel_lum(rgb: tuple[float, float, float]) -> float:
    r, g, b = rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    la, lb = rel_lum(a), rel_lum(b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


def lerp(a: tuple[float, float, float], b: tuple[float, float, float], t: float):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def ensure_on_bg(
    fg: tuple[float, float, float],
    bg: tuple[float, float, float],
    min_ratio: float,
) -> tuple[float, float, float]:
    if contrast(fg, bg) >= min_ratio:
        return fg
    toward = (1.0, 1.0, 1.0) if rel_lum(bg) < 0.5 else (0.0, 0.0, 0.0)
    best = fg
    for i in range(1, 41):
        cand = lerp(fg, toward, i / 40.0)
        if contrast(cand, bg) >= min_ratio:
            return cand
        best = cand
    return best


def hue_dist(a: float, b: float) -> float:
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def shift_hex(hex_color: str, delta_h: float, sat_scale: float = 1.0) -> str:
    h, s, l = rgb_to_hsl(parse_hex(hex_color))
    s = max(0.0, min(1.0, s * sat_scale))
    # Cap saturation to avoid garish accents
    s = min(s, 0.72)
    return to_hex(hsl_to_rgb(h + delta_h, s, l))


def load_harmonies() -> dict[str, dict[str, Any]]:
    for p in HARMONIES_PATHS:
        if p.is_file():
            data = tomllib.loads(p.read_text())
            return {k: v for k, v in data.items() if isinstance(v, dict)}
    raise FileNotFoundError("harmonies.toml not found")


# ── extract ──────────────────────────────────────────────────────────────


def extract_colors(image_path: Path, max_colors: int = 8) -> list[dict[str, Any]]:
    from PIL import Image

    img = Image.open(image_path).convert("RGB")
    img = img.resize((120, 120), Image.Resampling.BOX)
    # Adaptive palette quantization
    q = img.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
    palette = q.getpalette() or []
    counts: dict[tuple[int, int, int], int] = {}
    for idx in q.getdata():
        i = idx * 3
        if i + 2 >= len(palette):
            continue
        rgb = (palette[i], palette[i + 1], palette[i + 2])
        counts[rgb] = counts.get(rgb, 0) + 1
    total = sum(counts.values()) or 1
    scored: list[tuple[float, tuple[int, int, int]]] = []
    for rgb, n in counts.items():
        rf, gf, bf = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
        h, s, l = rgb_to_hsl((rf, gf, bf))
        # Drop near-black / near-white
        if l < 0.05 or l > 0.95:
            continue
        # Keep low-sat only if mid-dark (surface hints); prefer chroma
        if s < 0.05 and not (0.08 < l < 0.45):
            continue
        weight = n / total
        # Prefer mid-lightness chromatic colors (foliage, sky, sand)
        lum_boost = 1.0 - abs(l - 0.42) * 0.8
        score = weight * (0.35 + 0.65 * s) * max(0.4, lum_boost)
        scored.append((score, rgb))
    scored.sort(reverse=True, key=lambda x: x[0])
    # Renormalize top colors by raw pixel weight among kept
    kept = scored[:max_colors]
    raw_sum = sum(counts[rgb] for _, rgb in kept) or 1
    out = []
    for _, rgb in kept:
        rf, gf, bf = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
        h, s, l = rgb_to_hsl((rf, gf, bf))
        w = counts[rgb] / raw_sum
        out.append(
            {
                "hex": to_hex((rf, gf, bf)),
                "weight": round(w, 4),
                "hsl": [round(h, 1), round(s, 3), round(l, 3)],
            }
        )
    # normalize weights to 1
    tw = sum(c["weight"] for c in out) or 1.0
    for c in out:
        c["weight"] = round(c["weight"] / tw, 4)
    return out


def chroma_weight(colors: list[dict[str, Any]]) -> float:
    return sum(c["weight"] * c["hsl"][1] for c in colors)


def warm_weight(colors: list[dict[str, Any]]) -> float:
    w = 0.0
    for c in colors:
        h, s, l = c["hsl"]
        if s < 0.08 or l < 0.08:
            continue
        # warm hues ~ -30..70 (330..360 and 0..70)
        if h <= 70 or h >= 330:
            w += c["weight"] * s
        elif 70 < h < 110:  # yellow-green weak warm
            w += c["weight"] * s * 0.35
    return w


def dominant_hue(colors: list[dict[str, Any]]) -> float:
    # Prefer mid-lightness chromatic samples (skip near-black murk)
    x = y = 0.0
    for c in colors:
        h, s, l = c["hsl"]
        if l < 0.12:
            continue
        w = c["weight"] * max(s, 0.08) * (0.6 + 0.4 * min(l, 0.7))
        rad = math.radians(h)
        x += math.cos(rad) * w
        y += math.sin(rad) * w
    if x == 0 and y == 0:
        return 28.0  # sand default
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


# ── match ────────────────────────────────────────────────────────────────


def match_harmony(
    colors: list[dict[str, Any]],
    *,
    sand_bias: float = 0.10,
) -> tuple[str, dict[str, Any], float]:
    """Pick a curated harmony.

    Hybrid policy:
    - Low chroma / murky wallpapers → sand (tasteful default the user loves)
    - Warm wallpapers → sand (strong bias) or warm-amber/clay/rose
    - Clearly cool chromatic → sage/slate-teal/mist-blue/lavender
    """
    harmonies = load_harmonies()
    dh = dominant_hue(colors)
    ww = warm_weight(colors)
    cw = chroma_weight(colors)

    # Default to sand when image lacks clear chromatic signal
    if cw < 0.18 or ww >= sand_bias:
        hid = "sand"
        harmony = harmonies["sand"]
        delta = max(-8.0, min(8.0, (dh - float(harmony["hue_center"])) * 0.25))
        return hid, harmony, delta

    best_id = "sand"
    best_score = -1e9
    best_h = harmonies.get("sand", {})
    for hid, hset in harmonies.items():
        center = float(hset.get("hue_center", 0))
        dist = hue_dist(dh, center)
        score = 50.0 - dist
        if hset.get("warm"):
            # cool image: demote warms except mild clay
            score -= 30.0
        else:
            score += 20.0
            if hid == "sage" and 70 <= dh <= 160:
                score += 25.0
            if hid == "slate-teal" and 150 <= dh <= 200:
                score += 20.0
            if hid == "mist-blue" and 190 <= dh <= 250:
                score += 20.0
            if hid == "lavender" and 250 <= dh <= 320:
                score += 10.0  # weaker — easy to look gaudy
        if score > best_score:
            best_score = score
            best_id = hid
            best_h = hset

    delta = dh - float(best_h.get("hue_center", dh))
    delta = max(-12.0, min(12.0, delta * 0.5))
    return best_id, best_h, delta

# ── build surfaces from image ────────────────────────────────────────────


def build_surfaces(image_path: Path) -> dict[str, str]:
    from PIL import Image

    img = Image.open(image_path).convert("RGB").resize((64, 64), Image.Resampling.BOX)
    pixels = list(img.getdata())
    # Average of darker half
    lum_sorted = sorted(pixels, key=lambda p: 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2])
    dark = lum_sorted[: max(1, len(lum_sorted) // 3)]
    avg = tuple(sum(c[i] for c in dark) / len(dark) / 255.0 for i in range(3))
    h, s, l = rgb_to_hsl(avg)
    s = min(s * 0.55, 0.18)
    l = min(max(l * 0.45, 0.06), 0.14)
    bg = hsl_to_rgb(h, s, l)
    surface = hsl_to_rgb(h, s, min(l + 0.02, 0.16))
    container = hsl_to_rgb(h, s * 1.1, min(l + 0.06, 0.22))
    high = hsl_to_rgb(h, s * 1.15, min(l + 0.10, 0.28))
    variant = hsl_to_rgb(h, s * 1.2, min(l + 0.22, 0.38))
    return {
        "background": to_hex(bg),
        "surface": to_hex(surface),
        "surface_container": to_hex(container),
        "surface_container_high": to_hex(high),
        "surface_variant": to_hex(variant),
    }


def build_text(surfaces: dict[str, str], accents: dict[str, str]) -> dict[str, str]:
    bg = parse_hex(surfaces["surface"])
    on = ensure_on_bg(parse_hex("#ebe1d4"), bg, 7.0)
    muted = ensure_on_bg(parse_hex("#d1c5b4"), bg, 4.5)
    on_pri = parse_hex(accents["on_primary"])
    # ensure on_primary readable on primary
    on_pri = ensure_on_bg(on_pri, parse_hex(accents["primary"]), 4.5)
    # if primary is light, on_primary should be dark
    if rel_lum(parse_hex(accents["primary"])) > 0.4:
        on_pri = ensure_on_bg(parse_hex("#1a1008"), parse_hex(accents["primary"]), 4.5)
    return {
        "on_surface": to_hex(on),
        "on_surface_variant": to_hex(muted),
        "on_primary": to_hex(on_pri),
    }


def build_ansi(surfaces: dict[str, str], accents: dict[str, str], text: dict[str, str]) -> dict[str, str]:
    bg = surfaces["background"]
    return {
        "color0": surfaces["surface_container"],
        "color1": accents["error"],
        "color2": accents["secondary"],
        "color3": accents["tertiary"],
        "color4": accents["primary"],
        "color5": accents.get("primary_container", accents["primary"]),
        "color6": accents["secondary"],
        "color7": text["on_surface_variant"],
        "color8": text["on_surface_variant"],
        "color9": accents["error"],
        "color10": accents["secondary"],
        "color11": accents["tertiary"],
        "color12": accents["primary"],
        "color13": accents["primary"],
        "color14": accents["secondary"],
        "color15": text["on_surface"],
        "foreground": text["on_surface"],
        "background": bg,
        "cursor": accents["primary"],
        "cursor_text": text["on_primary"],
        "selection_background": accents["primary"],
        "selection_foreground": text["on_primary"],
        "url_color": accents["secondary"],
        "active_border_color": accents["primary"],
        "inactive_border_color": accents["outline"],
    }


def build_palette(
    wallpaper: Path,
    colors: list[dict[str, Any]],
    harmony_id: str,
    harmony: dict[str, Any],
    delta_h: float,
) -> dict[str, Any]:
    # Keep beloved sand hexes exact (no ensure_on_bg drift for accents)
    if harmony_id == "sand":
        accents = {
            "primary": harmony["primary"],
            "secondary": harmony["secondary"],
            "on_primary": harmony["on_primary"],
            "primary_container": harmony["primary_container"],
            "tertiary": harmony["tertiary"],
            "outline": harmony["outline"],
            "error": harmony.get("error", "#ffb4ab"),
        }
    else:
        sat_scale = 0.92 if not harmony.get("warm") else 1.0
        accents = {
            "primary": shift_hex(harmony["primary"], delta_h, sat_scale),
            "secondary": shift_hex(harmony["secondary"], delta_h, sat_scale),
            "on_primary": harmony["on_primary"],
            "primary_container": shift_hex(harmony["primary_container"], delta_h, sat_scale),
            "tertiary": shift_hex(harmony["tertiary"], delta_h, sat_scale),
            "outline": shift_hex(harmony["outline"], delta_h, sat_scale),
            "error": harmony.get("error", "#ffb4ab"),
        }
    surfaces = build_surfaces(wallpaper)
    text = build_text(surfaces, accents)
    if harmony_id != "sand":
        # Re-fix accent contrast on surfaces for UI chrome
        accents["primary"] = to_hex(
            ensure_on_bg(parse_hex(accents["primary"]), parse_hex(surfaces["surface"]), 3.0)
        )
        accents["secondary"] = to_hex(
            ensure_on_bg(parse_hex(accents["secondary"]), parse_hex(surfaces["surface"]), 3.0)
        )
        text = build_text(surfaces, accents)
    ansi = build_ansi(surfaces, accents, text)
    chrome = build_chrome(surfaces, accents, text)
    return {
        "meta": {
            "wallpaper": str(wallpaper),
            "harmony_id": harmony_id,
            "accent_family": str(harmony.get("family", "unknown")),
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hue_shift": round(delta_h, 2),
            "warm_weight": round(warm_weight(colors), 4),
        },
        "surface": surfaces,
        "text": text,
        "accent": accents,
        "chrome": chrome,
        "ansi": ansi,
    }


def build_chrome(
    surfaces: dict[str, str],
    accents: dict[str, str],
    text: dict[str, str],
) -> dict[str, str]:
    """Widget/bar chrome tokens shared by tmux, starship, QS, etc."""
    return {
        # Highlight pill — path / active session / active window
        "highlight_bg": accents["primary"],
        "highlight_fg": text["on_primary"],
        # Secondary segment — branch / inactive window name
        "panel_bg": surfaces["surface_container_high"],
        "panel_fg": accents["secondary"],
        # Muted/tertiary segment — time / inactive window index
        "muted_bg": surfaces["surface_container"],
        "muted_fg": accents["tertiary"],
        # Fonts for bars/widgets — DS typography: UI = modern sans, mono for terminals
        "font_mono": "JetBrains Mono",
        "font_ui": "Adwaita Sans",
    }


def palette_to_toml(p: dict[str, Any]) -> str:
    lines = ["# Generated by theme-ssot — do not edit by hand", ""]

    def section(name: str, data: dict[str, Any]):
        lines.append(f"[{name}]")
        for k, v in data.items():
            if isinstance(v, str):
                lines.append(f'{k} = "{v}"')
            elif isinstance(v, (int, float)):
                lines.append(f"{k} = {v}")
            else:
                lines.append(f'{k} = "{v}"')
        lines.append("")

    section("meta", p["meta"])
    section("surface", p["surface"])
    section("text", p["text"])
    section("accent", p["accent"])
    if "chrome" in p:
        section("chrome", p["chrome"])
    section("ansi", p["ansi"])
    return "\n".join(lines)


def load_palette(path: Path | None = None) -> dict[str, Any]:
    path = path or (THEME_DIR / "palette.toml")
    data = tomllib.loads(path.read_text())
    return data


def hex_to_ansi256(hex_color: str) -> int:
    """Nearest xterm-256 index for tools that only take 0-255 (cbonsai, etc.)."""
    r, g, b = [int(round(c * 255)) for c in parse_hex(hex_color)]
    if r == g == b:
        if r < 8:
            return 16
        if r > 248:
            return 231
        return int(round(((r - 8) / 247) * 24)) + 232

    def cube(c: int) -> int:
        return int(round(c / 255 * 5))

    return 16 + 36 * cube(r) + 6 * cube(g) + cube(b)


def hex_to_ansi8(hex_color: str) -> int:
    """Nearest basic ANSI 0-7 for tty-clock / pipes.sh."""
    h, s, l = rgb_to_hsl(parse_hex(hex_color))
    if l < 0.12:
        return 0  # black
    if s < 0.18:
        return 7 if l > 0.55 else 0
    # 0=black 1=red 2=green 3=yellow 4=blue 5=magenta 6=cyan 7=white
    if h < 30 or h >= 330:
        return 1
    if h < 70:
        return 3
    if h < 150:
        return 2
    if h < 200:
        return 6
    if h < 260:
        return 4
    if h < 300:
        return 5
    return 1


def flat_palette(p: dict[str, Any]) -> dict[str, str]:
    """Flatten nested palette for template substitution."""
    flat: dict[str, str] = {}
    for section in ("surface", "text", "accent", "chrome", "ansi", "meta"):
        block = p.get(section, {})
        for k, v in block.items():
            flat[k] = str(v)
            flat[f"{section}.{k}"] = str(v)
    # convenience aliases
    flat["primary"] = flat.get("primary", flat.get("accent.primary", "#ffb688"))
    flat["secondary"] = flat.get("secondary", flat.get("accent.secondary", "#e5bfa9"))
    flat["background"] = flat.get("background", flat.get("surface.background", "#111"))
    flat["surface"] = p.get("surface", {}).get("surface", flat.get("background"))
    flat["on_surface"] = p.get("text", {}).get("on_surface", "#eee")
    flat["on_surface_variant"] = p.get("text", {}).get("on_surface_variant", "#ccc")
    flat["on_primary"] = p.get("text", {}).get("on_primary", p.get("accent", {}).get("on_primary", "#512400"))
    flat["tertiary"] = p.get("accent", {}).get("tertiary", "#cac993")
    flat["outline"] = p.get("accent", {}).get("outline", "#c4a882")
    flat["error"] = p.get("accent", {}).get("error", "#ffb4ab")
    flat["primary_container"] = p.get("accent", {}).get("primary_container", "#6e380f")
    flat["surface_container"] = p.get("surface", {}).get("surface_container", "#222")
    flat["surface_container_high"] = p.get("surface", {}).get("surface_container_high", "#2a2a2a")
    flat["surface_variant"] = p.get("surface", {}).get("surface_variant", "#444")
    # Chrome tokens (derive if palette.toml predates [chrome] section)
    chrome = p.get("chrome") or build_chrome(
        {
            "surface_container": flat["surface_container"],
            "surface_container_high": flat["surface_container_high"],
        },
        {
            "primary": flat["primary"],
            "secondary": flat["secondary"],
            "tertiary": flat["tertiary"],
        },
        {"on_primary": flat["on_primary"]},
    )
    flat["chrome_highlight_bg"] = chrome.get("highlight_bg", flat["primary"])
    flat["chrome_highlight_fg"] = chrome.get("highlight_fg", flat["on_primary"])
    flat["chrome_panel_bg"] = chrome.get("panel_bg", flat["surface_container_high"])
    flat["chrome_panel_fg"] = chrome.get("panel_fg", flat["secondary"])
    flat["chrome_muted_bg"] = chrome.get("muted_bg", flat["surface_container"])
    flat["chrome_muted_fg"] = chrome.get("muted_fg", flat["tertiary"])
    flat["font_mono"] = chrome.get("font_mono", "JetBrains Mono")
    flat["font_ui"] = chrome.get("font_ui", flat["font_mono"])
    # strip # for rgba helpers
    for key in list(flat.keys()):
        val = flat[key]
        if isinstance(val, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", val):
            flat[f"{key}_hex"] = val.lstrip("#")
    # Indexed colors for ncurses / pipes toys
    for role in (
        "primary",
        "secondary",
        "tertiary",
        "outline",
        "error",
        "on_surface",
        "on_surface_variant",
        "surface_variant",
        "surface_container",
        "background",
    ):
        hx = flat.get(role)
        if isinstance(hx, str) and hx.startswith("#"):
            flat[f"c256_{role}"] = str(hex_to_ansi256(hx))
            flat[f"c8_{role}"] = str(hex_to_ansi8(hx))
    # Force 4 distinct ANSI slots for pipes.sh (0-7 only)
    pipe_pool = [
        int(flat.get("c8_primary", "4")),
        int(flat.get("c8_tertiary", "3")),
        int(flat.get("c8_error", "1")),
        int(flat.get("c8_secondary", "6")),
        int(flat.get("c8_outline", "5")),
        6,
        4,
        3,
        2,
        1,
        5,
    ]
    seen: set[int] = set()
    pipes: list[int] = []
    for idx in pipe_pool:
        if idx in (0, 7):
            continue
        if idx not in seen:
            seen.add(idx)
            pipes.append(idx)
        if len(pipes) == 4:
            break
    while len(pipes) < 4:
        for idx in range(1, 7):
            if idx not in seen:
                seen.add(idx)
                pipes.append(idx)
                break
    for i, idx in enumerate(pipes, start=1):
        flat[f"c8_pipe{i}"] = str(idx)
    return flat


def render_template(tmpl: str, flat: dict[str, str]) -> str:
    def repl(m: re.Match) -> str:
        key = m.group(1)
        return flat.get(key, m.group(0))

    return re.sub(r"\{\{\s*([A-Za-z0-9_.]+)\s*\}\}", repl, tmpl)
