import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Right panel: properties of the selection (app, screen or interaction).
Rectangle {
    id: inspector
    color: Theme.panel

    readonly property string screenId: Ui.selectedScreen
    readonly property string linkId: Ui.selectedLink
    readonly property var s: (Doc.revision < 0 ? undefined : screenId ? Doc.screen(screenId) : ({}))
    readonly property var l: (Doc.revision < 0 ? undefined : linkId ? Doc.link(linkId) : ({}))
    readonly property var screens: (Doc.revision < 0 ? undefined : Doc.screenList())
    readonly property var stats: (Doc.revision < 0 ? undefined : Doc.stats())

    function indexOfScreen(id) {
        for (let i = 0; i < screens.length; ++i)
            if (screens[i].id === id)
                return i
        return -1
    }

    // A clickable interaction row: colored dot, action, target.
    component LinkRow: ListRow {
        id: row
        required property var link
        property bool incoming: false
        Layout.fillWidth: true
        implicitHeight: Math.max(40, rowContent.implicitHeight + 12)
        selected: Ui.selectedLink === link.id
        onClicked: Ui.selectLink(link.id)
        onDoubleClicked: Ui.interactionDialog.openEdit(link.id)

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            spacing: 8
            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: row.link.isHotspotLink ? Theme.accent : Theme.transition
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 5
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: row.incoming ? row.link.fromName : row.link.label
                    font.pixelSize: Theme.fontSize
                    color: Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: row.incoming ? row.link.label : "→ " + row.link.toName
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }
            FIconButton {
                visible: row.hovered && !row.incoming
                iconName: "trash"
                size: 24
                tip: qsTr("Delete")
                onClicked: Doc.deleteLink(row.link.id)
            }
        }
    }

    component FieldLabel: Text {
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textSecondary
        Layout.topMargin: 4
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: -Theme.padding
        Layout.rightMargin: -Theme.padding
        Layout.topMargin: 8
        Layout.bottomMargin: 2
        implicitHeight: 1
        color: Theme.border
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            x: Theme.padding
            y: 4
            width: inspector.width - 2 * Theme.padding
            spacing: 6

            // ---------------------------------------------------------- nothing selected
            ColumnLayout {
                visible: !inspector.s.id && !inspector.l.id
                Layout.fillWidth: true
                spacing: 6

                SectionHeader { text: qsTr("App") }
                FieldLabel { text: qsTr("Name") }
                FTextField {
                    Layout.fillWidth: true
                    value: Doc.appName
                    onCommitted: (text) => Doc.setAppName(text)
                }
                FieldLabel { text: qsTr("Start screen") }
                FComboBox {
                    Layout.fillWidth: true
                    enabled: inspector.screens.length > 0
                    model: inspector.screens
                    textRole: "name"
                    valueRole: "id"
                    currentIndex: inspector.indexOfScreen(Doc.startScreen)
                    displayText: inspector.screens.length ? currentText : qsTr("No screens yet")
                    onActivated: Doc.setStartScreen(currentValue)
                }
                Text {
                    Layout.topMargin: 4
                    text: qsTr("%1 screens · %2 interactions").arg(inspector.stats.screens).arg(inspector.stats.links)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textTertiary
                }
                FButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    iconName: "export"
                    text: qsTr("Export flow as Markdown…")
                    onClicked: Ui.main.exportMarkdown()
                }

                Divider {}
                SectionHeader { text: qsTr("How it works") }
                Repeater {
                    model: [
                        qsTr("Drop screenshots on the canvas: each one is a screen."),
                        qsTr("Double-click a screen to draw its hotspots (what can be clicked)."),
                        qsTr("Drag a hotspot onto another screen to say where it leads."),
                        qsTr("Drag a screen's round purple handle onto another screen for transitions such as “user types command help”."),
                        qsTr("Press Play to click through the app.")
                    ]
                    delegate: RowLayout {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 9
                            color: Theme.field
                            Layout.alignment: Qt.AlignTop
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.index + 1
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.modelData
                            wrapMode: Text.Wrap
                            lineHeight: 1.2
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            // ---------------------------------------------------------- screen
            ColumnLayout {
                visible: !!inspector.s.id
                Layout.fillWidth: true
                spacing: 6

                SectionHeader {
                    text: qsTr("Screen")
                    FIconButton {
                        iconName: "play"
                        tip: qsTr("Play from here (Shift+F5)")
                        onClicked: Ui.play(inspector.screenId)
                    }
                    FIconButton {
                        iconName: "more"
                        onClicked: Ui.canvas.screenMenu.popupFor(inspector.screenId)
                    }
                }
                FTextField {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    value: inspector.s.name || ""
                    placeholderText: qsTr("Screen name")
                    onCommitted: (text) => Doc.setScreenName(inspector.screenId, text)
                }
                Text {
                    Layout.fillWidth: true
                    text: inspector.s.imageWidth + " × " + inspector.s.imageHeight + " px" + (inspector.s.fileName ? "  ·  " + inspector.s.fileName : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textTertiary
                    elide: Text.ElideMiddle
                }
                FSwitch {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: qsTr("Start screen")
                    checked: !!inspector.s.isStart
                    onToggled: {
                        if (checked)
                            Doc.setStartScreen(inspector.screenId)
                        checked = Qt.binding(() => !!inspector.s.isStart)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !inspector.s.isStart
                    text: inspector.s.reachable ? qsTr("Reached by: %1").arg(inspector.s.path)
                                                : qsTr("Not reachable from the start screen yet.")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: inspector.s.reachable ? Theme.textSecondary : Theme.warning
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8
                    FieldLabel { text: qsTr("Size"); Layout.topMargin: 0 }
                    FSlider {
                        id: scaleSlider
                        Layout.fillWidth: true
                        from: 0.05
                        to: 1.5
                        value: inspector.s.scale || 1
                        onPressedChanged: if (pressed) Doc.beginChange()
                        onMoved: Doc.setScreenScale(inspector.screenId, value)
                    }
                    Text {
                        text: Math.round(scaleSlider.value * 100) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textSecondary
                        Layout.preferredWidth: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }
                FButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    variant: "primary"
                    iconName: "hotspot"
                    text: inspector.s.hotspotCount ? qsTr("Edit hotspots (%1)").arg(inspector.s.hotspotCount) : qsTr("Add hotspots")
                    onClicked: Ui.openEditor(inspector.screenId, "")
                }

                Divider {}
                SectionHeader {
                    text: qsTr("Interactions")
                    FIconButton {
                        iconName: "plus"
                        tip: qsTr("Add a described transition to another screen")
                        onClicked: transitionPicker.popup()
                        ScreenPickerMenu {
                            id: transitionPicker
                            onPicked: (to) => Ui.interactionDialog.openNew(inspector.screenId, "", to)
                        }
                    }
                }
                Repeater {
                    model: (Doc.revision < 0 ? undefined : inspector.screenId ? Doc.linksFrom(inspector.screenId) : [])
                    delegate: LinkRow {
                        required property var modelData
                        link: modelData
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: (Doc.revision < 0 ? undefined : inspector.screenId && Doc.linksFrom(inspector.screenId).length === 0)
                    text: qsTr("Nothing leads away from this screen yet. Add hotspots, or drag its purple handle onto another screen.")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textTertiary
                }

                Divider {}
                SectionHeader { text: qsTr("Reached from") }
                Repeater {
                    model: (Doc.revision < 0 ? undefined : inspector.screenId ? Doc.linksTo(inspector.screenId) : [])
                    delegate: LinkRow {
                        required property var modelData
                        link: modelData
                        incoming: true
                    }
                }
                Text {
                    visible: (Doc.revision < 0 ? undefined : inspector.screenId && Doc.linksTo(inspector.screenId).length === 0)
                    text: inspector.s.isStart ? qsTr("This is where the flow starts.") : qsTr("No screen leads here.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textTertiary
                }

                Divider {}
                SectionHeader { text: qsTr("Notes") }
                FTextArea {
                    Layout.fillWidth: true
                    value: inspector.s.notes || ""
                    placeholderText: qsTr("Anything worth knowing about this screen")
                    onCommitted: (text) => Doc.setScreenNotes(inspector.screenId, text)
                }
                FButton {
                    Layout.topMargin: 8
                    variant: "danger"
                    iconName: "trash"
                    text: qsTr("Delete screen")
                    onClicked: Doc.deleteScreen(inspector.screenId)
                }
            }

            // ---------------------------------------------------------- interaction
            ColumnLayout {
                visible: !!inspector.l.id
                Layout.fillWidth: true
                spacing: 6

                SectionHeader {
                    text: qsTr("Interaction")
                    Rectangle {
                        width: kind.implicitWidth + 12
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        color: inspector.l.isHotspotLink ? Theme.accentSoft : Theme.transitionSoft
                        Text {
                            id: kind
                            anchors.centerIn: parent
                            text: inspector.l.isHotspotLink ? qsTr("Hotspot click") : qsTr("Transition")
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: inspector.l.isHotspotLink ? Theme.accent : Theme.transition
                        }
                    }
                }
                FieldLabel { text: qsTr("From") }
                ListRow {
                    Layout.fillWidth: true
                    implicitHeight: Theme.controlHeight
                    color: hovered ? Theme.fieldHover : Theme.field
                    onClicked: Ui.selectScreen(inspector.l.from)
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: inspector.l.fromName + (inspector.l.hotspotName ? "  ·  " + inspector.l.hotspotName : "")
                        elide: Text.ElideRight
                        color: Theme.text
                    }
                }
                FieldLabel { text: qsTr("Goes to") }
                FComboBox {
                    Layout.fillWidth: true
                    model: inspector.screens
                    textRole: "name"
                    valueRole: "id"
                    currentIndex: inspector.indexOfScreen(inspector.l.to)
                    onActivated: Doc.setLinkTarget(inspector.linkId, currentValue)
                }
                FieldLabel { text: inspector.l.isHotspotLink ? qsTr("Note (optional)") : qsTr("What does the user do?") }
                FTextArea {
                    Layout.fillWidth: true
                    value: inspector.l.message || ""
                    placeholderText: inspector.l.isHotspotLink ? qsTr("e.g. only when the form is valid") : qsTr("e.g. user types command help")
                    onCommitted: (text) => Doc.setLinkMessage(inspector.linkId, text)
                }
                FButton {
                    Layout.topMargin: 8
                    variant: "danger"
                    iconName: "trash"
                    text: qsTr("Delete interaction")
                    onClicked: Doc.deleteLink(inspector.linkId)
                }
            }
        }
    }
}
