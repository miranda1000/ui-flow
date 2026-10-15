pragma Singleton
import QtQuick

// Bindings that query the document re-evaluate through a dependency on Doc.revision:
//     property var s: (Doc.revision < 0 ? undefined : Doc.screen(id))
// The condition must really read `revision`: the QML compiler drops the left operand of
// a comma expression such as `(Doc.revision, Doc.screen(id))`, losing the dependency.
//
// UI state shared by all views: which view is shown, the selection, and handles to the
// main window, canvas and dialogs (registered by Main.qml).
QtObject {
    property string view: "canvas"          // "canvas" | "edit" | "play"
    property string selectedScreen
    property string selectedLink
    property string editScreen
    property string editHotspot
    property string playScreen
    property string playReturnView: "canvas"

    property var main: null                 // Main.qml (dialogs: addImages(), replaceImage(), ...)
    property var canvas: null               // CanvasView
    property var editor: null               // EditorView while open
    property var interactionDialog: null

    readonly property var zoomTarget: view === "edit" ? editor : canvas

    function selectScreen(id) { selectedLink = ""; selectedScreen = id || "" }
    function selectLink(id) { selectedScreen = ""; selectedLink = id || "" }
    function clearSelection() { selectedScreen = ""; selectedLink = "" }

    function openEditor(id, hotspotId) {
        if (!Doc.hasScreen(id))
            return
        editScreen = id
        editHotspot = hotspotId || ""
        selectScreen(id)
        view = "edit"
    }
    function closeEditor() {
        selectScreen(editScreen)
        view = "canvas"
        if (canvas)
            canvas.forceActiveFocus()
    }
    function play(id) {
        if (Doc.screenCount === 0)
            return
        if (view !== "play")
            playReturnView = view
        playScreen = Doc.hasScreen(id) ? id : Doc.startScreen
        view = "play"
    }
    function stopPlay() {
        view = playReturnView === "edit" && Doc.hasScreen(editScreen) ? "edit" : "canvas"
    }
    // Drops selections that no longer exist (after undo, delete, ...).
    function validate() {
        if (selectedScreen && !Doc.hasScreen(selectedScreen))
            selectedScreen = ""
        if (selectedLink && !Doc.hasLink(selectedLink))
            selectedLink = ""
        if (view === "edit" && !Doc.hasScreen(editScreen))
            view = "canvas"
    }
}
