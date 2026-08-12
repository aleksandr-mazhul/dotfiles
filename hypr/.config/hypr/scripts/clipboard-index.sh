#!/usr/bin/env bash
# Build clipboard index JSON for Quickshell (Raycast-style panel).
# Prints one JSON object to stdout. Also refreshes image thumbs + meta sidecars.
set -euo pipefail

# Prefer real user PATH over AppImage-stripped PATH
export PATH="/usr/local/bin:/usr/bin:$HOME/.local/bin:$PATH"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/qs-clipboard-thumbs"
mkdir -p "$cache"
find "$cache" -type f -mtime +2 -delete 2>/dev/null || true

python3 - "$cache" <<'PY'
import json, os, re, shutil, subprocess, sys
from datetime import datetime
from pathlib import Path

cache = Path(sys.argv[1])
cache.mkdir(parents=True, exist_ok=True)

BINARY_RE = re.compile(r"\[\[\s*binary data", re.I)
IMAGE_RE = re.compile(r"image/", re.I)
SKIP_RE = re.compile(r"hypr-clipboard-paste|file:///tmp/hypr-clipboard")
DIMS_RE = re.compile(r"(\d+)\s*[x×]\s*(\d+)", re.I)

HAS_MAGICK = shutil.which("magick") or shutil.which("convert")
HAS_IDENTIFY = shutil.which("magick") or shutil.which("identify")

def run(cmd, data=None):
    return subprocess.run(cmd, input=data, capture_output=True)

def cliphist_list():
    p = run(["cliphist", "list"])
    if p.returncode != 0:
        return []
    return p.stdout.decode("utf-8", "replace").splitlines()

def decode_line(line: str) -> bytes:
    p = run(["cliphist", "decode"], data=(line + "\n").encode())
    return p.stdout if p.returncode == 0 else b""

def dims_from_preview(preview: str):
    m = DIMS_RE.search(preview or "")
    if m:
        return int(m.group(1)), int(m.group(2))
    return 0, 0

def dims_from_file(path: Path):
    try:
        out = subprocess.check_output(["file", "-b", str(path)], text=True, errors="replace")
        m = DIMS_RE.search(out)
        if m:
            return int(m.group(1)), int(m.group(2))
    except Exception:
        pass
    try:
        from PIL import Image
        with Image.open(path) as im:
            return int(im.width), int(im.height)
    except Exception:
        pass
    if HAS_IDENTIFY:
        for cmd in (
            ["magick", "identify", "-format", "%w %h", str(path)],
            ["identify", "-format", "%w %h", str(path)],
        ):
            if not shutil.which(cmd[0]):
                continue
            try:
                p = run(cmd)
                if p.returncode == 0:
                    parts = p.stdout.decode().strip().split()
                    if len(parts) >= 2:
                        return int(parts[0]), int(parts[1])
            except Exception:
                continue
    return 0, 0

def make_thumb(src: Path, dest: Path):
    if HAS_MAGICK:
        for cmd in (
            ["magick", str(src), "-resize", "480x320>", str(dest)],
            ["convert", str(src), "-resize", "480x320>", str(dest)],
        ):
            if not shutil.which(cmd[0]):
                continue
            try:
                p = run(cmd)
                if p.returncode == 0 and dest.exists():
                    return True
            except Exception:
                continue
    # Fallback: copy raw (QML Image can often decode png/jpeg)
    try:
        shutil.copyfile(src, dest)
        return True
    except Exception:
        return False

def ensure_image_assets(entry_id: str, line: str, preview: str):
    thumb = cache / f"{entry_id}.png"
    meta = cache / f"{entry_id}.json"
    src = cache / f"{entry_id}.src"

    preview_w, preview_h = dims_from_preview(preview)

    if thumb.exists() and meta.exists():
        try:
            info = json.loads(meta.read_text())
            w = int(info.get("width") or 0)
            h = int(info.get("height") or 0)
            if (not w or not h) and (src.exists() or thumb.exists()):
                fw, fh = dims_from_file(src if src.exists() else thumb)
                if fw and fh:
                    w, h = fw, fh
            if (not w or not h) and preview_w:
                w, h = preview_w, preview_h
            if w and h:
                info["width"], info["height"] = w, h
                info["dims_label"] = f"{w}×{h}"
            if not info.get("thumb") and thumb.exists():
                info["thumb"] = str(thumb)
            if not info.get("preview_path"):
                info["preview_path"] = str(src if src.exists() else thumb)
            meta.write_text(json.dumps(info))
            return info
        except Exception:
            pass

    data = decode_line(line)
    if not data:
        return {
            "width": preview_w,
            "height": preview_h,
            "bytes": 0,
            "mtime": 0,
            "mtime_label": "",
            "thumb": str(thumb) if thumb.exists() else "",
            "preview_path": str(src if src.exists() else thumb) if (src.exists() or thumb.exists()) else "",
            "dims_label": f"{preview_w}×{preview_h}" if preview_w else "",
        }

    try:
        src.write_bytes(data)
    except PermissionError:
        # Stale root-owned cache entry — use whatever we already have + cliphist dims
        w, h = preview_w, preview_h
        if (not w or not h) and thumb.exists():
            w, h = dims_from_file(thumb)
        mtime = int(thumb.stat().st_mtime) if thumb.exists() else 0
        return {
            "width": w,
            "height": h,
            "bytes": thumb.stat().st_size if thumb.exists() else 0,
            "mtime": mtime,
            "mtime_label": datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M") if mtime else "",
            "thumb": str(thumb) if thumb.exists() else "",
            "preview_path": str(thumb) if thumb.exists() else "",
            "dims_label": f"{w}×{h}" if w and h else "",
        }
    make_thumb(src, thumb)

    w, h = dims_from_file(src if src.exists() else thumb)
    if not w and preview_w:
        w, h = preview_w, preview_h

    nbytes = src.stat().st_size if src.exists() else (thumb.stat().st_size if thumb.exists() else 0)
    mtime = int(src.stat().st_mtime) if src.exists() else (
        int(thumb.stat().st_mtime) if thumb.exists() else int(datetime.now().timestamp())
    )
    label = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")

    if src.exists() and src.stat().st_size > 2_000_000:
        src.unlink(missing_ok=True)
        preview_path = str(thumb)
    else:
        preview_path = str(src if src.exists() else thumb)

    info = {
        "width": w,
        "height": h,
        "bytes": nbytes,
        "mtime": mtime,
        "mtime_label": label,
        "thumb": str(thumb) if thumb.exists() else "",
        "preview_path": preview_path,
        "dims_label": f"{w}×{h}" if w and h else "",
    }
    meta.write_text(json.dumps(info))
    return info

