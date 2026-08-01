import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    //@ pragma IconTheme Papirus-Dark

    Clipboard { id: clipboard }
    Launcher { id: launcher }
    Wallpaper { id: wallpaper }
    Vpn { id: vpn }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboard.toggle() }
        function open(): void { clipboard.show() }
        function close(): void { clipboard.close() }
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
