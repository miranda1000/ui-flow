import QtQuick
import QtQuick.Layouts

// Message with up to three choices: accept (primary), discard (optional), cancel.
FDialog {
    id: dialog
    property string message
    property string acceptText: qsTr("OK")
    property string discardText
    property bool showCancel: true

    ColumnLayout {
        width: parent.width
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: dialog.message
            wrapMode: Text.Wrap
            lineHeight: 1.25
            color: Theme.text
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8
            FButton {
                visible: !!dialog.discardText
                variant: "ghost"
                text: dialog.discardText
                onClicked: {
                    dialog.close()
                    dialog.discarded()
                }
            }
            Item { Layout.fillWidth: true }
            FButton { visible: dialog.showCancel; text: qsTr("Cancel"); onClicked: dialog.reject() }
            FButton { variant: "primary"; text: dialog.acceptText; onClicked: dialog.accept() }
        }
    }
}
