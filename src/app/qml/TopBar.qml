import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: bar
    implicitHeight: Theme.topBarHeight
    color: Theme.panel

    readonly property var zoomTarget: Ui.zoomTarget
    readonly property string saveState: !Doc.filePath ? qsTr("Not saved yet")
                                        : Doc.dirty ? (Doc.autosave ? qsTr("Saving…") : qsTr("Unsaved changes"))
                                        : qsTr("Saved")

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 4

        // App menu (logo + chevron), Figma style.
        AbstractButton {
            id: menuButton
            implicitWidth: 52
            implicitHeight: 34
            hoverEnabled: true
            onClicked: mainMenu.popup(menuButton, 0, menuButton.height + 6)
            background: Rectangle {
                radius: Theme.radius
                color: menuButton.down || mainMenu.visible ? Theme.pressed : menuButton.hovered ? Theme.hover : "transparent"
            }
            contentItem: Row {
                spacing: 4
                leftPadding: 6
                Image {
                    source: "icons/app.svg"
                    sourceSize: Qt.size(22, 22)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon {
                    name: "chevron-down"
                    width: 12
                    height: 12
                    sourceSize: Qt.size(12, 12)
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle { implicitWidth: 1; implicitHeight: 20; color: Theme.border; Layout.leftMargin: 4; Layout.rightMargin: 8 }

        // Breadcrumb
        FIconButton {
            visible: Ui.view === "edit"
            iconName: "back"
            tip: qsTr("Back to the flow (Esc)")
            onClicked: Ui.closeEditor()
        }
        Text {
            text: Doc.appName
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Ui.view === "edit" ? Font.Normal : Font.DemiBold
            color: Ui.view === "edit" ? Theme.textSecondary : Theme.text
            elide: Text.ElideRight
            Layout.maximumWidth: 260
            MouseArea {
                anchors.fill: parent
                enabled: Ui.view === "edit"
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Ui.closeEditor()
            }
        }
        Text {
            visible: Ui.view === "edit"
            text: "/"
            color: Theme.textTertiary
            font.pixelSize: Theme.fontSizeLarge
        }
        Text {
            visible: Ui.view === "edit"
            text: (Doc.revision < 0 ? undefined : Doc.screen(Ui.editScreen).displayName || "")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
            Layout.maximumWidth: 260
        }
        Text {
            Layout.leftMargin: 10
            text: bar.saveState
            font.pixelSize: Theme.fontSizeSmall
            color: Doc.dirty && !Doc.autosave ? Theme.warning : Theme.textTertiary
            FToolTip {
                visible: saveHover.hovered && !!Doc.filePath
                text: Doc.filePath
            }
            HoverHandler { id: saveHover }
        }

        Item { Layout.fillWidth: true }

        FIconButton {
            iconName: "undo"
            enabled: Doc.canUndo
            tip: qsTr("Undo (Ctrl+Z)")
            onClicked: Doc.undo()
        }
        FIconButton {
            iconName: "redo"
            enabled: Doc.canRedo
            tip: qsTr("Redo (Ctrl+Shift+Z)")
            onClicked: Doc.redo()
        }

        Rectangle { implicitWidth: 1; implicitHeight: 20; color: Theme.border; Layout.leftMargin: 6; Layout.rightMargin: 6 }

        AbstractButton {
            id: zoomButton
            implicitWidth: 64
            implicitHeight: Theme.controlHeight
            hoverEnabled: true
            enabled: !!bar.zoomTarget
            onClicked: zoomMenu.popup(zoomButton, zoomButton.width - zoomMenu.width, zoomButton.height + 6)
            background: Rectangle {
                radius: Theme.radius
                color: zoomButton.down || zoomMenu.visible ? Theme.pressed : zoomButton.hovered ? Theme.hover : "transparent"
            }
            contentItem: Row {
                spacing: 2
                leftPadding: 8
                Text {
                    text: bar.zoomTarget ? Math.round(bar.zoomTarget.zoom * 100) + "%" : ""
                    font.pixelSize: Theme.fontSize
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon {
                    name: "chevron-down"
                    width: 12
                    height: 12
                    sourceSize: Qt.size(12, 12)
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        FButton {
            Layout.leftMargin: 6
            variant: "primary"
            iconName: "play"
            text: qsTr("Play")
            enabled: Doc.screenCount > 0
            tip: Ui.view === "edit" ? qsTr("Play from this screen (F5 from the start)") : qsTr("Play from the start screen (F5)")
            onClicked: Ui.play(Ui.view === "edit" ? Ui.editScreen : Doc.startScreen)
        }
        FIconButton {
            Layout.leftMargin: 4
            iconName: "github"
            tip: qsTr("Help and feedback on GitHub")
            onClicked: Qt.openUrlExternally(Ui.issuesUrl)
        }
    }

    FMenu {
        id: mainMenu
        FMenuItem { text: qsTr("New app…"); shortcutText: "Ctrl+N"; onTriggered: Ui.main.newApp() }
        FMenuItem { text: qsTr("Open…"); shortcutText: "Ctrl+O"; onTriggered: Ui.main.openApp() }
        FMenu {
            id: recentMenu
            title: qsTr("Open recent")
            enabled: Doc.recentFiles.length > 0
            Instantiator {
                model: Doc.recentFiles
                delegate: FMenuItem {
                    required property string modelData
                    text: modelData.replace(/^.*[\/\\]/, "")
                    onTriggered: {
                        if (Doc.dirty && Doc.filePath)
                            Doc.save()
                        Doc.openApp(modelData)
                    }
                }
                onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => recentMenu.removeItem(object)
            }
        }
        FMenuSeparator {}
        FMenuItem { text: Doc.web ? qsTr("Download") : qsTr("Save"); shortcutText: "Ctrl+S"; onTriggered: Ui.main.save() }
        FMenuItem { id: saveAsItem; text: qsTr("Save as…"); shortcutText: "Ctrl+Shift+S"; onTriggered: Ui.main.saveAs() }
        FMenuItem { text: qsTr("Export flow as Markdown…"); onTriggered: Ui.main.exportMarkdown() }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Add screens from images…"); onTriggered: Ui.main.addImages() }
        FMenuItem { text: qsTr("Paste image as screen"); shortcutText: "Ctrl+V"; onTriggered: Ui.main.pasteImage() }
        FMenuSeparator {}
        FMenuItem {
            id: autosaveItem
            text: qsTr("Autosave")
            checkable: true
            checked: Doc.autosave
            onTriggered: Doc.autosave = checked
        }
        FMenuItem {
            text: qsTr("Scroll wheel zooms")
            checkable: true
            checked: Doc.wheelZooms
            onTriggered: Doc.wheelZooms = checked
        }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Keyboard shortcuts"); shortcutText: "F1"; onTriggered: Ui.main.showShortcuts() }
        FMenuItem { text: qsTr("Help and feedback (GitHub)"); onTriggered: Qt.openUrlExternally(Ui.issuesUrl) }
        FMenuItem { text: qsTr("Close app"); onTriggered: Ui.main.closeApp() }
        FMenuItem { id: quitItem; text: qsTr("Quit"); shortcutText: "Ctrl+Q"; onTriggered: Ui.main.quit() }

        // Web: no recent files, no file name to choose, no autosave (saving downloads the
        // file), nothing to quit.
        Component.onCompleted: {
            if (Doc.web) {
                removeMenu(recentMenu)
                removeItem(saveAsItem)
                removeItem(autosaveItem)
                removeItem(quitItem)
            }
        }
    }

    FMenu {
        id: zoomMenu
        menuWidth: 200
        FMenuItem { text: qsTr("Zoom in"); shortcutText: "+"; onTriggered: bar.zoomTarget.zoomIn() }
        FMenuItem { text: qsTr("Zoom out"); shortcutText: "−"; onTriggered: bar.zoomTarget.zoomOut() }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Zoom to fit"); shortcutText: "Shift+1"; onTriggered: bar.zoomTarget.fit() }
        FMenuItem { text: qsTr("Zoom to 50%"); onTriggered: bar.zoomTarget.setZoom(0.5) }
        FMenuItem { text: qsTr("Zoom to 100%"); shortcutText: "Shift+0"; onTriggered: bar.zoomTarget.setZoom(1) }
        FMenuItem { text: qsTr("Zoom to 200%"); onTriggered: bar.zoomTarget.setZoom(2) }
    }
}
