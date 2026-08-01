pragma Singleton
import QtQuick

QtObject {
    id: hub

    property var panels: []

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
}
