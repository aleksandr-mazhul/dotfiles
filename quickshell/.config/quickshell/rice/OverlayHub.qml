pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: hub

    property var panels: []
    property var clipboard: null
    property var launcher: null
    property var wallpaper: null
    property var vpn: null
    property var quickSettings: null
    property var calendar: null
    property var notifications: null
    property bool barVisible: true
    // false = autohide + top-edge peek (like fullscreen); true = always on.
    // Persisted across reboots via stateFile below.
    property bool barPinned: false
    // Notifications mute / DND — also persisted.
    property bool notifDnd: false

    // Avoid writing defaults before the first disk load finishes.
    property bool _stateReady: false

    // QtObject has no default property — keep FileView as an explicit property.
    property FileView stateFile: FileView {
        path: `${Quickshell.stateDir}/rice.json`
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: stateAdapter
            property bool barPinned: false
            property bool notifDnd: false

            // Disk → hub (initial load + external file edits).
            onBarPinnedChanged: {
                if (hub.barPinned !== barPinned)
                    hub.barPinned = barPinned
            }
            onNotifDndChanged: {
                if (hub.notifDnd !== notifDnd)
                    hub.notifDnd = notifDnd
            }
        }
    }

    Component.onCompleted: {
        hub.barPinned = stateAdapter.barPinned
        hub.notifDnd = stateAdapter.notifDnd
        hub._stateReady = true
    }

    // Hub → disk.
    onBarPinnedChanged: {
        if (!hub._stateReady)
            return
        if (stateAdapter.barPinned !== hub.barPinned)
            stateAdapter.barPinned = hub.barPinned
    }

    onNotifDndChanged: {
        if (!hub._stateReady)
            return
        if (stateAdapter.notifDnd !== hub.notifDnd)
            stateAdapter.notifDnd = hub.notifDnd
    }

    function toggleBar() {
        barPinned = !barPinned
        barVisible = true
    }

    function toggleQuickSettings() {
        if (calendar)
            calendar.open = false
        if (notifications)
            notifications.open = false
        if (!quickSettings)
            return
        if (quickSettings.open)
            quickSettings.close()
        else
            quickSettings.show()
    }

    function toggleCalendar() {
        if (quickSettings)
            quickSettings.open = false
        if (notifications)
            notifications.open = false
        if (!calendar)
            return
        if (calendar.open)
            calendar.close()
        else
            calendar.show()
    }

    function toggleNotifications() {
        if (quickSettings)
            quickSettings.open = false
        if (calendar)
            calendar.open = false
        if (!notifications)
            return
        if (notifications.open)
            notifications.close()
        else
            notifications.show()
    }
    function register(panel) {
        if (!panel)
            return
        if (panels.indexOf(panel) < 0)
            panels = panels.concat([panel])
    }

    // Parked popups under the current one (Raycast-style Esc back).
    property var overlayStack: []

    function mapOverlay(id) {
        return {
            clipboard: clipboard,
            launcher: launcher,
            wallpaper: wallpaper,
            vpn: vpn
        }[id] || null
    }

    function dropStack(except) {
        const parked = overlayStack.slice()
        overlayStack = []
        for (let i = 0; i < parked.length; i++) {
            const p = parked[i]
            if (!p || p === except)
                continue
            if (typeof p.hide === "function")
                p.hide()
            else if (typeof p.close === "function")
                p.close()
        }
    }

    function closeOthers(except) {
        dropStack(except)
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (p && p !== except && p.open)
                p.close()
        }
    }

    function closeAll() {
        dropStack(null)
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (p && p.open)
                p.close()
        }
    }

    // Open a page on top of `from` without destroying it. Esc pops back.
    function pushFrom(from, id) {
        if (from === launcher && launcher && typeof launcher.openPage === "function") {
            launcher.openPage(id)
            return
        }
        if (launcher && typeof launcher.openPage === "function"
                && (id === "clipboard" || id === "wallpaper" || id === "vpn")) {
            launcher.openPage(id)
            return
        }
        const target = mapOverlay(id)
        if (!target)
            return
        if (from && from.open) {
            if (typeof from.park === "function") {
                from.park()
                overlayStack = overlayStack.concat([from])
            } else {
                from.close()
            }
        }
        if (typeof target.present === "function")
            target.present()
        else if (typeof target.show === "function")
            target.show()
    }

    // One step back: in-surface view stack, then parked overlay, else hide.
    function pop(panel) {
        if (panel && typeof panel.popView === "function" && panel.popView())
            return
        if (panel && typeof panel.close === "function")
            panel.close()
        else if (panel && typeof panel.hide === "function")
            panel.hide()
    }

    function open(id) {
        if (id === "launcher" && launcher && typeof launcher.show === "function") {
            launcher.show()
            return
        }
        if (launcher && typeof launcher.openPage === "function"
                && (id === "clipboard" || id === "wallpaper" || id === "vpn")) {
            launcher.openPage(id)
            return
        }
        const p = mapOverlay(id)
        if (p && typeof p.show === "function")
            p.show()
    }

    // Contextual filter: toggle only on an already-open overlay / launcher page.
    function toggleFilter() {
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (!p || !p.open)
                continue
            // Prefer page-aware routing (Launcher → clipboard/wallpaper/vpn).
            if (typeof p.toggleFilter === "function") {
                p.toggleFilter()
                return
            }
            if (typeof p.toggleFilterMenu === "function") {
                p.toggleFilterMenu()
                return
            }
            if (typeof p.showFilter === "function") {
                p.showFilter()
                return
            }
            return
        }
        if (launcher && launcher.open && typeof launcher.toggleFilter === "function") {
            launcher.toggleFilter()
        }
    }

    function refocusOpen() {
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (!p || !p.open)
                continue
            if (typeof p.grabFocus === "function") {
                p.grabFocus()
                return
            }
            if (typeof p.refocusInput === "function") {
                p.refocusInput()
                return
            }
            return
        }
        if (launcher && launcher.open && typeof launcher.grabFocus === "function")
            launcher.grabFocus()
    }
}
