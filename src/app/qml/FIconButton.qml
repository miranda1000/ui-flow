import QtQuick
import QtQuick.Controls.Basic

// Square icon-only button (toolbars, list rows).
AbstractButton {
    id: control
    property string iconName
    property string tip
    property color iconColor: !enabled ? Theme.textTertiary : checked ? Theme.accent : Theme.text
    property bool dark: false
    property int size: Theme.controlHeight

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            color: control.dark ? (control.enabled ? Theme.darkText : Theme.darkTextSecondary) : control.iconColor
        }
    }
    background: Rectangle {
        radius: Theme.radius
        color: control.dark
               ? (control.down ? Theme.darkBorder : control.hovered || control.checked ? Theme.darkHover : "transparent")
               : (control.down ? Theme.pressed : control.checked ? Theme.accentSoft : control.hovered ? Theme.hover : "transparent")
    }

    FToolTip {
        visible: !!control.tip && control.hovered
        text: control.tip
    }
}
