import QtQuick
import QtQuick.Controls.Basic

MenuItem {
    id: control
    property string shortcutText
    property string iconName
    property bool danger: false

    implicitHeight: visible ? 26 : 0
    leftPadding: 26
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    font.pixelSize: Theme.fontSize
    hoverEnabled: true

    readonly property color fg: !enabled ? "#6E6E6E" : control.highlighted ? "white" : control.danger ? "#FF8A70" : Theme.darkText

    indicator: Icon {
        x: 7
        anchors.verticalCenter: parent.verticalCenter
        name: control.checked ? "check" : control.iconName
        visible: control.checked || !!control.iconName
        width: 14
        height: 14
        sourceSize: Qt.size(14, 14)
        color: control.fg
    }
    arrow: Icon {
        x: control.width - width - 6
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-right"
        visible: !!control.subMenu
        width: 14
        height: 14
        sourceSize: Qt.size(14, 14)
        color: control.fg
    }
    contentItem: Item {
        implicitWidth: label.implicitWidth + (shortcut.text ? shortcut.implicitWidth + 24 : 0) + (control.subMenu ? 16 : 0)
        Text {
            id: label
            anchors.left: parent.left
            anchors.right: shortcut.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: control.fg
            elide: Text.ElideRight
        }
        Text {
            id: shortcut
            anchors.right: parent.right
            anchors.rightMargin: control.subMenu ? 14 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: control.shortcutText
            font.pixelSize: Theme.fontSizeSmall
            color: control.highlighted ? "#DDEEFF" : "#8C8C8C"
        }
    }
    background: Rectangle {
        implicitWidth: 200
        radius: 4
        color: control.highlighted && control.enabled ? Theme.accent : "transparent"
    }
}
