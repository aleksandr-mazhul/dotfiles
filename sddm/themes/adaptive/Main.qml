import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1920
    height: 1080

    property color cAccent: "#ffb688"
    property color cText: "#f0dfd7"
    property color cMuted: "#d7c3b8"
    property color cSurface: "#19120d"
    property color cField: "#312823"
    property color cFail: "#ffb4ab"

    function loadColors() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("colors.conf"))
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var lines = xhr.responseText.split("\n")
            for (var i = 0; i < lines.length; ++i) {
                var line = lines[i].trim()
                if (!line || line.charAt(0) === "#")
                    continue
                var parts = line.split("=")
                if (parts.length < 2)
                    continue
                var key = parts[0].trim()
                var val = parts.slice(1).join("=").trim()
                if (key === "accent") cAccent = val
                else if (key === "text") cText = val
                else if (key === "text_muted") cMuted = val
                else if (key === "surface") cSurface = val
                else if (key === "field_bg") cField = val
                else if (key === "fail") cFail = val
            }
        }
        xhr.send()
    }

    function doLogin() {
        errorLabel.text = ""
        sddm.login(userName.text, password.text, sessionModel.lastIndex)
    }

    Component.onCompleted: {
        loadColors()
        if (userName.text === "")
            userName.forceActiveFocus()
        else
            password.forceActiveFocus()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            errorLabel.text = "Login failed"
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            errorLabel.text = ""
        }
    }

    Image {
        id: bg
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Error)
                source = "background.jpg"
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.40) }
            GradientStop { position: 0.40; color: Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.78) }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -80
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "JetBrains Mono"
            font.pixelSize: 100
            font.weight: Font.Medium
            color: cText
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.40)
            text: Qt.formatTime(clock.date, "HH:mm")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Adwaita Sans"
            font.pixelSize: 18
            color: cMuted
            text: Qt.formatDate(clock.date, "dddd  ·  d MMMM")
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: date = new Date()
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(90, parent.height * 0.11)
        spacing: 12
        width: 340

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            color: cMuted
            text: userName.text
        }

        TextField {
            id: userName
            width: parent.width
            height: 1
            visible: false
            text: userModel.lastUser
        }

        Rectangle {
            width: parent.width
            height: 52
            radius: 16
            color: Qt.rgba(cField.r, cField.g, cField.b, 0.72)
            border.width: password.activeFocus ? 2 : 1
            border.color: password.activeFocus ? cAccent : Qt.rgba(cMuted.r, cMuted.g, cMuted.b, 0.30)

            TextField {
                id: password
                anchors.fill: parent
                anchors.margins: 2
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                echoMode: TextInput.Password
                color: cText
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                background: Item {}

                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        doLogin()
                        event.accepted = true
                    }
                }
            }
        }

        Text {
            id: errorLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            color: cFail
            text: ""
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 8

        Rectangle {
            width: 44; height: 44; radius: 22
            color: powerMa.containsMouse ? Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.55) : "transparent"
            Text {
                anchors.centerIn: parent
                text: "⏻"
                color: cMuted
                font.pixelSize: 18
            }
            MouseArea {
                id: powerMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.powerOff()
            }
        }
        Rectangle {
            width: 44; height: 44; radius: 22
            color: rebootMa.containsMouse ? Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.55) : "transparent"
            Text {
                anchors.centerIn: parent
                text: "↻"
                color: cMuted
                font.pixelSize: 18
            }
            MouseArea {
                id: rebootMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.reboot()
            }
        }
    }
}
