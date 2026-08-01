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

    readonly property bool panelOpen: !!(
        (quickSettings && quickSettings.open)
        || (calendar && calendar.open)
        || (notifCenter && notifCenter.open)
    )
    property bool hovering: false
    property bool revealed: false

    // Fullscreen: only hover / open panel can show the bar (pin does NOT keep it).
    // Normal: pin OR hover OR panel.
    readonly property bool showContent: root.fullscreenActive
        ? (root.panelOpen || root.revealed)
        : (root.pinned || root.revealed || root.panelOpen)

    readonly property int fullHeight: Theme.barHeight + Theme.barMargin * 2
    readonly property int triggerHeight: 3

    screen: modelData
    color: "transparent"
    visible: true
    implicitHeight: root.showContent ? root.fullHeight : root.triggerHeight
    exclusiveZone: root.showContent ? (Theme.barHeight + Theme.barMargin) : 0

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: root.showContent ? Theme.barMargin : 0
        left: Theme.barMargin
        right: Theme.barMargin
    }

    exclusionMode: ExclusionMode.Auto
    focusable: false
    // Ensure the whole bar surface receives pointer input (transparent windows
    // can otherwise end up with an empty / partial click mask).
    mask: Region { item: barHitbox }
    WlrLayershell.layer: root.fullscreenActive ? WlrLayer.Overlay : WlrLayer.Top
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
        interval: 350
        onTriggered: root.revealed = true
    }

    Timer {
        id: hideTimer
        interval: 550
        onTriggered: {
            if (root.panelOpen || root.hovering)
                return
            if (root.pinned && !root.fullscreenActive)
                return
            root.revealed = false
        }
    }

    // Hover only — never steal button clicks from bar islands.
    HoverHandler {
        id: barHover
        onHoveredChanged: {
            if (barHover.hovered) {
                root.hovering = true
                hideTimer.stop()
                if (!root.showContent)
                    showTimer.restart()
                else
                    root.revealed = true
            } else {
                root.hovering = false
                showTimer.stop()
                if (root.panelOpen)
                    return
                if (root.pinned && !root.fullscreenActive)
                    return
                hideTimer.restart()
            }
        }
    }

    // Opaque-enough hit surface so the Wayland input region covers the bar.
    Rectangle {
        id: barHitbox
        anchors.fill: parent
        visible: root.showContent
        color: Qt.rgba(0, 0, 0, 0.01)
        z: -1
    }

    RowLayout {
        id: barRow
        anchors.fill: parent
        spacing: Theme.barGap
        visible: root.showContent
        opacity: root.showContent ? 1 : 0
        z: 1

        Behavior on opacity { NumberAnimation { duration: 120 } }

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
