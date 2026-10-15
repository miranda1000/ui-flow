import QtQuick

// Hoverable / selectable row for panels. Children are laid out by the caller.
Rectangle {
    id: row
    property bool selected: false
    property bool hovered: mouse.containsMouse
    property bool dark: false
    signal clicked()
    signal doubleClicked()
    signal rightClicked(real x, real y)

    implicitHeight: Theme.rowHeight
    radius: Theme.radius
    color: dark ? (selected ? Theme.darkHover : hovered ? "#333333" : "transparent")
                : (selected ? Theme.accentSoft : hovered ? Theme.hover : "transparent")

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => e.button === Qt.RightButton ? row.rightClicked(e.x, e.y) : row.clicked()
        onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) row.doubleClicked() }
    }
}
