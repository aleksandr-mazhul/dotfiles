#!/usr/bin/env python3
"""Persistent RapidOCR daemon — PP-OCRv5 en + ru, models kept warm for Super+T."""

from __future__ import annotations

import os
import re
import socket
import sys
import traceback
from pathlib import Path

import numpy as np
from PIL import Image

SOCK = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-ocr.sock"
PID_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-ocr.pid"

MIN_SCORE = 0.38
CYR_RE = re.compile(r"[\u0400-\u04FF]")
LAT_RE = re.compile(r"[A-Za-z]")
# Cyrillic that cannot be a Latin lookalike — proves the word is Russian.
UNIQUE_CYR_RE = re.compile(r"[БГДЁЖЗИЙЛПФЦЧШЩЪЫЬЭЮЯбгдёжзийлпфцчшщъыьэюя]")
# Latin that cannot be a Cyrillic lookalike — proves Super/Error/etc.
UNIQUE_LAT_RE = re.compile(r"[bdfgijlnqrsuvwzDFGIJLNQRSUVWZ]")
TOKEN_RE = re.compile(r"[A-Za-zА-Яа-яЁёІіЇї0-9+]+|[^A-Za-zА-Яа-яЁёІіЇї0-9+]+")
KNOWN_RU = {
    "не",
    "но",
    "на",
    "по",
    "от",
    "со",
    "то",
    "он",
    "мы",
    "вы",
    "ты",
    "за",
    "до",
    "из",
    "во",
    "об",
    "ну",
    "да",
    "же",
    "бы",
    "ли",
    "ни",
    "ее",
    "её",
    "в",
    "с",
    "к",
    "о",
    "у",
    "а",
    "и",
    "я",
}
# Isolated Latin letters that are Russian one-letter words (а/в/к/о/с/у).
PREP_LAT_TO_CYR = str.maketrans(
    {
        "A": "а",
        "a": "а",
        "B": "в",
        "C": "с",
        "c": "с",
        "K": "к",
        "O": "о",
        "o": "о",
        "Y": "у",
        "y": "у",
    }
)
# Full lookalike map for short Russian words OCR'd as Latin (Tak → так).
LAT_TO_CYR = str.maketrans(
    {
        "A": "А",
        "a": "а",
        "B": "В",
        "C": "С",
        "c": "с",
        "E": "Е",
        "e": "е",
        "H": "Н",
        "K": "К",
        "k": "к",
        "M": "М",
        "O": "О",
        "o": "о",
        "P": "Р",
        "p": "р",
        "T": "Т",
        "t": "т",
        "X": "Х",
        "x": "х",
        "Y": "У",
        "y": "у",
    }
)
CYR_TO_LAT = str.maketrans(
    {
        "А": "A",
        "а": "a",
        "В": "B",
        "в": "B",
        "С": "C",
        "с": "c",
        "Е": "E",
        "е": "e",
        "Н": "H",
        "н": "H",
        "К": "K",
        "к": "k",
        "М": "M",
        "м": "M",
        "О": "O",
        "о": "o",
        "Р": "P",
        "р": "p",
        "Т": "T",
        "т": "t",
        "Х": "X",
        "х": "x",
        "У": "Y",
        "у": "y",
    }
)
LATIN_AS_RU = {w.translate(CYR_TO_LAT).lower(): w for w in KNOWN_RU}

RU_ENGINE = None
EN_ENGINE = None


def _engine_params(lang):
    from rapidocr import EngineType, LangDet, LangRec, ModelType, OCRVersion

    rec = LangRec.ESLAV if lang == "ru" else LangRec.EN
    return {
        "Det.engine_type": EngineType.ONNXRUNTIME,
        "Det.lang_type": LangDet.CH,
        "Det.model_type": ModelType.MOBILE,
        "Det.ocr_version": OCRVersion.PPOCRV5,
        "Rec.engine_type": EngineType.ONNXRUNTIME,
        "Rec.lang_type": rec,
        "Rec.model_type": ModelType.MOBILE,
        "Rec.ocr_version": OCRVersion.PPOCRV5,
        "Global.text_score": MIN_SCORE,
        "Global.use_cls": False,
    }


