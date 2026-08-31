//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Launcher { id: launcher }

    // Ids must differ from Bar property names — `calendar: calendar` self-binds to null.
    QuickSettings { id: qsPanel }
    Calendar { id: calendarPanel }
    Notifications { id: notifications }
    Osd {}
    ScreenshotFlash { id: screenshotFlash }
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
        OverlayHub.launcher = launcher
        OverlayHub.clipboard = launcher.clipboard
        OverlayHub.wallpaper = launcher.wallpaper
        OverlayHub.vpn = launcher.vpn
        OverlayHub.quickSettings = qsPanel
        OverlayHub.calendar = calendarPanel
        OverlayHub.notifications = notifications
    }

    IpcHandler {
        target: "overlay"
        function filter(): void { OverlayHub.toggleFilter() }
        function toggleFilter(): void { OverlayHub.toggleFilter() }
        function refocus(): void { OverlayHub.refocusOpen() }
        function open(id: string): void { OverlayHub.open(id) }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { launcher.togglePage("clipboard") }
        function open(): void { launcher.openPage("clipboard") }
        function close(): void { launcher.close() }
        function openFilter(): void { launcher.clipboard.showFilter() }
        function toggleFilter(): void { launcher.clipboard.showFilter() }
        function focusPreview(): void { launcher.clipboardFocusPreview() }
        function focusList(): void { launcher.clipboardFocusList() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.show() }
        function close(): void { launcher.close() }
        function refocus(): void {
            if (launcher.open)
                launcher.grabFocus()
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { launcher.togglePage("wallpaper") }
        function open(): void { launcher.openPage("wallpaper") }
        function close(): void { launcher.close() }
        function filter(): void { launcher.wallpaper.toggleFilter() }
        function toggleFilter(): void { launcher.wallpaper.toggleFilter() }
    }

    IpcHandler {
        target: "vpn"
        function toggle(): void { launcher.togglePage("vpn") }
        function open(): void { launcher.openPage("vpn") }
        function close(): void { launcher.close() }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            // Pinned (always on) ↔ autohide (top-edge hover reveals, like fullscreen).
            // Persisted via OverlayHub.barPinned → rice.json.
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
        target: "screenshot"
        function flash(): void { screenshotFlash.flash() }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { Quickshell.reload(true) }
    }
}
