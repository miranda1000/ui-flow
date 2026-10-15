import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Centered modal card with a title bar. Put the body (and a button row) as children.
Dialog {
    id: dialog
    property int dialogWidth: 400
    modal: true
    anchors.centerIn: Overlay.overlay
    width: dialogWidth
    padding: Theme.padding
    topPadding: 4
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle { color: "#40000000" }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }

    header: Item {
        implicitHeight: 48
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: Theme.text
        }
        FIconButton {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            iconName: "close"
            onClicked: dialog.reject()
        }
    }
    background: Rectangle {
        color: Theme.panel
        radius: Theme.radiusLarge
        border.width: 1
        border.color: Theme.border
    }
}
