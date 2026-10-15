import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: Doc.startup.width || 1440
    height: Doc.startup.height || 900
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    color: Theme.canvas
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    title: Doc.hasDocument ? (Doc.dirty && !Doc.autosave ? "• " : "") + Doc.appName + " – ui-flow" : "ui-flow"

    property bool quitting: false
    readonly property bool modalOpen: newAppDialog.visible || interactionDialog.visible || shortcutsDialog.visible
                                      || unsavedDialog.visible || errorDialog.visible

    // --- actions used from menus, panels and shortcuts
    function newApp() { newAppDialog.openFresh() }
    function openApp() { openDialog.open() }
    function save() { Doc.save() }
    function saveAs() {
        saveDialog.selectedFile = Doc.suggestedFile("json")
        saveDialog.open()
    }
    function exportMarkdown() {
        exportDialog.selectedFile = Doc.suggestedFile("md")
        exportDialog.open()
    }
    function addImages() { imagesDialog.open() }
    function replaceImage(screenId) {
        replaceDialog.screenId = screenId
        replaceDialog.open()
    }
    function pasteImage() {
        if (Ui.view === "canvas" && Ui.canvas)
            Ui.canvas.pasteAtCenter()
        else if (Ui.view === "edit")
            toast.show(qsTr("Go back to the flow to paste a new screen"))
    }
    function showShortcuts() { shortcutsDialog.open() }
    function quit() {
        quitting = true
        win.close()
    }
    function closeApp() {
        if (Doc.dirty && !(Doc.filePath && Doc.save())) {
            unsavedDialog.afterSave = "close"
            unsavedDialog.open()
            return
        }
        Doc.closeApp()
    }

    Component.onCompleted: {
        Ui.main = win
        Ui.interactionDialog = interactionDialog
        const s = Doc.startup
        if (Doc.hasDocument) {
            if (s.mode === "play")
                Ui.play(s.screen)
            else if (s.mode === "edit")
                Ui.openEditor(s.screen, "")
            if (s.select) {
                if (Doc.hasScreen(s.select))
                    Ui.selectScreen(s.select)
                else if (Doc.hasLink(s.select))
                    Ui.selectLink(s.select)
            }
        }
    }

    onClosing: (close) => {
        if (!Doc.dirty || !Doc.hasDocument)
            return
        if (Doc.filePath && Doc.save())
            return
        close.accepted = false
        unsavedDialog.afterSave = "quit"
        unsavedDialog.open()
    }

    Connections {
        target: Doc
        function onErrorOccurred(message) { errorDialog.show(message) }
        function onToast(message) { toast.show(message) }
        function onSaveAsRequested() { win.saveAs() }
        function onDocumentChanged() {
            Ui.view = "canvas"
            Ui.clearSelection()
            if (Ui.canvas)
                Ui.canvas.fitSoon()
        }
        function onRevisionChanged() { Ui.validate() }
        function onScreenAdded(id) {
            Ui.selectScreen(id)
            if (Ui.canvas)
                Ui.canvas.reveal(id)
        }
    }

    // --- layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            visible: Doc.hasDocument && Ui.view !== "play"
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Welcome {
                anchors.fill: parent
                visible: !Doc.hasDocument
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: Doc.hasDocument && Ui.view === "canvas"

                ScreensPanel {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Theme.leftPanelWidth
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }
                CanvasView {
                    id: canvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Component.onCompleted: Ui.canvas = canvas
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }
                Inspector {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Theme.rightPanelWidth
                }
            }

            Loader {
                anchors.fill: parent
                active: Doc.hasDocument && Ui.view === "edit"
                sourceComponent: EditorView {}
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: Doc.hasDocument && Ui.view === "play"
        sourceComponent: PlayerView {}
    }

    // Drops outside the canvas (welcome page, panels): images become screens.
    DropArea {
        anchors.fill: parent
        z: -1
        onDropped: (drop) => {
            if (drop.hasUrls && Ui.view !== "play")
                Doc.addImages(drop.urls, 0, 0, false)
        }
    }

    Toast { id: toast }

    // --- dialogs
    FileDialog {
        id: openDialog
        title: qsTr("Open app")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("ui-flow apps (*.json)"), qsTr("All files (*)")]
        onAccepted: {
            if (Doc.dirty && Doc.filePath)
                Doc.save()
            Doc.openApp(Doc.localPath(selectedFile))
        }
    }
    FileDialog {
        id: newFileDialog
        title: qsTr("Save the new app as")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("ui-flow apps (*.json)")]
        onAccepted: Doc.newApp(newAppDialog.appName, Doc.localPath(selectedFile))
    }
    FileDialog {
        id: saveDialog
        title: qsTr("Save app as")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("ui-flow apps (*.json)")]
        onAccepted: {
            if (Doc.saveAs(Doc.localPath(selectedFile)) && win.quitting)
                Qt.quit()
        }
        onRejected: win.quitting = false
    }
    FileDialog {
        id: exportDialog
        title: qsTr("Export flow as Markdown")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "md"
        nameFilters: [qsTr("Markdown (*.md)")]
        onAccepted: Doc.exportMarkdown(Doc.localPath(selectedFile))
    }
    FileDialog {
        id: imagesDialog
        title: qsTr("Add screens")
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.bmp *.gif *.tga *.psd)"), qsTr("All files (*)")]
        onAccepted: Doc.addImages(selectedFiles, 0, 0, false)
    }
    FileDialog {
        id: replaceDialog
        property string screenId
        title: qsTr("Replace screen image")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.bmp *.gif *.tga *.psd)"), qsTr("All files (*)")]
        onAccepted: Doc.replaceImage(screenId, selectedFile)
    }

    NewAppDialog {
        id: newAppDialog
        onAccepted: {
            if (Doc.dirty && Doc.filePath)
                Doc.save()
            newFileDialog.selectedFile = Doc.suggestedFile("json", appName)
            newFileDialog.open()
        }
    }
    InteractionDialog { id: interactionDialog }
    ShortcutsDialog { id: shortcutsDialog }

    ConfirmDialog {
        id: unsavedDialog
        property string afterSave: "quit"
        title: qsTr("Unsaved changes")
        message: qsTr("Do you want to save the changes to “%1”?").arg(Doc.appName)
        acceptText: qsTr("Save")
        discardText: qsTr("Don't save")
        onAccepted: {
            if (!Doc.filePath) {
                win.quitting = afterSave === "quit"
                win.saveAs()
            } else if (Doc.save()) {
                afterSave === "quit" ? Qt.quit() : Doc.closeApp()
            }
        }
        onDiscarded: afterSave === "quit" ? Qt.quit() : Doc.closeApp()
    }
    ConfirmDialog {
        id: errorDialog
        title: qsTr("Something went wrong")
        acceptText: qsTr("OK")
        showCancel: false
        function show(text) {
            message = text
            open()
        }
    }

    // --- global shortcuts (text fields keep their own Ctrl+Z / Ctrl+V)
    Shortcut { sequences: [StandardKey.New]; onActivated: win.newApp() }
    Shortcut { sequences: [StandardKey.Open]; onActivated: win.openApp() }
    Shortcut { sequences: [StandardKey.Save]; enabled: Doc.hasDocument; onActivated: win.save() }
    Shortcut { sequences: ["Ctrl+Shift+S"]; enabled: Doc.hasDocument; onActivated: win.saveAs() }
    Shortcut { sequences: [StandardKey.Undo]; enabled: Doc.hasDocument && Ui.view !== "play"; onActivated: Doc.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; enabled: Doc.hasDocument && Ui.view !== "play"; onActivated: Doc.redo() }
    Shortcut { sequences: [StandardKey.Paste]; enabled: Ui.view !== "play"; onActivated: win.pasteImage() }
    Shortcut { sequences: ["F5"]; enabled: Doc.hasDocument && Doc.screenCount > 0; onActivated: Ui.play(Doc.startScreen) }
    Shortcut {
        sequences: ["Shift+F5"]
        enabled: Doc.hasDocument && Doc.screenCount > 0
        onActivated: Ui.play(Ui.view === "edit" ? Ui.editScreen : Ui.selectedScreen)
    }
    Shortcut { sequences: ["F1", "Ctrl+/"]; onActivated: win.showShortcuts() }
    Shortcut { sequences: [StandardKey.Quit, "Ctrl+Q"]; onActivated: win.quit() }
}
