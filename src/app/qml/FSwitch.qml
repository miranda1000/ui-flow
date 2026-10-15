import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    implicitHeight: 24
    padding: 0
    spacing: 8
    font.pixelSize: Theme.fontSize
    hoverEnabled: true

    indicator: Rectangle {
        implicitWidth: 26
        implicitHeight: 14
        x: control.width - width
        anchors.verticalCenter: parent.verticalCenter
        radius: 7
        color: control.checked ? Theme.accent : Theme.borderStrong
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 10
            height: 10
            radius: 5
            y: 2
            x: control.checked ? parent.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        text: control.text
        font: control.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        rightPadding: control.indicator.width + control.spacing
        elide: Text.ElideRight
    }
}