def get_engines():
    global RU_ENGINE, EN_ENGINE
    if RU_ENGINE is None or EN_ENGINE is None:
        import logging

        from rapidocr import RapidOCR

        logging.getLogger("RapidOCR").setLevel(logging.WARNING)
        print("loading RapidOCR PP-OCRv5 (eslav + en)…", flush=True)
        RU_ENGINE = RapidOCR(params=_engine_params("ru"))
        EN_ENGINE = RapidOCR(params=_engine_params("en"))
        print("RapidOCR ready", flush=True)
    return RU_ENGINE, EN_ENGINE


def prepare_image(path: Path) -> np.ndarray:
    img = Image.open(path).convert("RGB")
    w, h = img.size
    long_side = max(w, h)
    if long_side < 1:
        return np.zeros((1, 1, 3), dtype=np.uint8)
    # UI/chat text is ~13–16px; PP-OCR wants ~32–48px glyphs.
    if long_side < 960:
        scale = max(2.0, 960 / long_side)
    elif long_side < 1400:
        scale = 1.35
    else:
        scale = 1.0
    if long_side * scale > 1920:
        scale = 1920 / long_side
    if scale > 1.01:
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.LANCZOS)
    rgb = np.asarray(img)
    return rgb[:, :, ::-1].copy()


def _items(result) -> list[dict]:
    if result is None or result.boxes is None or result.txts is None:
        return []
    scores = result.scores or (0.0,) * len(result.txts)
    out: list[dict] = []
    for box, txt, score in zip(result.boxes, result.txts, scores, strict=False):
        text = str(txt).strip()
        if not text:
            continue
        conf = float(score)
        if conf < MIN_SCORE:
            continue
        xs = [float(p[0]) for p in box]
        ys = [float(p[1]) for p in box]
        x1, y1, x2, y2 = min(xs), min(ys), max(xs), max(ys)
        out.append(
            {
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2,
                "cx": (x1 + x2) / 2.0,
                "cy": (y1 + y2) / 2.0,
                "h": max(1.0, y2 - y1),
                "txt": text,
                "score": conf,
            }
        )
    return out


def _script_counts(text: str) -> tuple[int, int]:
    return len(CYR_RE.findall(text)), len(LAT_RE.findall(text))


def _is_word(token: str) -> bool:
    return bool(re.search(r"[A-Za-zА-Яа-яЁёІіЇї0-9]", token))


def _latinish(token: str) -> bool:
    if not token or UNIQUE_CYR_RE.search(token):
        return False
    return bool(UNIQUE_LAT_RE.search(token) or token.isascii())


def _all_cyr_letters(token: str) -> bool:
    letters = [c for c in token if c.isalpha()]
    return bool(letters) and all("\u0400" <= c <= "\u04FF" for c in letters)


def _lookalike_equiv(a: str, b: str) -> bool:
    if not a or not b:
        return False
    return a.translate(CYR_TO_LAT).lower() == b.translate(CYR_TO_LAT).lower()


