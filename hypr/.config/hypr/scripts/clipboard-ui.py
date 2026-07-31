#!/usr/bin/env python3
"""Minimal always-on-top clipboard popup. Pastes back into the original window."""

from __future__ import annotations

import os
import re
import shutil
import signal
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Pango

BINARY_RE = re.compile(r"\[\[\s*binary data\b(.*?)\]\]", re.I)
IMAGE_HINT_RE = re.compile(r"(image/[\w.+-]+|\bpng\b|\bjpe?g\b|\bwebp\b|\bgif\b)", re.I)
# Preview: consistent height, natural aspect ratio, no square letterbox
THUMB_HEIGHT = 96
THUMB_MAX_WIDTH = 520
THUMB_RADIUS = 12
TMP_DIR = Path(tempfile.gettempdir()) / "hypr-clipboard-paste"
PID_FILE = Path(tempfile.gettempdir()) / "hypr-clipboard-ui.pid"

CSS = """
window.clip-window {
  background-color: #18181b;
  color: #f2f2f7;
  border-radius: 16px;
}

.clip-root {
  background-color: #18181b;
  border-radius: 16px;
  border: 1px solid #35353a;
}

.clip-title {
  color: #ffffff;
  font-size: 16px;
  font-weight: 700;
}

.clip-count {
  color: #98989f;
  font-size: 12px;
  font-weight: 600;
}

.clip-footer {
  color: #8e8e93;
  font-size: 12px;
  font-weight: 500;
}

scrolledwindow {
  background-color: #18181b;
  border-radius: 12px;
}

list {
  background-color: #202024;
  border-radius: 12px;
  border: 1px solid #303036;
}

row {
  background-color: #202024;
  color: #f2f2f7;
  border-radius: 0;
  border-bottom: 1px solid #303036;
  min-height: 56px;
  padding: 0;
  margin: 0;
}

row.image-row {
  min-height: 116px;
}

row:last-child {
  border-bottom: none;
}

row:hover {
  background-color: #29292e;
}

row:selected {
  background-color: #2b405c;
  color: #ffffff;
}

row:selected label {
  color: #ffffff;
}

row:selected .mark-badge.empty {
  background-color: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.7);
}

.mark-badge {
  background-color: #0a84ff;
  color: #ffffff;
  font-weight: 700;
  font-size: 10px;
  min-width: 20px;
  min-height: 20px;
  border-radius: 10px;
  padding: 0;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
}

.mark-badge.empty {
  background-color: #2c2c30;
  color: transparent;
  border: 1px solid #5a5a61;
  min-width: 20px;
  min-height: 20px;
  box-shadow: none;
}

.preview-label {
  color: inherit;
  font-size: 15px;
  font-weight: 450;
}

/* No chrome behind screenshots — only the pixels */
.image-thumb {
  background-color: transparent;
  background-image: none;
  border: none;
  box-shadow: none;
  padding: 0;
  margin: 0;
  outline: none;
}
"""


@dataclass
class ClipItem:
    list_line: str
    item_id: str
    preview: str
    is_image: bool
    mime: str | None = None


def run(cmd: list[str], data: bytes | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, input=data, capture_output=True, check=False)


def cliphist_list() -> list[ClipItem]:
    proc = run(["cliphist", "list"])
    if proc.returncode != 0:
        return []
    items: list[ClipItem] = []
    for raw in proc.stdout.decode("utf-8", errors="replace").splitlines():
        if not raw.strip() or "\t" not in raw:
            continue
        item_id, preview = raw.split("\t", 1)
        # Hide internal paste helper artifacts from history UI
        if "hypr-clipboard-paste" in preview or preview.startswith("file:///tmp/hypr-clipboard"):
            continue
        binary = BINARY_RE.search(preview)
        mime = None
        is_image = False
        if binary:
            hint = IMAGE_HINT_RE.search(binary.group(1) or "")
            if hint:
                is_image = True
                token = hint.group(1).lower()
                mime = (
                    token
                    if token.startswith("image/")
                    else f"image/{token.replace('jpg', 'jpeg')}"
                )
        items.append(
            ClipItem(
                list_line=raw,
                item_id=item_id,
                preview=preview,
                is_image=is_image,
                mime=mime,
            )
        )
    # Newest first (cliphist ids grow monotonically)
    items.sort(key=lambda it: int(it.item_id) if it.item_id.isdigit() else 0, reverse=True)
    return items


