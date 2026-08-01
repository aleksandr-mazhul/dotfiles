pragma Singleton
import QtQuick

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
    // When false, bar autohides and reveals on top-edge hover hold.
    property bool barPinned: false

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

    function closeOthers(except) {
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (p && p !== except && p.open)
                p.close()
        }
    }

    function closeAll() {
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (p && p.open)
                p.close()
        }
    }

    function open(id) {
        const map = {
            clipboard: clipboard,
            launcher: launcher,
            wallpaper: wallpaper,
            vpn: vpn
        }
        const p = map[id]
        if (p && typeof p.show === "function")
            p.show()
    }

    // Contextual filter: toggle burger on the open overlay; else open clipboard + filter.
    function toggleFilter() {
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (!p || !p.open)
                continue
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
        // Nothing open — default to clipboard with filter menu
        for (let i = 0; i < panels.length; i++) {
            const p = panels[i]
            if (!p || typeof p.showFilter !== "function")
                continue
            if (p.hasFilter === false)
                continue
            p.showFilter()
            return
        }
    }
}