def _pick_word(ru_t: str, en_t: str, *, russian_context: bool) -> str:
    ru_uc = bool(UNIQUE_CYR_RE.search(ru_t))
    ru_ul = bool(UNIQUE_LAT_RE.search(ru_t))
    en_ok = _latinish(en_t) if en_t else False
    ru_letters = "".join(c for c in ru_t if c.isalpha())
    en_letters = "".join(c for c in (en_t or "") if c.isalpha())
    # Super / Sиреr / Suреr+Т — mixed glyph soup, English rec is the source of truth.
    if en_ok and ((ru_uc and ru_ul) or "+" in ru_t or "+" in (en_t or "")):
        return en_t
    # Short Latin labels (ru:/en:) vs unique-cyr garbage (ги).
    if (
        en_letters
        and re.fullmatch(r"[A-Za-z]{1,3}", en_letters)
        and ru_uc
        and ru_letters.lower() not in KNOWN_RU
        and len(ru_letters) <= 3
    ):
        return en_t
    # Slavic rec already in Cyrillic (не/текст/тест) vs English lookalikes (He/Tekc/tect).
    if _all_cyr_letters(ru_t) and en_t and _lookalike_equiv(ru_t, en_t):
        if russian_context or len(ru_letters) >= 3 or ru_letters.lower() in KNOWN_RU:
            return ru_t
    if ru_uc and not ru_ul:
        return ru_t
    if ru_letters.lower() in KNOWN_RU:
        return ru_t
    if russian_context and en_letters.lower() in LATIN_AS_RU:
        return LATIN_AS_RU[en_letters.lower()]
    # "Tak" / lookalike-only tokens in a Russian line → так.
    if (
        russian_context
        and len(src := (ru_t or en_t)) >= 3
        and not ru_uc
        and not ru_ul
        and not UNIQUE_LAT_RE.search(en_t or "")
    ):
        mapped = src.translate(LAT_TO_CYR)
        if src[:1].isupper() and src[1:].islower():
            return mapped.lower()
        return mapped
    if en_ok and not ru_uc:
        return en_t
    if ru_ul and not ru_uc:
        return ru_t.translate(CYR_TO_LAT) if CYR_RE.search(ru_t) else ru_t
    if en_ok and ru_uc and ru_ul:
        return en_t
    return ru_t


def _blend(ru_txt: str, en_txt: str | None) -> str:
    ru_toks = TOKEN_RE.findall(ru_txt)
    en_words = [t for t in TOKEN_RE.findall(en_txt or "") if _is_word(t)]
    ru_word_idx = [i for i, tok in enumerate(ru_toks) if _is_word(tok)]
    ru_words = [ru_toks[i] for i in ru_word_idx]
    russian_context = len(UNIQUE_CYR_RE.findall(ru_txt)) >= 3 and (
        len(UNIQUE_CYR_RE.findall(ru_txt)) >= len(UNIQUE_LAT_RE.findall(ru_txt))
    )

    if en_txt and len(ru_words) == len(en_words):
        for idx, en_w in zip(ru_word_idx, en_words, strict=False):
            ru_toks[idx] = _pick_word(ru_toks[idx], en_w, russian_context=russian_context)
        return "".join(ru_toks)

    # Different tokenisation — only swap mixed-script / shortcut words onto EN.
    if en_txt:
        en_shortcuts = [w for w in en_words if "+" in w]
        en_latin = [w for w in en_words if _latinish(w) and not UNIQUE_CYR_RE.search(w)]
        si = 0
        for idx in ru_word_idx:
            rw = ru_toks[idx]
            mixed = bool(UNIQUE_CYR_RE.search(rw) and UNIQUE_LAT_RE.search(rw))
            if "+" in rw and si < len(en_shortcuts):
                ru_toks[idx] = en_shortcuts[si]
                si += 1
            elif mixed and en_latin:
                ru_toks[idx] = min(en_latin, key=lambda w: abs(len(w) - len(rw)))
            else:
                ru_toks[idx] = _pick_word(rw, "", russian_context=russian_context)
    else:
        for idx in ru_word_idx:
            ru_toks[idx] = _pick_word(ru_toks[idx], "", russian_context=russian_context)
    return "".join(ru_toks)


def _cyrillize_lookalike_words(text: str) -> str:
    """Fold Latin lookalikes only where the word is already Russian (coединение → соединение)
    or a lookalike-only token sits next to unique Cyrillic (Tak → так). Never touch path/com/echo.
    """
    if not UNIQUE_CYR_RE.search(text):
        return text
    tokens = TOKEN_RE.findall(text)

    def ru_word(tok: str) -> bool:
        return _is_word(tok) and bool(UNIQUE_CYR_RE.search(tok))

    def fold_latin_lookalikes(tok: str) -> str:
        return "".join(
            ch.translate(LAT_TO_CYR) if ch.isascii() and ch.isalpha() and not UNIQUE_LAT_RE.search(ch) else ch
            for ch in tok
        )

    out: list[str] = []
    for i, tok in enumerate(tokens):
        if not _is_word(tok):
            out.append(tok)
            continue
        if UNIQUE_CYR_RE.search(tok) and LAT_RE.search(tok):
            out.append(fold_latin_lookalikes(tok))
            continue
        if (
            tok.isascii()
            and tok.isalpha()
            and len(tok) >= 3
            and not UNIQUE_LAT_RE.search(tok)
        ):
            prev = next((tokens[j] for j in range(i - 1, -1, -1) if _is_word(tokens[j])), "")
            nxt = next((tokens[j] for j in range(i + 1, len(tokens)) if _is_word(tokens[j])), "")
            if ru_word(prev) or ru_word(nxt):
                mapped = tok.translate(LAT_TO_CYR)
                out.append(mapped if tok.isupper() else mapped.lower())
                continue
        out.append(tok)
    return "".join(out)


