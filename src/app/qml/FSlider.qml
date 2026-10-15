import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: control
    implicitHeight: 24
    padding: 0
    hoverEnabled: true

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 2
        radius: 1
        color: Theme.border
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 1
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 12
        height: 12
        radius: 6
        color: "white"
        border.width: 1
        border.color: control.pressed || control.hovered ? Theme.accent : Theme.borderStrong
    }
}
