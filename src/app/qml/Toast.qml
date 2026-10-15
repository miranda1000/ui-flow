import QtQuick

// Short-lived dark notification at the bottom of the window.
Rectangle {
    id: toast
    property alias text: label.text
    function show(message) {
        label.text = message
        opacity = 1
        hideTimer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 32
    width: label.implicitWidth + 32
    height: 34
    radius: 17
    color: Theme.dark
    opacity: 0
    visible: opacity > 0
    z: 1000
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.darkText
        font.pixelSize: Theme.fontSize
    }
    Timer {
        id: hideTimer
        interval: 2200
        onTriggered: toast.opacity = 0
    }
}
