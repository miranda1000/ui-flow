import QtQuick
import QtQuick.Controls.impl

// A monochrome SVG icon from icons/, tinted with `color`.
Item {
    id: root
    property string name
    property color color: Theme.text
    property alias sourceSize: image.sourceSize
    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize
    width: implicitWidth
    height: implicitHeight

    IconImage {
        id: image
        anchors.fill: parent
        source: root.name ? "icons/" + root.name + ".svg" : ""
        sourceSize: Qt.size(Theme.iconSize, Theme.iconSize)
        color: root.color
    }
}
