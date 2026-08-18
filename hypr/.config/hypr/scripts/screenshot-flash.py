#!/usr/bin/env python3
"""Fullscreen shutter veil — same family as slurp's region dim, not a white blast."""
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

HOLD_MS = 240
# slurp default background is #FFFFFF40 — pale gray wash, desktop still readable.
VEIL_ALPHA = 64 / 255


def _draw(_widget, cr):
    cr.set_operator(1)  # cairo.OPERATOR_SOURCE
    cr.set_source_rgba(1.0, 1.0, 1.0, VEIL_ALPHA)
    cr.paint()
    return False


def _flash_window(monitor) -> Gtk.Window:
    win = Gtk.Window()
    win.set_decorated(False)
    win.set_resizable(True)
    win.set_accept_focus(False)
    win.set_app_paintable(True)
    screen = win.get_screen()
    visual = screen.get_rgba_visual() if screen is not None else None
    if visual is not None:
        win.set_visual(visual)
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_namespace(win, "rice-screenshot-flash")
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_exclusive_zone(win, -1)
    if monitor is not None:
        GtkLayerShell.set_monitor(win, monitor)
        geo = monitor.get_geometry()
        win.set_size_request(max(geo.width, 64), max(geo.height, 64))
    for edge in (
        GtkLayerShell.Edge.TOP,
        GtkLayerShell.Edge.BOTTOM,
        GtkLayerShell.Edge.LEFT,
        GtkLayerShell.Edge.RIGHT,
    ):
        GtkLayerShell.set_anchor(win, edge, True)
    area = Gtk.DrawingArea()
    area.set_app_paintable(True)
    area.connect("draw", _draw)
    win.add(area)
    win.show_all()
    return win


def main() -> None:
    Gtk.init([])
    display = Gdk.Display.get_default()
    if display is None:
        raise SystemExit("no display")
    n = display.get_n_monitors()
    windows = []
    if n <= 0:
        windows.append(_flash_window(None))
    else:
        for i in range(n):
            windows.append(_flash_window(display.get_monitor(i)))
    GLib.timeout_add(HOLD_MS, Gtk.main_quit)
    Gtk.main()
    for win in windows:
        win.destroy()


if __name__ == "__main__":
    main()
