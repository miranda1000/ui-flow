import QtQuick
import QtQuick.Controls.Basic

// Dark popup menu, as in Figma.
Menu {
    id: menu
    property int menuWidth: 232
    padding: 6
    margins: 8
    overlap: 4
    delegate: FMenuItem {}

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 70 } }

    background: Rectangle {
        implicitWidth: menu.menuWidth
        color: Theme.dark
        radius: 8
        border.width: 1
        border.color: "#000000"
    }
}
