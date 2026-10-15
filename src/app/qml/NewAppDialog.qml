import QtQuick
import QtQuick.Layouts

FDialog {
    id: dialog
    title: qsTr("New app")
    property alias appName: nameField.text

    function openFresh() {
        nameField.text = qsTr("My app")
        open()
    }
    onOpened: {
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    ColumnLayout {
        width: parent.width
        spacing: 8
        Text { text: qsTr("Name"); font.pixelSize: Theme.fontSizeSmall; color: Theme.textSecondary }
        FTextField {
            id: nameField
            Layout.fillWidth: true
            onAccepted: if (text.trim().length) dialog.accept()
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: qsTr("Next, choose where to save it. The whole app – screens, images and flow – is one .json file.")
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textSecondary
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8
            Item { Layout.fillWidth: true }
            FButton { text: qsTr("Cancel"); onClicked: dialog.reject() }
            FButton {
                variant: "primary"
                text: qsTr("Create…")
                enabled: nameField.text.trim().length > 0
                onClicked: dialog.accept()
            }
        }
    }
}