def _map_isolated(text: str, letter_re: re.Pattern[str], table, *, lower: bool) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if letter_re.match(ch):
            j = i + 1
            while j < n and letter_re.match(text[j]):
                j += 1
            word = text[i:j]
            if len(word) == 1:
                mapped = word.translate(table)
                if mapped != word:
                    out.append(mapped.lower() if lower else mapped)
                else:
                    out.append(word)
            else:
                out.append(word)
            i = j
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def _normalize_script(text: str) -> str:
    cyr, lat = _script_counts(text)
    letters = cyr + lat
    if letters == 0:
        return text
    # Isolated Latin C/o/p in a Russian line → с/о/р; keep words like OCR, Super.
    if cyr >= 2 and cyr >= lat:
        return _map_isolated(text, LAT_RE, PREP_LAT_TO_CYR, lower=True)
    # Isolated Cyrillic lookalikes in code/English → Latin.
    if lat >= 3 and cyr and lat >= cyr * 3:
        return _map_isolated(text, CYR_RE, CYR_TO_LAT, lower=False)
    return text


def _finalize_line(line: str) -> str:
    tokens = TOKEN_RE.findall(line)
    if not tokens:
        return line

    def unique_ru(tok: str) -> bool:
        return _is_word(tok) and bool(UNIQUE_CYR_RE.search(tok))

    out: list[str] = []
    for i, tok in enumerate(tokens):
        prev = next((tokens[j] for j in range(i - 1, -1, -1) if _is_word(tokens[j])), "")
        nxt = next((tokens[j] for j in range(i + 1, len(tokens)) if _is_word(tokens[j])), "")
        near_ru = unique_ru(prev) or unique_ru(nxt)
        letters = "".join(c for c in tok if c.isalpha())
        low = letters.lower()

        if tok in {"0CR", "0СR"} or low in {"0cr"}:
            out.append("OCR")
            continue
        if i == 0 and tok in {"ги", "Ги"} and i + 1 < len(tokens) and tokens[i + 1].lstrip().startswith(":"):
            out.append("ru")
            continue
        if tok in {"п", "П"} and i + 1 < len(tokens) and tokens[i + 1] in {"≈", "~", "="}:
            out.append("π")
            continue
        if near_ru and tok in {"6y", "6Y", "by", "By", "BY"}:
            out.append("в")
            continue
        if near_ru and low in LATIN_AS_RU:
            out.append(LATIN_AS_RU[low])
            continue
        # q=tect → q=тест — only inside a URL query, not `SOCK = Path`.
        if (
            tok.isascii()
            and tok.isalpha()
            and 3 <= len(tok) <= 8
            and not UNIQUE_LAT_RE.search(tok)
            and i > 0
            and "=" in tokens[i - 1]
        ):
            left = "".join(tokens[:i])
            if "?" in left or "http://" in left or "https://" in left:
                out.append(tok.translate(LAT_TO_CYR).lower())
                continue
        # copiesіTekc → copies (Ukrainian i + duplicate of the next Russian word)
        glued = re.sub(r"[ііi][A-Za-z]{3,}$", "", tok)
        if glued != tok and glued.isascii() and len(glued) >= 4:
            out.append(glued)
            continue
        out.append(tok)
    return _normalize_script("".join(out))