def cliphist_decode(list_line: str) -> bytes:
    proc = run(["cliphist", "decode"], data=(list_line + "\n").encode())
    return proc.stdout if proc.returncode == 0 else b""


def load_thumb(data: bytes) -> GdkPixbuf.Pixbuf | None:
    """Scale screenshot to a clean wide preview (no square letterboxing)."""
    try:
        from io import BytesIO

        from PIL import Image, ImageDraw

        im = Image.open(BytesIO(data)).convert("RGBA")
        w, h = im.size
        if w < 1 or h < 1:
            return None

        # Fit height; clamp width so ultra-wide shots stay tidy
        scale = THUMB_HEIGHT / h
        tw = max(1, int(round(w * scale)))
        th = THUMB_HEIGHT
        if tw > THUMB_MAX_WIDTH:
            scale = THUMB_MAX_WIDTH / w
            tw = THUMB_MAX_WIDTH
            th = max(1, int(round(h * scale)))

        im = im.resize((tw, th), Image.Resampling.LANCZOS)

        # Soft rounded clip baked into pixels — no GTK frame/background
        mask = Image.new("L", (tw, th), 0)
        draw = ImageDraw.Draw(mask)
        draw.rounded_rectangle((0, 0, tw, th), radius=THUMB_RADIUS, fill=255)
        out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        out.paste(im, (0, 0), mask=mask)

        raw = out.tobytes()
        # GLib.Bytes keeps pixel buffer alive for the Pixbuf
        gbytes = GLib.Bytes.new(raw)
        return GdkPixbuf.Pixbuf.new_from_bytes(
            gbytes,
            GdkPixbuf.Colorspace.RGB,
            True,
            8,
            tw,
            th,
            tw * 4,
        )
    except Exception:
        # Fallback without Pillow rounding
        try:
            loader = GdkPixbuf.PixbufLoader()
            loader.write(data)
            loader.close()
            pix = loader.get_pixbuf()
            if pix is None:
                return None
            w, h = pix.get_width(), pix.get_height()
            scale = THUMB_HEIGHT / max(h, 1)
            tw = max(1, int(w * scale))
            th = max(1, int(h * scale))
            if tw > THUMB_MAX_WIDTH:
                scale = THUMB_MAX_WIDTH / max(w, 1)
                tw = THUMB_MAX_WIDTH
                th = max(1, int(h * scale))
            return pix.scale_simple(tw, th, GdkPixbuf.InterpType.BILINEAR)
        except GLib.Error:
            return None


def kill_stale_instances() -> None:
    """Kill only other python interpreters whose argv is this script."""
    my_pid = os.getpid()
    script = str(Path(__file__).resolve())
    script_name = Path(script).name
    try:
        out = subprocess.check_output(["ps", "-eo", "pid=,cmd="], text=True)
    except subprocess.CalledProcessError:
        return
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            pid_s, cmd = line.split(None, 1)
            pid = int(pid_s)
        except ValueError:
            continue
        if pid == my_pid:
            continue
        tokens = cmd.split()
        if not tokens:
            continue
        if Path(tokens[0]).name not in {"python", "python3"}:
            continue
        if script not in tokens and script_name not in tokens:
            continue
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass


class ClipboardWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application) -> None:
        super().__init__(application=app, title="Clipboard")
        self.add_css_class("clip-window")
        self.set_default_size(680, 600)
        self.set_resizable(False)
        self.set_decorated(False)
        self.set_modal(False)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        self._items: list[ClipItem] = []
        self._marked: list[str] = []
        self._badges: dict[str, Gtk.Label] = {}
        self._thumb_cache: dict[str, GdkPixbuf.Pixbuf | None] = {}

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        root.add_css_class("clip-root")
        root.set_margin_top(14)
        root.set_margin_bottom(14)
        root.set_margin_start(14)
        root.set_margin_end(14)
        self.set_child(root)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title = Gtk.Label(label="Clipboard")
        title.add_css_class("clip-title")
        title.set_halign(Gtk.Align.START)
        title.set_hexpand(True)
        top.append(title)
        self.count_label = Gtk.Label(label="")
        self.count_label.add_css_class("clip-count")
        self.count_label.set_halign(Gtk.Align.END)
        top.append(self.count_label)
        root.append(top)

        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_vexpand(True)
        self.scrolled.set_hexpand(True)
        self.scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scrolled.set_propagate_natural_height(False)
        self.scrolled.set_propagate_natural_width(False)
        self.scrolled.set_min_content_height(448)
        root.append(self.scrolled)

        self.list_box = Gtk.ListBox()
        self.list_box.set_selection_mode(Gtk.SelectionMode.BROWSE)
        self.list_box.set_can_focus(True)
        self.list_box.set_activate_on_single_click(False)
        self.list_box.connect("row-activated", lambda *_: self.paste_and_close())
        self.scrolled.set_child(self.list_box)

        footer = Gtk.Label(label="↑↓ move  ·  ⇧↵ mark  ·  ↵ paste  ·  esc")
        footer.add_css_class("clip-footer")
        footer.set_halign(Gtk.Align.CENTER)
        root.append(footer)

        # Only intercept action keys; let ListBox handle arrows + scrolling
        key = Gtk.EventControllerKey()
        key.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        key.connect("key-pressed", self.on_key)
        self.add_controller(key)

        self.connect("close-request", self.on_close_request)
        self.reload()
        # Keep newest copies on top while the popup is open
        GLib.timeout_add(1000, self._soft_refresh)

    def on_close_request(self, *_args) -> bool:
        app = self.get_application()
        if app is not None:
            GLib.idle_add(app.quit)
        return False

    def _soft_refresh(self) -> bool:
        if not self.get_mapped():
            return False
        fresh = cliphist_list()
        old_ids = [i.item_id for i in self._items]
        new_ids = [i.item_id for i in fresh]
        if old_ids != new_ids:
            # New copy arrived — rebuild list, newest stays first
            keep_sel = self.focused_item().item_id if self.focused_item() else None
            self.reload()
            if keep_sel and keep_sel in {i.item_id for i in self._items}:
                for idx, item in enumerate(self._items):
                    if item.item_id == keep_sel:
                        row = self.list_box.get_row_at_index(idx)
                        if row is not None:
                            self.list_box.select_row(row)
                        break
            else:
                # Prefer jumping to the newest item after a fresh copy
                first = self.list_box.get_row_at_index(0)
                if first is not None:
                    self.list_box.select_row(first)
        return True

    def show_ui(self) -> None:
        self.set_visible(True)
        self.present()
        self.reload()
        GLib.idle_add(self._focus_list)
        GLib.timeout_add(40, self._hypr_top)

    def _hypr_top(self) -> bool:
        run(["hyprctl", "dispatch", "focuswindow", "class:^(com\\.hypr\\.clipboardhistory)$"])
        run(["hyprctl", "dispatch", "bringactivetotop"])
        return False

    def _focus_list(self) -> bool:
        self.list_box.grab_focus()
        row = self.list_box.get_selected_row()
        if row is None:
            row = self.list_box.get_row_at_index(0)
            if row is not None:
                self.list_box.select_row(row)
        if row is not None:
            self._ensure_row_visible(row)
        return False

    def _ensure_row_visible(self, row: Gtk.ListBoxRow) -> None:
        """Keep the selected row inside the scrolled viewport."""
        adj = self.scrolled.get_vadjustment()
        if adj is None:
            return

        def _scroll() -> bool:
            # Allocation is valid after a frame
            row_h = max(row.get_height(), 1)
            # Approximate row top from index * height when allocation is unset
            idx = row.get_index()
            y = idx * row_h
            page = adj.get_page_size()
            value = adj.get_value()
            upper = adj.get_upper()
            if y < value:
                adj.set_value(max(0, y - 8))
            elif y + row_h > value + page:
                adj.set_value(min(upper - page, y + row_h - page + 8))
            return False

        GLib.idle_add(_scroll)

    def update_count(self) -> None:
        n = len(self._marked)
        self.count_label.set_text(f"marked {n}" if n else "")

    def refresh_badges(self) -> None:
        order = {item_id: i + 1 for i, item_id in enumerate(self._marked)}
        for item_id, badge in self._badges.items():
            if item_id in order:
                badge.set_text(str(order[item_id]))
                badge.remove_css_class("empty")
            else:
                badge.set_text(" ")
                badge.add_css_class("empty")
        self.update_count()

    def focused_item(self) -> ClipItem | None:
        row = self.list_box.get_selected_row()
        if row is None:
            return None
        idx = row.get_index()
        if idx < 0 or idx >= len(self._items):
            return None
        return self._items[idx]

    def toggle_mark_focused(self) -> None:
        item = self.focused_item()
        if item is None:
            return
        if item.item_id in self._marked:
            self._marked = [x for x in self._marked if x != item.item_id]
        else:
            self._marked.append(item.item_id)
        self.refresh_badges()
        # Keep keyboard focus in the list after marking
        self.list_box.grab_focus()

    def on_key(self, _ctrl, keyval, _code, state) -> bool:
        shift = bool(state & Gdk.ModifierType.SHIFT_MASK)
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            if shift:
                self.toggle_mark_focused()
                return True
            self.paste_and_close()
            return True
        if keyval == Gdk.KEY_space:
            self.toggle_mark_focused()
            return True
        # Arrow keys: do not capture — ListBox scrolls selection into view
        return False

    def reload(self) -> None:
        while (child := self.list_box.get_first_child()) is not None:
            self.list_box.remove(child)
        self._badges.clear()
        self._items = cliphist_list()
        valid = {x.item_id for x in self._items}
        self._marked = [i for i in self._marked if i in valid]

        if not self._items:
            empty = Gtk.Label(label="Buffer is empty")
            empty.set_margin_top(28)
            empty.set_margin_bottom(28)
            empty.add_css_class("preview-label")
            self.list_box.append(empty)
            self.update_count()
            return

        for item in self._items:
            row = Gtk.ListBoxRow()
            row.set_activatable(True)
            row.set_selectable(True)

            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
            box.set_margin_top(10)
            box.set_margin_bottom(10)
            box.set_margin_start(12)
            box.set_margin_end(12)

            badge = Gtk.Label(label=" ")
            badge.add_css_class("mark-badge")
            badge.add_css_class("empty")
            badge.set_valign(Gtk.Align.CENTER)
            self._badges[item.item_id] = badge
            box.append(badge)

            if item.is_image:
                row.add_css_class("image-row")
                # Bust old square thumbs if cache was from previous version
                if item.item_id not in self._thumb_cache:
                    data = cliphist_decode(item.list_line)
                    self._thumb_cache[item.item_id] = load_thumb(data)
                pix = self._thumb_cache.get(item.item_id)

                image = Gtk.Picture()
                image.add_css_class("image-thumb")
                image.set_can_shrink(False)
                image.set_content_fit(Gtk.ContentFit.CONTAIN)
                image.set_halign(Gtk.Align.START)
                image.set_valign(Gtk.Align.CENTER)
                if pix is not None:
                    image.set_paintable(Gdk.Texture.new_for_pixbuf(pix))
                    image.set_size_request(pix.get_width(), pix.get_height())
                else:
                    fallback = Gtk.Image.new_from_icon_name("image-x-generic")
                    box.append(fallback)
                    row.set_child(box)
                    self.list_box.append(row)
                    continue
                # Screenshot only — no "Image" label, no frame
                box.append(image)
            else:
                text = item.preview.replace("\n", " ")
                if len(text) > 150:
                    text = text[:147] + "…"
                label = Gtk.Label(label=text)
                label.add_css_class("preview-label")
                label.set_xalign(0)
                label.set_hexpand(True)
                label.set_ellipsize(Pango.EllipsizeMode.END)
                box.append(label)

            row.set_child(box)
            self.list_box.append(row)

        first = self.list_box.get_row_at_index(0)
        if first is not None:
            self.list_box.select_row(first)
        self.refresh_badges()

    def items_to_paste(self) -> list[ClipItem]:
        if self._marked:
            by_id = {item.item_id: item for item in self._items}
            return [by_id[i] for i in self._marked if i in by_id]
        item = self.focused_item()
        return [item] if item else []

    def paste_and_close(self) -> None:
        items = self.items_to_paste()
        if not items:
            return

        helper = Path(__file__).with_name("clipboard-paste-helper.sh")
        if all(item.is_image for item in items):
            payload = self._build_uri_payload(items)
            if not payload:
                return
            payload_path = Path(tempfile.gettempdir()) / "hypr-clipboard-uri.txt"
            payload_path.write_bytes(payload)
            subprocess.Popen(
                ["bash", str(helper), "uri", str(payload_path)],
                start_new_session=True,
            )
        else:
            chunks: list[bytes] = []
            metas: list[str] = []
            for item in items:
                data = cliphist_decode(item.list_line)
                if not data:
                    continue
                chunks.append(data)
                metas.append(item.mime if item.is_image and item.mime else "text/plain")
            if not chunks:
                return
            blob_path = Path(tempfile.gettempdir()) / "hypr-clipboard-seq.bin"
            meta_path = Path(tempfile.gettempdir()) / "hypr-clipboard-seq.meta"
            with blob_path.open("wb") as fh:
                for chunk in chunks:
                    fh.write(len(chunk).to_bytes(4, "big"))
                    fh.write(chunk)
            meta_path.write_text("\n".join(metas))
            subprocess.Popen(
                ["bash", str(helper), "seq", str(blob_path), str(meta_path)],
                start_new_session=True,
            )

        app = self.get_application()
        self.set_visible(False)
        if app is not None:
            app.quit()

    def _build_uri_payload(self, items: list[ClipItem]) -> bytes | None:
        if TMP_DIR.exists():
            shutil.rmtree(TMP_DIR, ignore_errors=True)
        TMP_DIR.mkdir(parents=True, exist_ok=True)
        uris: list[str] = []
        for idx, item in enumerate(items, start=1):
            data = cliphist_decode(item.list_line)
            if not data:
                continue
            ext = "png"
            if item.mime and "/" in item.mime:
                ext = item.mime.split("/", 1)[1].split(";")[0] or "png"
                if ext == "jpeg":
                    ext = "jpg"
            path = TMP_DIR / f"clip-{idx}.{ext}"
            path.write_bytes(data)
            uris.append(path.resolve().as_uri())
        if not uris:
            return None
        return ("\n".join(uris) + "\n").encode()


class ClipboardApp(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id="com.hypr.clipboardhistory",
            flags=Gio.ApplicationFlags.NON_UNIQUE,
        )
        self._window: ClipboardWindow | None = None

    def do_activate(self) -> None:  # noqa: N802
        if self._window is None:
            self._window = ClipboardWindow(self)
        self._window.show_ui()


def main() -> None:
    kill_stale_instances()
    PID_FILE.write_text(str(os.getpid()))
    try:
        ClipboardApp().run(None)
    finally:
        try:
            if PID_FILE.exists() and PID_FILE.read_text().strip() == str(os.getpid()):
                PID_FILE.unlink(missing_ok=True)
        except OSError:
            pass


if __name__ == "__main__":
    main()
