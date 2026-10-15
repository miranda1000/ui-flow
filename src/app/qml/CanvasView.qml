import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

// The flow canvas: every screen at its position, arrows between them. World coordinates
// are canvasView units; `world` is scaled by `zoom` and offset by (panX, panY).
Item {
    id: canvasView
    clip: true
    focus: true
    activeFocusOnTab: true

    property real zoom: 1
    property real panX: 80
    property real panY: 80
    readonly property real minZoom: 0.05
    readonly property real maxZoom: 8
    property bool fitPending: true
    property bool spaceDown: false
    property alias world: world
    property alias screenMenu: screenMenu
    property alias linkMenu: linkMenu

    // Link being drawn (world coordinates)
    property bool linking: false
    property string linkFrom
    property string linkHotspot
    property point linkStart
    property point linkEnd
    property string linkTarget

    function clampZoom(z) { return Math.max(minZoom, Math.min(maxZoom, z)) }
    function toWorld(px, py) { return Qt.point((px - panX) / zoom, (py - panY) / zoom) }
    function zoomAt(factor, px, py) {
        const nz = clampZoom(zoom * factor)
        const w = toWorld(px, py)
        zoom = nz
        panX = px - w.x * nz
        panY = py - w.y * nz
    }
    function setZoom(z) { zoomAt(z / zoom, width / 2, height / 2) }
    function zoomIn() { zoomAt(1.25, width / 2, height / 2) }
    function zoomOut() { zoomAt(0.8, width / 2, height / 2) }
    function fit() {
        const b = Doc.bounds()
        if (b.width <= 0 || b.height <= 0) {
            zoom = 1
            panX = 80
            panY = 80
            return
        }
        const margin = 72
        const z = clampZoom(Math.min(1, (width - 2 * margin) / b.width, (height - 2 * margin - 24) / b.height))
        zoom = z
        panX = (width - b.width * z) / 2 - b.x * z
        panY = (height - b.height * z) / 2 - b.y * z + 12
    }
    function fitSoon() {
        fitPending = true
        Qt.callLater(doFit)
    }
    function doFit() {
        if (!fitPending || width <= 0 || height <= 0)
            return
        fit()
        fitPending = false
    }
    // Pans so that a screen is fully visible (centres it if it is not).
    function reveal(id) {
        const s = Doc.screen(id)
        if (!s.id)
            return
        const x0 = panX + s.x * zoom, y0 = panY + (s.y - 24 / zoom) * zoom
        const x1 = panX + (s.x + s.width) * zoom, y1 = panY + (s.y + s.height) * zoom
        if (x0 >= 0 && y0 >= 0 && x1 <= width && y1 <= height)
            return
        if (s.width * zoom > width * 0.9 || s.height * zoom > height * 0.85)
            zoom = clampZoom(Math.min(width * 0.6 / s.width, height * 0.7 / s.height))
        panX = width / 2 - (s.x + s.width / 2) * zoom
        panY = height / 2 - (s.y + s.height / 2) * zoom
    }
    function pasteAtCenter() {
        const p = mouseInside.hovered ? toWorld(mouseInside.point.position.x, mouseInside.point.position.y) : null
        if (p)
            Doc.pasteImage(p.x, p.y, true)
        else
            Doc.pasteImage(0, 0, false)
    }

    function startLink(screenId, hotspotId, worldPoint) {
        linkFrom = screenId
        linkHotspot = hotspotId
        linkStart = worldPoint
        linkEnd = worldPoint
        linkTarget = ""
        linking = true
    }
    function moveLink(worldPoint) {
        linkEnd = worldPoint
        const t = Doc.screenAt(worldPoint.x, worldPoint.y)
        linkTarget = t !== linkFrom ? t : ""
    }
    function endLink() {
        if (!linking)
            return
        linking = false
        if (!linkTarget)
            return
        if (linkHotspot)
            Ui.selectLink(Doc.addLink(linkFrom, linkHotspot, linkTarget, ""))
        else
            Ui.interactionDialog.openNew(linkFrom, "", linkTarget)
    }

    onWidthChanged: if (fitPending) Qt.callLater(doFit)
    onHeightChanged: if (fitPending) Qt.callLater(doFit)

    Rectangle {
        anchors.fill: parent
        color: Theme.canvas
    }

    // Background: pan, select links, clear the selection, context menu.
    MouseArea {
        id: bgMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        property bool panning: false
        property bool moved: false
        property point last
        cursorShape: panning ? Qt.ClosedHandCursor : canvasView.spaceDown ? Qt.OpenHandCursor : Qt.ArrowCursor

        onPressed: (m) => {
            canvasView.forceActiveFocus()
            last = Qt.point(m.x, m.y)
            moved = false
            if (m.button !== Qt.LeftButton || canvasView.spaceDown) {
                panning = true
                return
            }
            const w = canvasView.toWorld(m.x, m.y)
            const l = Doc.linkAt(w.x, w.y, 6 / canvasView.zoom)
            if (l)
                Ui.selectLink(l)
            else
                Ui.clearSelection()
        }
        onPositionChanged: (m) => {
            if (!panning)
                return
            canvasView.panX += m.x - last.x
            canvasView.panY += m.y - last.y
            if (Math.abs(m.x - last.x) + Math.abs(m.y - last.y) > 0)
                moved = true
            last = Qt.point(m.x, m.y)
        }
        onReleased: (m) => {
            panning = false
            if (m.button === Qt.RightButton && !moved) {
                const w = canvasView.toWorld(m.x, m.y)
                const l = Doc.linkAt(w.x, w.y, 6 / canvasView.zoom)
                if (l) {
                    Ui.selectLink(l)
                    linkMenu.popup()
                } else {
                    canvasMenu.worldPos = w
                    canvasMenu.popup()
                }
            }
        }
        onDoubleClicked: (m) => {
            const w = canvasView.toWorld(m.x, m.y)
            const l = Doc.linkAt(w.x, w.y, 6 / canvasView.zoom)
            if (l)
                Ui.interactionDialog.openEdit(l)
        }
    }

    HoverHandler { id: mouseInside }

    WheelHandler {
        id: wheel
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const pos = wheel.point.position
            // Wheel zooms (Figma's Ctrl+wheel too); Shift+wheel, or plain wheel with
            // "Scroll wheel zooms" off, pans.
            const shift = event.modifiers & Qt.ShiftModifier
            if ((event.modifiers & Qt.ControlModifier) || (Doc.wheelZooms && !shift)) {
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                canvasView.zoomAt(Math.pow(1.0018, d), pos.x, pos.y)
            } else {
                let dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 2
                let dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
                if ((event.modifiers & Qt.ShiftModifier) && dx === 0) {
                    dx = dy
                    dy = 0
                }
                canvasView.panX += dx
                canvasView.panY += dy
            }
        }
    }
    PinchHandler {
        target: null
        property real startZoom: 1
        onActiveChanged: if (active) startZoom = canvasView.zoom
        onActiveScaleChanged: canvasView.zoomAt(startZoom * activeScale / canvasView.zoom, centroid.position.x, centroid.position.y)
    }

    Item {
        id: world
        x: canvasView.panX
        y: canvasView.panY
        scale: canvasView.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            model: Doc.screens
            delegate: ScreenItem { canvas: canvasView }
        }
        Repeater {
            model: Doc.links
            delegate: LinkItem { canvas: canvasView }
        }

        // Link preview while dragging
        Shape {
            visible: canvasView.linking
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: canvasView.linkHotspot ? Theme.accent : Theme.transition
                strokeWidth: 2 / canvasView.zoom
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                fillColor: "transparent"
                startX: canvasView.linkStart.x
                startY: canvasView.linkStart.y
                PathLine { x: canvasView.linkEnd.x; y: canvasView.linkEnd.y }
            }
        }
        Rectangle {
            visible: canvasView.linking
            width: 8 / canvasView.zoom
            height: width
            radius: width / 2
            x: canvasView.linkEnd.x - width / 2
            y: canvasView.linkEnd.y - height / 2
            color: canvasView.linkHotspot ? Theme.accent : Theme.transition
        }
    }

    // Empty state
    Rectangle {
        visible: Doc.hasDocument && Doc.screenCount === 0
        anchors.centerIn: parent
        width: 380
        height: emptyColumn.implicitHeight + 48
        radius: Theme.radiusLarge
        color: Theme.panel
        border.width: 1
        border.color: dropArea.containsDrag ? Theme.accent : Theme.border

        Column {
            id: emptyColumn
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 10
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: Theme.accentSoft
                anchors.horizontalCenter: parent.horizontalCenter
                Icon {
                    anchors.centerIn: parent
                    name: "image"
                    color: Theme.accent
                    width: 20
                    height: 20
                    sourceSize: Qt.size(20, 20)
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Drop screenshots here")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Each image becomes a screen of your app. You can also paste one with Ctrl+V.")
                color: Theme.textSecondary
                lineHeight: 1.25
            }
            Item { width: 1; height: 4 }
            FButton {
                anchors.horizontalCenter: parent.horizontalCenter
                variant: "primary"
                iconName: "plus"
                text: qsTr("Add images…")
                onClicked: Ui.main.addImages()
            }
        }
    }

    // Hint for new users once there are screens but no links yet
    Rectangle {
        visible: Doc.screenCount > 0 && Doc.linkCount === 0 && !canvasView.linking
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: hintText.implicitWidth + 28
        height: 32
        radius: 16
        color: Theme.panel
        border.width: 1
        border.color: Theme.border
        Text {
            id: hintText
            anchors.centerIn: parent
            text: qsTr("Double-click a screen to mark its clickable areas, then drag an area onto another screen")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textSecondary
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: (drag) => drag.accepted = drag.hasUrls
        onDropped: (drop) => {
            const w = canvasView.toWorld(drop.x, drop.y)
            Doc.addImages(drop.urls, w.x, w.y, true)
            drop.accept()
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        visible: dropArea.containsDrag
        color: "transparent"
        radius: 8
        border.width: 2
        border.color: Theme.accent
    }

    Keys.onPressed: (e) => {
        const shift = e.modifiers & Qt.ShiftModifier
        const ctrl = e.modifiers & Qt.ControlModifier
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceDown = true
        } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
            if (Ui.selectedScreen)
                Doc.deleteScreen(Ui.selectedScreen)
            else if (Ui.selectedLink)
                Doc.deleteLink(Ui.selectedLink)
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (Ui.selectedScreen)
                Ui.openEditor(Ui.selectedScreen, "")
            else if (Ui.selectedLink)
                Ui.interactionDialog.openEdit(Ui.selectedLink)
        } else if (e.key === Qt.Key_Escape) {
            Ui.clearSelection()
        } else if (e.key === Qt.Key_Exclam || (e.key === Qt.Key_1 && shift) || (e.key === Qt.Key_F && !ctrl)) {
            fit()
        } else if (e.key === Qt.Key_ParenRight || (e.key === Qt.Key_0 && (shift || ctrl))) {
            setZoom(1)
        } else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) {
            zoomIn()
        } else if (e.key === Qt.Key_Minus) {
            zoomOut()
        } else if (e.key === Qt.Key_D && ctrl && Ui.selectedScreen) {
            Doc.duplicateScreen(Ui.selectedScreen)
        } else if (Ui.selectedScreen && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(e.key) >= 0) {
            const step = shift ? 10 : 1
            const s = Doc.screen(Ui.selectedScreen)
            const dx = e.key === Qt.Key_Left ? -step : e.key === Qt.Key_Right ? step : 0
            const dy = e.key === Qt.Key_Up ? -step : e.key === Qt.Key_Down ? step : 0
            if (!e.isAutoRepeat)
                Doc.beginChange()
            Doc.moveScreen(s.id, s.x + dx, s.y + dy)
        } else {
            return
        }
        e.accepted = true
    }
    Keys.onReleased: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
            spaceDown = false
            e.accepted = true
        }
    }

    // --- context menus
    FMenu {
        id: screenMenu
        property string screenId
        function popupFor(id) {
            screenId = id
            Ui.selectScreen(id)
            popup()
        }
        FMenuItem { text: qsTr("Edit hotspots"); shortcutText: "Enter"; onTriggered: Ui.openEditor(screenMenu.screenId, "") }
        FMenuItem { text: qsTr("Play from here"); shortcutText: "Shift+F5"; onTriggered: Ui.play(screenMenu.screenId) }
        FMenuItem {
            text: qsTr("Set as start screen")
            enabled: Doc.startScreen !== screenMenu.screenId
            onTriggered: Doc.setStartScreen(screenMenu.screenId)
        }
        FMenu {
            id: transitionMenu
            title: qsTr("Add transition to")
            Instantiator {
                model: (Doc.revision < 0 ? undefined : Doc.screenList())
                delegate: FMenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: Ui.interactionDialog.openNew(screenMenu.screenId, "", modelData.id)
                }
                onObjectAdded: (index, object) => transitionMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => transitionMenu.removeItem(object)
            }
        }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Duplicate"); shortcutText: "Ctrl+D"; onTriggered: Doc.duplicateScreen(screenMenu.screenId) }
        FMenuItem { text: qsTr("Replace image…"); onTriggered: Ui.main.replaceImage(screenMenu.screenId) }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Delete"); shortcutText: "Del"; danger: true; onTriggered: Doc.deleteScreen(screenMenu.screenId) }
    }
    FMenu {
        id: linkMenu
        FMenuItem { text: qsTr("Edit description…"); shortcutText: "Enter"; onTriggered: Ui.interactionDialog.openEdit(Ui.selectedLink) }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Delete"); shortcutText: "Del"; danger: true; onTriggered: Doc.deleteLink(Ui.selectedLink) }
    }
    FMenu {
        id: canvasMenu
        property point worldPos
        FMenuItem { text: qsTr("Add screens from images…"); onTriggered: Ui.main.addImages() }
        FMenuItem {
            text: qsTr("Paste image here")
            shortcutText: "Ctrl+V"
            onTriggered: Doc.pasteImage(canvasMenu.worldPos.x, canvasMenu.worldPos.y, true)
        }
        FMenuSeparator {}
        FMenuItem { text: qsTr("Zoom to fit"); shortcutText: "Shift+1"; onTriggered: canvasView.fit() }
    }
}