def fmt_bytes(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n / 1024:.0f} KB"
    return f"{n / 1024 / 1024:.1f} MB"

def day_bucket(mtime: int) -> str:
    """Relative day label for Raycast-style section headers."""
    if not mtime:
        return "Today"
    now = datetime.now().date()
    d = datetime.fromtimestamp(mtime).date()
    delta = (now - d).days
    if delta <= 0:
        return "Today"
    if delta == 1:
        return "Yesterday"
    if delta == 2:
        return "2 days ago"
    if delta < 7:
        return f"{delta} days ago"
    return d.strftime("%d.%m.%Y")

items = []
for line in cliphist_list():
    if not line or SKIP_RE.search(line):
        continue
    tab = line.find("\t")
    entry_id = line[:tab] if tab >= 0 else line
    preview = line[tab + 1 :] if tab >= 0 else line
    is_image = bool(BINARY_RE.search(preview) or IMAGE_RE.search(preview))

    item = {
        "id": entry_id,
        "line": line,
        "isImage": is_image,
        "kind": "image" if is_image else "text",
        "preview": preview,
        "label": preview,
        "width": 0,
        "height": 0,
        "bytes": 0,
        "sizeLabel": "",
        "mtime": 0,
        "mtimeLabel": "",
        "dayGroup": "Today",
        "isToday": True,
        "thumb": "",
        "previewPath": "",
        "dimsLabel": "",
        "contentType": "Image" if is_image else "Text",
    }

    if is_image:
        info = ensure_image_assets(entry_id, line, preview)
        w, h = int(info.get("width") or 0), int(info.get("height") or 0)
        item["width"] = w
        item["height"] = h
        item["bytes"] = int(info.get("bytes") or 0)
        item["sizeLabel"] = fmt_bytes(item["bytes"]) if item["bytes"] else ""
        item["mtime"] = int(info.get("mtime") or 0)
        item["mtimeLabel"] = info.get("mtime_label") or ""
        item["dayGroup"] = day_bucket(item["mtime"])
        item["isToday"] = item["dayGroup"] == "Сегодня"
        item["thumb"] = info.get("thumb") or ""
        item["previewPath"] = info.get("preview_path") or item["thumb"]
        item["dimsLabel"] = info.get("dims_label") or (f"{w}×{h}" if w and h else "")
        item["label"] = f"Image ({item['dimsLabel']})" if item["dimsLabel"] else "Image"
        item["preview"] = item["label"]
    else:
        # List label is short; keep raw list preview separately — full body is
        # decoded lazily by the Quickshell panel (cliphist list truncates).
        raw = preview.replace("\r\n", "\n").replace("\r", "\n")
        one_line = " ".join(raw.split())
        if len(one_line) > 90:
            item["label"] = one_line[:87] + "…"
        else:
            item["label"] = one_line or "Text"
        item["preview"] = raw
        item["needsDecode"] = True

    items.append(item)

# Newest first — id grows monotonically with copy time
items.sort(key=lambda it: int(it.get("id") or 0), reverse=True)

# Propagate known image mtimes down the stack so neighboring text gets a day label.
# (cliphist itself does not store timestamps.)
carry_mtime = 0
for it in items:
    if it.get("mtime"):
        carry_mtime = int(it["mtime"])
    elif carry_mtime:
        it["mtime"] = carry_mtime
        it["mtimeLabel"] = datetime.fromtimestamp(carry_mtime).strftime("%Y-%m-%d %H:%M")
    group = day_bucket(int(it.get("mtime") or 0))
    it["dayGroup"] = group
    it["isToday"] = group == "Today"

json.dump({"cache": str(cache), "items": items}, sys.stdout, ensure_ascii=False)
PY
