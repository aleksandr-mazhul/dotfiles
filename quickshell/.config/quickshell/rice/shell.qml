import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    //@ pragma IconTheme Papirus-Dark

    Clipboard { id: clipboard }
    Launcher { id: launcher }
    Wallpaper { id: wallpaper }
    Vpn { id: vpn }

    // Ids must differ from Bar property names — `calendar: calendar` self-binds to null.
    QuickSettings { id: qsPanel }
    Calendar { id: calendarPanel }
    Notifications { id: notifications }
    Osd {}
    GroupStackBar {}

    Variants {
        model: Quickshell.screens

        Bar {
            // Variants injects modelData into the root component
            quickSettings: qsPanel
            calendar: calendarPanel
            notifCenter: notifications
            pinned: OverlayHub.barPinned
        }
    }

    Component.onCompleted: {
        OverlayHub.clipboard = clipboard
        OverlayHub.launcher = launcher
        OverlayHub.wallpaper = wallpaper
        OverlayHub.vpn = vpn
        OverlayHub.quickSettings = qsPanel
        OverlayHub.calendar = calendarPanel
        OverlayHub.notifications = notifications
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
        target: "bar"
        function toggle(): void {
            // Pin / unpin: pinned = always visible; unpinned = autohide at top edge.
            OverlayHub.barPinned = !OverlayHub.barPinned
            OverlayHub.barVisible = true
            if (!OverlayHub.barPinned) {
                qsPanel.close()
                calendarPanel.close()
                notifications.close()
            }
        }
        function showBar(): void {
            OverlayHub.barPinned = true
            OverlayHub.barVisible = true
        }
        function hideBar(): void {
            OverlayHub.barPinned = false
            OverlayHub.barVisible = true
            qsPanel.close()
            calendarPanel.close()
            notifications.close()
        }
        function toggleQuickSettings(): void {
            calendarPanel.close()
            notifications.close()
            qsPanel.toggle()
        }
        function openQuickSettings(): void {
            calendarPanel.close()
            notifications.close()
            qsPanel.show()
        }
        function closeQuickSettings(): void { qsPanel.close() }
        function toggleCalendar(): void {
            qsPanel.close()
            notifications.close()
            calendarPanel.toggle()
        }
        function openCalendar(): void {
            qsPanel.close()
            notifications.close()
            calendarPanel.show()
        }
        function closeCalendar(): void { calendarPanel.close() }
        function toggleNotifications(): void {
            qsPanel.close()
            calendarPanel.close()
            notifications.toggle()
        }
        function openNotifications(): void {
            qsPanel.close()
            calendarPanel.close()
            notifications.show()
        }
        function closeNotifications(): void { notifications.close() }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { Quickshell.reload(true) }
    }
}
