#!/usr/bin/env bash
# Build clipboard index JSON for Quickshell (Raycast-style panel).
# Prints one JSON object to stdout (except --warmup). Writes index.json for instant opens.
#
#   clipboard-index.sh           # rebuild, write cache, print JSON
#   clipboard-index.sh --cached  # print cache if present (no rebuild)
#   clipboard-index.sh --warmup  # rebuild + write cache, no stdout
set -euo pipefail

# Prefer real user PATH over AppImage-stripped PATH
export PATH="/usr/local/bin:/usr/bin:$HOME/.local/bin:$PATH"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/qs-clipboard-thumbs"
mkdir -p "$cache"

mode="${1:-}"

python3 - "$cache" "$mode" <<'PY'
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

cache = Path(sys.argv[1])
mode = sys.argv[2] if len(sys.argv) > 2 else ""
cache.mkdir(parents=True, exist_ok=True)
index_path = cache / "index.json"
lock_path = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "clipboard-index.lock"

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
            dirty = False
            w = int(info.get("width") or 0)
            h = int(info.get("height") or 0)
            if (not w or not h) and (src.exists() or thumb.exists()):
                fw, fh = dims_from_file(src if src.exists() else thumb)
                if fw and fh:
                    w, h = fw, fh
                    dirty = True
            if (not w or not h) and preview_w:
                w, h = preview_w, preview_h
                dirty = True
            if w and h:
                if info.get("width") != w or info.get("height") != h:
                    info["width"], info["height"] = w, h
                    dirty = True
                label = f"{w}×{h}"
                if info.get("dims_label") != label:
                    info["dims_label"] = label
                    dirty = True
            if not info.get("thumb") and thumb.exists():
                info["thumb"] = str(thumb)
                dirty = True
            if not info.get("preview_path"):
                info["preview_path"] = str(src if src.exists() else thumb)
                dirty = True
            if dirty:
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


def fingerprint(lines):
    h = hashlib.sha1()
    for line in lines:
        h.update(line.encode("utf-8", "replace"))
        h.update(b"\n")
    return h.hexdigest()


def load_index():
    try:
        return json.loads(index_path.read_text())
    except Exception:
        return None


def emit(payload: dict):
    text = json.dumps(payload, ensure_ascii=False)
    tmp = index_path.with_name("index.json.tmp")
    tmp.write_text(text)
    tmp.replace(index_path)
    if mode != "--warmup":
        sys.stdout.write(text)


def apply_day_groups(items):
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
    return items


def prune_orphans(items):
    keep = {str(it.get("id") or "") for it in items}
    keep.discard("")
    for p in cache.iterdir():
        if p.name in {"index.json", "index.json.tmp"}:
            continue
        if p.stem not in keep:
            try:
                p.unlink()
            except OSError:
                pass


def build_item(line: str, old=None):
    if old and old.get("line") == line:
        return old
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
        item["thumb"] = info.get("thumb") or ""
        item["previewPath"] = info.get("preview_path") or item["thumb"]
        item["dimsLabel"] = info.get("dims_label") or (f"{w}×{h}" if w and h else "")
        item["label"] = f"Image ({item['dimsLabel']})" if item["dimsLabel"] else "Image"
        item["preview"] = item["label"]
    else:
        raw = preview.replace("\r\n", "\n").replace("\r", "\n")
        one_line = " ".join(raw.split())
        if len(one_line) > 90:
            item["label"] = one_line[:87] + "…"
        else:
            item["label"] = one_line or "Text"
        item["preview"] = raw
        item["needsDecode"] = True

    return item


if mode == "--cached":
    data = load_index()
    if data:
        sys.stdout.write(json.dumps(data, ensure_ascii=False))
    sys.exit(0)

lock_f = open(lock_path, "w")
fcntl.flock(lock_f.fileno(), fcntl.LOCK_EX)

lines = [ln for ln in cliphist_list() if ln and not SKIP_RE.search(ln)]
fp = fingerprint(lines)
old_data = load_index() or {}

if old_data.get("fingerprint") == fp and old_data.get("items"):
    items = apply_day_groups(old_data["items"])
    emit({"cache": str(cache), "fingerprint": fp, "items": items})
    sys.exit(0)

old_by_id = {str(it.get("id")): it for it in (old_data.get("items") or []) if it.get("id") is not None}

items = []
for line in lines:
    tab = line.find("\t")
    entry_id = line[:tab] if tab >= 0 else line
    items.append(build_item(line, old_by_id.get(str(entry_id))))

items.sort(key=lambda it: int(it.get("id") or 0), reverse=True)
items = apply_day_groups(items)
prune_orphans(items)
emit({"cache": str(cache), "fingerprint": fp, "items": items})
PY
