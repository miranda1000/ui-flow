import QtQuick
import QtQuick.Layouts

// Small bold section title with optional trailing controls (children go to the right).
Item {
    id: root
    property string text
    property color color: Theme.text
    default property alias actions: actionRow.data
    Layout.fillWidth: true
    implicitHeight: 36

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: root.color
    }
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: -6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
