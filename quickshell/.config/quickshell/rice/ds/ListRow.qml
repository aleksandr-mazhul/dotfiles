import QtQuick
import QtQuick.Layouts
import ".."

// List Pattern row v2: [leading] primary secondary… [trailing].
// Trailing is a persistent quiet affordance (kbd badge or chevron) that
// strengthens slightly on hover/selection (ref #8, ADR-0005).
Item {
    id: root

    property string primary: ""
    property string secondary: ""
    // Shortcut badges, e.g. ["super", "Q"]; empty = none.
    property var trailingKeys: []
    // Navigation affordance (apps, submenus).
    property bool chevron: false
    property bool selected: false
    property Component leading: null

    signal entered()
    signal activated()

    height: Tokens.rowHeight

    SelectionPill {
        anchors.fill: parent
        hovered: mouse.containsMouse
        selected: root.selected
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.rowPaddingX
        anchors.rightMargin: Tokens.rowPaddingX
        spacing: Tokens.gapInline

        Loader {
            active: !!root.leading
            visible: active
            sourceComponent: root.leading
            Layout.preferredWidth: Tokens.leadingSize
            Layout.preferredHeight: Tokens.leadingSize
        }

        Text {
            text: root.primary
            color: Tokens.textPrimary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSize
            elide: Text.ElideRight
            Layout.fillWidth: root.secondary.length === 0
            Layout.maximumWidth: root.secondary.length === 0 ? -1 : Math.round(root.width * 0.55)
        }

        Text {
            visible: root.secondary.length > 0
            text: root.secondary
            color: Tokens.textSecondary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Row {
            visible: root.trailingKeys.length > 0
            spacing: 4
            opacity: (root.selected || mouse.containsMouse) ? 1.0 : 0.7
            Behavior on opacity {
                NumberAnimation { duration: Tokens.stateMs }
            }

            Repeater {
                model: root.trailingKeys
                KbdBadge {
                    required property var modelData
                    key: modelData
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        RiceIcon {
            visible: root.chevron && root.trailingKeys.length === 0
            customSource: Qt.resolvedUrl("../assets/chevron-right.svg")
            tint: (root.selected || mouse.containsMouse) ? Tokens.textSecondary : Tokens.textTertiary
            implicitSize: 14
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onClicked: root.activated()
    }
}
