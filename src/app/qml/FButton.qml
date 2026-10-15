import QtQuick
import QtQuick.Controls.Basic

// Text button. variant: "primary" | "secondary" | "ghost" | "danger"
Button {
    id: control
    property string variant: "secondary"
    property string iconName
    property string tip

    implicitHeight: Theme.controlHeight
    leftPadding: iconName && !text ? 6 : 12
    rightPadding: iconName && !text ? 6 : 12
    topPadding: 0
    bottomPadding: 0
    spacing: 6
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium
    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    readonly property color fg: !enabled ? Theme.textTertiary
                              : variant === "primary" ? Theme.textOnAccent
                              : variant === "danger" ? Theme.danger
                              : Theme.text

    contentItem: Row {
        spacing: control.spacing
        Icon {
            visible: !!control.iconName
            name: control.iconName
            color: control.fg
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: control.text.length > 0
            text: control.text
            font: control.font
            color: control.fg
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        implicitHeight: Theme.controlHeight
        radius: Theme.radius
        color: {
            if (control.variant === "primary")
                return !control.enabled ? Theme.pressed
                     : control.down ? Theme.accentPressed
                     : control.hovered ? Theme.accentHover : Theme.accent
            if (control.variant === "danger")
                return control.down ? Theme.dangerSoft : control.hovered ? Theme.dangerSoft : "transparent"
            if (control.variant === "ghost")
                return control.down ? Theme.pressed : control.hovered ? Theme.hover : "transparent"
            return control.down ? Theme.pressed : control.hovered ? Theme.hover : Theme.panel
        }
        border.width: control.variant === "secondary" ? 1 : 0
        border.color: Theme.border
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: Theme.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: control.visualFocus
        }
    }

    FToolTip {
        visible: !!control.tip && control.hovered
        text: control.tip
    }
}
