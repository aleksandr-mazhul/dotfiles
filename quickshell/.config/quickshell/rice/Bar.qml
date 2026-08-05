import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    required property var modelData
    property var quickSettings
    property var calendar
    property var notifCenter
    // Alt+Shift+F: keep bar visible in normal mode (ignored while fullscreen).
    property bool pinned: false

    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int monitorId: hyprMonitor ? hyprMonitor.id : -1

    // Polled from hyprctl — reliable for Super+F (fullscreen: 2).
    property bool fsPolled: false
    readonly property bool fullscreenActive: root.fsPolled

    readonly property bool panelOpen: {
        const active = (p) => !!(p && (p.open || p.surfaceActive || p.visible))
        if (active(quickSettings) || active(calendar) || active(notifCenter))
            return true
        const hubPanels = OverlayHub.panels || []
        for (let i = 0; i < hubPanels.length; i++) {
            if (active(hubPanels[i]))
                return true
        }
        return false
    }
    property bool hovering: false
    property bool revealed: false

    // Fullscreen: only hover / open panel can show the bar (pin does NOT keep it).
    // Normal: pin OR hover OR panel.
    readonly property bool showContent: root.fullscreenActive
        ? (root.panelOpen || root.revealed)
        : (root.pinned || root.revealed || root.panelOpen)

    readonly property int fullHeight: Theme.barHeight + Theme.barMargin * 2
    // Tall enough to catch the cursor at the physical screen edge.
    readonly property int triggerHeight: 10
    // Only pinned bar reserves space. Autohide overlays content — no exclusiveZone flicker.
    readonly property bool reserveSpace: root.pinned && !root.fullscreenActive

    screen: modelData
    color: "transparent"
    visible: true
    // Keep layer size CONSTANT. Resizing 3↔full on every menu open is the jerk.
    implicitHeight: root.fullHeight
    exclusiveZone: root.reserveSpace ? (Theme.barHeight + Theme.barMargin) : 0

    anchors {
        top: true
        left: true
        right: true
    }

    // Always flush to the top edge so the autohide hit-strip is reachable.
    // Visual inset lives on barRow (topMargin), not on the layer.
    margins {
        top: 0
        left: Theme.barMargin
        right: Theme.barMargin
    }

    exclusionMode: root.reserveSpace ? ExclusionMode.Auto : ExclusionMode.Ignore
    focusable: false
    // Input region: full bar when shown, thin top strip when autohidden.
    mask: Region { item: barHitbox }
    // Overlay while a menu is open so the same island hitbox toggles close
    // (menus are Overlay and would otherwise sit above the Top bar).
    WlrLayershell.layer: (root.fullscreenActive || root.panelOpen) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function keepOpen() {
        hideTimer.stop()
        showTimer.stop()
        root.revealed = true
    }

    function forceHideForFullscreen() {
        showTimer.stop()
        hideTimer.stop()
        root.hovering = false
        if (!root.panelOpen)
            root.revealed = false
    }

    function onEdgeEnter() {
        root.hovering = true
        hideTimer.stop()
        if (!root.showContent)
            showTimer.restart()
        else
            root.revealed = true
    }

    function onEdgeLeave() {
        // Height/mask can change mid-reveal; confirm leave after the frame settles.
        Qt.callLater(function () {
            if (barHover.hovered) {
                root.hovering = true
                hideTimer.stop()
                return
            }
            root.hovering = false
            showTimer.stop()
            if (root.panelOpen)
                return
            if (root.pinned && !root.fullscreenActive)
                return
            hideTimer.restart()
        })
    }

    function openQuickSettings() {
        keepOpen()
        if (calendar)
            calendar.close()
        if (notifCenter)
            notifCenter.close()
        if (!quickSettings)
            return
        if (quickSettings.open)
            quickSettings.close()
        else
            quickSettings.show()
    }

    function openCalendar() {
        keepOpen()
        if (quickSettings)
            quickSettings.close()
        if (notifCenter)
            notifCenter.close()
        if (!calendar)
            return
        if (calendar.open)
            calendar.close()
        else
            calendar.show()
    }

    function openNotifications() {
        keepOpen()
        if (quickSettings)
            quickSettings.close()
        if (calendar)
            calendar.close()
        if (!notifCenter)
            return
        if (notifCenter.open)
            notifCenter.close()
        else
            notifCenter.show()
    }

    // Poll active workspace on this monitor for fullscreen (Super+F → mode 2).
    // Pin mode is ignored while this is true; hover can still reveal the bar.
    Process {
        id: fsCheck
        command: [
            "bash", "-lc",
            "mid='" + root.monitorId + "'; "
            + "if [ \"$mid\" = \"-1\" ]; then echo 0; exit 0; fi; "
            + "ws=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson mid \"$mid\" "
            + "'.[] | select(.id == $mid) | .activeWorkspace.id' 2>/dev/null); "
            + "case \"$ws\" in ''|null) echo 0; exit 0 ;; esac; "
            + "hyprctl clients -j 2>/dev/null | jq -r --argjson mid \"$mid\" --argjson ws \"$ws\" "
            + "'[.[] | select(.monitor == $mid and .workspace.id == $ws "
            + "and (((.fullscreen // 0) | tonumber) > 0))] "
            + "| if length > 0 then 1 else 0 end' 2>/dev/null || echo 0"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim() === "1"
                if (v === root.fsPolled)
                    return
                root.fsPolled = v
                if (v)
                    root.forceHideForFullscreen()
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.monitorId < 0 || fsCheck.running)
                return
            fsCheck.running = true
        }
    }

    onShowContentChanged: {
        if (root.showContent) {
            hideTimer.stop()
            if (barHover.hovered)
                root.hovering = true
        }
    }

    onPanelOpenChanged: {
        if (root.panelOpen) {
            keepOpen()
        } else if (!root.hovering && !(root.pinned && !root.fullscreenActive)) {
            hideTimer.restart()
        }
    }

    onFullscreenActiveChanged: {
        if (root.fullscreenActive)
            root.forceHideForFullscreen()
    }

    onPinnedChanged: {
        // Pin only applies outside fullscreen.
        if (root.pinned && !root.fullscreenActive) {
            keepOpen()
        } else if (!root.pinned && !root.hovering && !root.panelOpen) {
            hideTimer.restart()
        }
    }

    Timer {
        id: showTimer
        interval: 100
        onTriggered: root.revealed = true
    }

    Timer {
        id: hideTimer
        interval: 400
        onTriggered: {
            if (root.panelOpen || root.hovering)
                return
            if (root.pinned && !root.fullscreenActive)
                return
            root.revealed = false
        }
    }

    // True while the bar is up or still sliding/fading — keeps the input mask full.
    readonly property bool barInteractive: root.showContent || barMotion.opacity > 0.02

    // Hit region for the input mask: full bar when shown/animating, top strip when hidden.
    Item {
        id: barHitbox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.barInteractive ? parent.height : root.triggerHeight
    }

    // Track hover on the whole layer (mask still clips input to barHitbox).
    // ApprovesTakeOver so island TapHandlers keep a stable open/close hitbox.
    HoverHandler {
        id: barHover
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onHoveredChanged: {
            if (hovered)
                root.onEdgeEnter()
            else
                root.onEdgeLeave()
        }
    }

    // Slide + fade — QML-side so Hyprland layer tweens stay off.
    Item {
        id: barMotion
        width: parent.width
        height: parent.height
        y: root.showContent ? 0 : -(Theme.barHeight + Theme.barMargin)
        opacity: root.showContent ? 1 : 0
        visible: opacity > 0.001
        z: 1
        clip: false

        Behavior on y {
            NumberAnimation {
                duration: root.showContent ? 340 : 260
                easing.type: root.showContent ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.showContent ? 300 : 220
                easing.type: root.showContent ? Easing.OutCubic : Easing.InCubic
            }
        }

        RowLayout {
            id: barRow
            anchors.fill: parent
            anchors.topMargin: Theme.barMargin
            anchors.bottomMargin: Theme.barMargin
            spacing: Theme.barGap

            RowLayout {
                spacing: Theme.barGap
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                BarWorkspaces {}
                BarActiveWindow {}
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: Theme.barGap
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                BarQsButton {
                    onActivated: root.openQuickSettings()
                }

                BarClockButton {
                    onActivated: root.openCalendar()
                }

                BarNotifButton {
                    muted: !!(notifCenter && notifCenter.dnd)
                    unread: notifCenter ? notifCenter.unread : 0
                    onActivated: root.openNotifications()
                }
            }
        }
    }
}
