import QtQuick
import QtQuick.Layouts

FDialog {
    id: dialog
    title: qsTr("Keyboard shortcuts")
    dialogWidth: 560

    readonly property var groups: [
        { title: qsTr("Flow"), keys: [
            ["Double-click", qsTr("Edit a screen's hotspots")],
            ["Drag hotspot or its ○", qsTr("Link it to the screen you drop it on")],
            ["Drag screen's ○", qsTr("Described transition to another screen")],
            ["Wheel  /  Shift+wheel", qsTr("Zoom  /  pan sideways")],
            ["Space + drag", qsTr("Pan (also middle / right drag)")],
            ["Shift+1  /  Shift+0", qsTr("Zoom to fit  /  100%")],
            ["Enter", qsTr("Edit selection")],
            ["Del", qsTr("Delete selection")],
            ["Ctrl+D", qsTr("Duplicate screen")],
            ["Ctrl+V", qsTr("Paste an image as a new screen")] ] },
        { title: qsTr("Screen editor"), keys: [
            ["Drag on image", qsTr("Draw a hotspot")],
            ["Click ○ of a hotspot", qsTr("Choose the screen it opens")],
            ["Arrows", qsTr("Nudge hotspot (Shift: 10 px)")],
            ["Esc", qsTr("Back to the flow")] ] },
        { title: qsTr("Player"), keys: [
            ["F5  /  Shift+F5", qsTr("Play from start / from selection")],
            ["1 … 9", qsTr("Take a described transition")],
            ["Backspace  /  R", qsTr("Back  /  restart")],
            ["H", qsTr("Show hotspots")],
            ["Esc", qsTr("Stop")] ] },
        { title: qsTr("File"), keys: [
            ["Ctrl+N  /  Ctrl+O", qsTr("New  /  open")],
            ["Ctrl+S", qsTr("Save (autosave is on by default)")],
            ["Ctrl+Z  /  Ctrl+Shift+Z", qsTr("Undo  /  redo")] ] }
    ]

    ColumnLayout {
        width: parent.width
        spacing: 4
        Repeater {
            model: dialog.groups
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                SectionHeader { text: parent.modelData.title; implicitHeight: 30 }
                Repeater {
                    model: parent.modelData.keys
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 170
                            implicitHeight: 22
                            radius: 4
                            color: Theme.field
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: parent.parent.modelData[0]
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.modelData[1]
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
