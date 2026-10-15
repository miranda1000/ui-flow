import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Left panel: every screen, how it is reached from the start screen, and a flow check.
Rectangle {
    id: panel
    color: Theme.panel
    readonly property var screens: (Doc.revision < 0 ? undefined : Doc.overview())
    readonly property var stats: (Doc.revision < 0 ? undefined : Doc.stats())

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SectionHeader {
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.topMargin: 4
            text: qsTr("Screens") + (panel.screens.length ? "  " + panel.screens.length : "")
            FIconButton {
                iconName: "plus"
                tip: qsTr("Add screens from images")
                onClicked: Ui.main.addImages()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: panel.screens
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: ListRow {
                id: row
                required property var modelData
                width: ListView.view.width - 16
                x: 8
                implicitHeight: 52
                selected: Ui.selectedScreen === modelData.id
                onClicked: {
                    Ui.selectScreen(modelData.id)
                    Ui.canvas.reveal(modelData.id)
                }
                onDoubleClicked: Ui.openEditor(modelData.id, "")
                onRightClicked: Ui.canvas.screenMenu.popupFor(modelData.id)

                FToolTip {
                    visible: row.hovered && row.modelData.reachable && !row.modelData.isStart
                    delay: 800
                    text: row.modelData.path
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 38
                        radius: 3
                        color: Theme.canvas
                        border.width: 1
                        border.color: row.selected ? Theme.accent : Theme.border
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: row.modelData.imageUrl
                            sourceSize: Qt.size(60, 76)
                            fillMode: Image.PreserveAspectCrop
                            horizontalAlignment: Image.AlignHCenter
                            verticalAlignment: Image.AlignTop
                            asynchronous: true
                            smooth: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: 6
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.Medium
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: row.modelData.idleHotspots > 0
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: Theme.warning
                                FToolTip {
                                    visible: idleHover.hovered
                                    text: qsTr("%n hotspot(s) without a link", "", row.modelData.idleHotspots)
                                }
                                HoverHandler { id: idleHover }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.isStart ? qsTr("Start screen")
                                  : row.modelData.reachable ? qsTr("via %1").arg(row.modelData.via)
                                  : qsTr("Not reachable from the start")
                            font.pixelSize: Theme.fontSizeSmall
                            color: row.modelData.isStart ? Theme.accent
                                   : row.modelData.reachable ? Theme.textTertiary : Theme.warning
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: qsTr("No screens yet")
                color: Theme.textTertiary
            }
        }

        // Flow check
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.padding
            Layout.topMargin: 10
            spacing: 6
            visible: panel.stats.screens > 0

            Text {
                text: qsTr("Flow check")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Repeater {
                model: [
                    { ok: panel.stats.unreachable === 0,
                      text: panel.stats.unreachable === 0 ? qsTr("Every screen can be reached")
                                                          : qsTr("%n screen(s) cannot be reached", "", panel.stats.unreachable) },
                    { ok: panel.stats.idleHotspots === 0,
                      text: panel.stats.idleHotspots === 0 ? qsTr("Every hotspot leads somewhere")
                                                           : qsTr("%n hotspot(s) lead nowhere", "", panel.stats.idleHotspots) },
                    { ok: true, neutral: true,
                      text: qsTr("%n dead end(s)", "", panel.stats.deadEnds) }
                ]
                delegate: RowLayout {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: parent.modelData.neutral ? Theme.textTertiary : parent.modelData.ok ? Theme.success : Theme.warning
                    }
                    Text {
                        text: parent.modelData.text
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
}
