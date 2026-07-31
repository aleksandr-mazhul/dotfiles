#!/usr/bin/env python3
"""Persistent EasyOCR daemon — keeps models warm so Ctrl+T is fast."""

from __future__ import annotations

import os
import socket
import sys
import traceback
from pathlib import Path

SOCK = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-easyocr.sock"
PID_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-easyocr.pid"

READER = None


def get_reader():
    global READER
    if READER is None:
        import easyocr

        READER = easyocr.Reader(["en", "ru"], gpu=False, verbose=False)
    return READER


def ocr_image(path: Path) -> str:
    from PIL import Image, ImageEnhance, ImageOps

    reader = get_reader()
    img = Image.open(path).convert("RGB")
    w, h = img.size
    # 2x is enough for most UI text and much faster than 3x
    scale = 2 if max(w, h) < 1200 else 1
    if scale > 1:
        img = img.resize((w * scale, h * scale), Image.Resampling.LANCZOS)
    img = ImageOps.autocontrast(img)
    img = ImageEnhance.Sharpness(img).enhance(1.15)

    prepared = path.with_suffix(".ocr.png")
    img.save(prepared)
    try:
        parts = reader.readtext(str(prepared), detail=0, paragraph=True)
    finally:
        try:
            prepared.unlink(missing_ok=True)
        except OSError:
            pass

    if not parts:
        return ""
    if isinstance(parts, str):
        return parts.strip()
    return "\n".join(str(p).strip() for p in parts if str(p).strip()).strip()


def handle(conn: socket.socket) -> None:
    with conn:
        data = b""
        while not data.endswith(b"\n"):
            chunk = conn.recv(4096)
            if not chunk:
                return
            data += chunk
        path = Path(data.decode("utf-8", errors="replace").strip())
        try:
            if not path.is_file():
                conn.sendall(b"ERR missing image\n")
                return
            text = ocr_image(path)
            # Frame response: OK\n then body, then \0 end
            payload = text.encode("utf-8", errors="replace")
            conn.sendall(b"OK\n")
            conn.sendall(payload)
            conn.sendall(b"\0")
        except Exception as exc:  # noqa: BLE001
            msg = f"ERR {exc}\n".encode("utf-8", errors="replace")
            conn.sendall(msg)


def serve() -> int:
    if SOCK.exists():
        try:
            SOCK.unlink()
        except OSError:
            pass

    PID_FILE.write_text(str(os.getpid()))
    print(f"loading EasyOCR models…", flush=True)
    get_reader()
    print(f"ready on {SOCK}", flush=True)

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(SOCK))
        server.listen(4)
        while True:
            conn, _ = server.accept()
            try:
                handle(conn)
            except Exception:  # noqa: BLE001
                traceback.print_exc()
    return 0


def client(path: str) -> int:
    """One-shot client: print OCR text to stdout."""
    if not SOCK.exists():
        print("ocr daemon not running", file=sys.stderr)
        return 2
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(str(SOCK))
        sock.sendall(path.encode("utf-8") + b"\n")
        header = b""
        while not header.endswith(b"\n"):
            chunk = sock.recv(1)
            if not chunk:
                print("ocr daemon closed", file=sys.stderr)
                return 1
            header += chunk
        line = header.decode("utf-8", errors="replace").rstrip("\n")
        if line.startswith("ERR"):
            print(line[4:].strip() or line, file=sys.stderr)
            return 1
        if line != "OK":
            print(f"bad response: {line}", file=sys.stderr)
            return 1
        buf = b""
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            buf += chunk
            if b"\0" in buf:
                buf = buf.split(b"\0", 1)[0]
                break
        sys.stdout.buffer.write(buf)
        return 0


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "serve":
        return serve()
    if len(sys.argv) >= 3 and sys.argv[1] == "ocr":
        return client(sys.argv[2])
    # Back-compat: ocr-easyocr.py <image> via daemon if up, else inline
    if len(sys.argv) == 2 and not sys.argv[1].startswith("-"):
        path = sys.argv[1]
        if SOCK.exists():
            return client(path)
        try:
            sys.stdout.write(ocr_image(Path(path)))
            return 0
        except Exception as exc:  # noqa: BLE001
            print(f"ocr failed: {exc}", file=sys.stderr)
            return 1
    print("usage: ocr-easyocr.py serve | ocr <image> | <image>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
