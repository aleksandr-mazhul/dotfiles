import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    //@ pragma IconTheme Papirus-Dark

    Clipboard { id: clipboard }
    Launcher { id: launcher }
    Wallpaper { id: wallpaper }
    Vpn { id: vpn }

    Component.onCompleted: {
        OverlayHub.clipboard = clipboard
        OverlayHub.launcher = launcher
        OverlayHub.wallpaper = wallpaper
        OverlayHub.vpn = vpn
    }

    IpcHandler {
        target: "overlay"
        function filter(): void { OverlayHub.toggleFilter() }
        function toggleFilter(): void { OverlayHub.toggleFilter() }
        function open(id: string): void { OverlayHub.open(id) }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboard.toggle() }
        function open(): void { clipboard.show() }
        function close(): void { clipboard.close() }
        function openFilter(): void { clipboard.showFilter() }
        function toggleFilter(): void { clipboard.showFilter() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.show() }
        function close(): void { launcher.close() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { wallpaper.toggle() }
        function open(): void { wallpaper.show() }
        function close(): void { wallpaper.close() }
        function filter(): void { wallpaper.toggleFilter() }
        function toggleFilter(): void { wallpaper.toggleFilter() }
    }

    IpcHandler {
        target: "vpn"
        function toggle(): void { vpn.toggle() }
        function open(): void { vpn.show() }
        function close(): void { vpn.close() }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { Quickshell.reload(true) }
    }
}
