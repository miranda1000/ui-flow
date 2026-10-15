import QtQuick
import QtQuick.Layouts

// Describe a transition ("user types command help") when it is created, or edit it.
FDialog {
    id: dialog
    property string editId
    property string from
    property string hotspot
    property string to
    readonly property bool isHotspot: hotspot.length > 0
    title: editId ? qsTr("Edit interaction") : qsTr("New transition")

    function openNew(fromId, hotspotId, toId) {
        editId = ""
        from = fromId
        hotspot = hotspotId || ""
        to = toId
        field.text = ""
        open()
    }
    function openEdit(id) {
        const l = Doc.link(id)
        if (!l.id)
            return
        editId = id
        from = l.from
        hotspot = l.hotspot
        to = l.to
        field.text = l.message
        open()
    }
    onOpened: {
        field.forceActiveFocus()
        field.selectAll()
    }
    onAccepted: {
        if (editId)
            Doc.setLinkMessage(editId, field.text)
        else
            Ui.selectLink(Doc.addLink(from, hotspot, to, field.text))
    }

    ColumnLayout {
        width: parent.width
        spacing: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Repeater {
                model: [dialog.from, dialog.to]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    Layout.maximumWidth: 160
                    implicitWidth: chip.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: Theme.field
                    Text {
                        id: chip
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 144)
                        text: (Doc.revision < 0 ? undefined : Doc.screen(parent.modelData).displayName || "")
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }
        Text {
            Layout.topMargin: 6
            text: dialog.isHotspot ? qsTr("Note (optional)") : qsTr("What does the user do to get there?")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textSecondary
        }
        FTextField {
            id: field
            Layout.fillWidth: true
            placeholderText: dialog.isHotspot ? qsTr("e.g. only when the form is valid") : qsTr("e.g. user types command help")
            onAccepted: dialog.accept()
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8
            Item { Layout.fillWidth: true }
            FButton { text: qsTr("Cancel"); onClicked: dialog.reject() }
            FButton {
                variant: "primary"
                text: dialog.editId ? qsTr("Save") : qsTr("Add transition")
                onClicked: dialog.accept()
            }
        }
    }
}