def _pick(ru: dict | None, en: dict | None) -> dict | None:
    if en is not None and not en.get("txt"):
        en = None
    if ru is None:
        return en
    if en is None:
        ru_cyr, _ = _script_counts(ru["txt"])
        if ru_cyr and len(ru["txt"].strip()) <= 2 and ru["score"] < 0.65:
            return None
        txt = _blend(ru["txt"], None)
        txt = re.sub(r"[§]+", "", txt)
        return {**ru, "txt": txt}
    # Brace / punctuation: Slavic rec turns `{` into `т`.
    if (
        len(ru["txt"].strip()) <= 2
        and CYR_RE.search(ru["txt"])
        and en["txt"].isascii()
        and not en["txt"].isalnum()
    ):
        return {**en, "x1": ru["x1"], "y1": ru["y1"], "x2": ru["x2"], "y2": ru["y2"], "cx": ru["cx"], "cy": ru["cy"], "h": ru["h"]}
    txt = _blend(ru["txt"], en["txt"])
    txt = re.sub(r"[§]+", "", txt)
    txt = re.sub(r" {2,}", " ", txt).strip()
    if not txt:
        return None
    return {**ru, "txt": txt, "score": max(ru["score"], en["score"])}


def _en_on_crop(en_engine, img, ru: dict) -> dict | None:
    h, w = img.shape[:2]
    pad = 3
    x1 = max(0, int(ru["x1"]) - pad)
    y1 = max(0, int(ru["y1"]) - pad)
    x2 = min(w, int(ru["x2"]) + pad)
    y2 = min(h, int(ru["y2"]) + pad)
    crop = img[y1:y2, x1:x2]
    if crop.size == 0:
        return None
    en_res = en_engine(crop, use_det=False, use_cls=False, use_rec=True)
    txts = [str(t).strip() for t in (en_res.txts or []) if str(t).strip()]
    if not txts:
        return None
    scores = [float(s) for s in (en_res.scores or [])] or [0.0]
    return {
        "x1": ru["x1"],
        "y1": ru["y1"],
        "x2": ru["x2"],
        "y2": ru["y2"],
        "cx": ru["cx"],
        "cy": ru["cy"],
        "h": ru["h"],
        "txt": " ".join(txts),
        "score": max(scores),
    }


def reading_order(items: list[dict]) -> str:
    if not items:
        return ""
    remaining = sorted(items, key=lambda it: (it["cy"], it["x1"]))
    lines: list[list[dict]] = []
    for it in remaining:
        placed = False
        for line in lines:
            ref = line[0]
            overlap = min(ref["y2"], it["y2"]) - max(ref["y1"], it["y1"])
            if overlap > 0.5 * min(ref["h"], it["h"]):
                line.append(it)
                placed = True
                break
        if not placed:
            lines.append([it])
    for line in lines:
        line.sort(key=lambda it: it["x1"])
    lines.sort(key=lambda line: sum(i["cy"] for i in line) / len(line))
    raw = "\n".join(" ".join(i["txt"] for i in line) for line in lines).strip()
    return "\n".join(_finalize_line(ln) for ln in _cyrillize_lookalike_words(raw).split("\n"))


def ocr_image(path: Path) -> str:
    ru_engine, en_engine = get_engines()
    img = prepare_image(path)
    ru_items = _items(ru_engine(img, use_cls=False))
    merged: list[dict] = []
    for ru in ru_items:
        picked = _pick(ru, _en_on_crop(en_engine, img, ru))
        if picked:
            merged.append(picked)
    return reading_order(merged)


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
    get_engines()
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


def warmup() -> int:
    get_engines()
    img = Image.new("RGB", (160, 48), "white")
    tmp = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-ocr-warmup.png"
    img.save(tmp)
    try:
        ocr_image(tmp)
    finally:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
    print("warmup done", flush=True)
    return 0


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "serve":
        return serve()
    if len(sys.argv) >= 2 and sys.argv[1] == "warmup":
        return warmup()
    if len(sys.argv) >= 3 and sys.argv[1] == "ocr":
        return client(sys.argv[2])
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
    print("usage: ocr-daemon.py serve | warmup | ocr <image> | <image>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
