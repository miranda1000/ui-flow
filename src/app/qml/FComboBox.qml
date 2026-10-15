import QtQuick
import QtQuick.Controls.Basic

// Filled dropdown with a dark popup list. Use textRole/valueRole with a JS array model.
ComboBox {
    id: control
    implicitHeight: Theme.controlHeight
    leftPadding: 8
    rightPadding: 28
    font.pixelSize: Theme.fontSize
    hoverEnabled: true

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.textTertiary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width - width - 8
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        color: Theme.textSecondary
    }
    background: Rectangle {
        radius: Theme.radius
        color: control.pressed ? Theme.pressed : control.hovered ? Theme.fieldHover : Theme.field
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.accent
    }
    delegate: ItemDelegate {
        id: item
        required property var model
        required property int index
        width: ListView.view ? ListView.view.width : 200
        height: 26
        leftPadding: 26
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: item.model[control.textRole] ?? ""
            font.pixelSize: Theme.fontSize
            color: "white"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Icon {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            width: 14
            height: 14
            sourceSize: Qt.size(14, 14)
            color: "white"
            visible: control.currentIndex === item.index
        }
        background: Rectangle {
            radius: 4
            color: item.highlighted ? Theme.accent : "transparent"
        }
    }
    popup: Popup {
        y: control.height + 4
        width: Math.max(control.width, 180)
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 320)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
            color: Theme.dark
            radius: 8
        }
    }
}
