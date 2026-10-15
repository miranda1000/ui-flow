import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// "Edit screen": draw, move and resize the hotspots (clickable areas) of one screen.
Item {
    id: editor
    readonly property string screenId: Ui.editScreen
    readonly property var s: (Doc.revision < 0 ? undefined : Doc.screen(screenId))
    readonly property var hotspots: (Doc.revision < 0 ? undefined : Doc.hotspots(screenId))
    property string selected: Ui.editHotspot
    readonly property var sel: {
        for (let i = 0; i < hotspots.length; ++i)
            if (hotspots[i].id === selected)
                return hotspots[i]
        return null
    }
    readonly property real imgW: s.imageWidth || 1
    readonly property real imgH: s.imageHeight || 1

    // View transform (image pixels -> view pixels)
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property bool userZoomed: false

    function clampZoom(z) { return Math.max(0.05, Math.min(16, z)) }
    function toImage(px, py) { return Qt.point((px - panX) / zoom, (py - panY) / zoom) }
    function fit() {
        if (view.width <= 0 || view.height <= 0)
            return
        const m = 56
        zoom = clampZoom(Math.min(2, (view.width - 2 * m) / imgW, (view.height - 2 * m) / imgH))
        panX = (view.width - imgW * zoom) / 2
        panY = (view.height - imgH * zoom) / 2
        userZoomed = false
    }
    function zoomAt(f, px, py) {
        const nz = clampZoom(zoom * f)
        const p = toImage(px, py)
        zoom = nz
        panX = px - p.x * nz
        panY = py - p.y * nz
        userZoomed = true
    }
    function setZoom(z) { zoomAt(z / zoom, view.width / 2, view.height / 2) }
    function zoomIn() { zoomAt(1.25, view.width / 2, view.height / 2) }
    function zoomOut() { zoomAt(0.8, view.width / 2, view.height / 2) }
    function select(id) {
        selected = id || ""
        Ui.editHotspot = selected
    }
    function focusName() { Qt.callLater(() => nameField.forceActiveFocus()) }
    // Back to the flow. Moving the focus first commits a text field being edited.
    function close() {
        mouse.mode = ""
        view.forceActiveFocus()
        Ui.closeEditor()
    }
    function addCentered() {
        const w = Math.round(imgW * 0.3), h = Math.round(Math.max(24, imgH * 0.06))
        select(Doc.addHotspot(screenId, (imgW - w) / 2, (imgH - h) / 2, w, h))
        focusName()
    }

    // Esc leaves the editor from anywhere in it, also while a text field has the focus.
    Shortcut {
        sequences: ["Esc"]
        enabled: Ui.view === "edit" && !(Ui.main && Ui.main.modalOpen)
                 && !linkPicker.visible && !hotspotMenu.visible && !hotspotTarget.visible && !screenTarget.visible
        onActivated: editor.close()
    }

    Component.onCompleted: {
        Ui.editor = editor
        Qt.callLater(fit)
        view.forceActiveFocus()
    }
    Component.onDestruction: if (Ui.editor === editor) Ui.editor = null

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- hotspot list
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.leftPanelWidth
            color: Theme.panel

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                SectionHeader {
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    Layout.topMargin: 4
                    text: qsTr("Hotspots") + (editor.hotspots.length ? "  " + editor.hotspots.length : "")
                    FIconButton {
                        iconName: "plus"
                        tip: qsTr("Add a hotspot (or drag on the image)")
                        onClicked: editor.addCentered()
                    }
                }
                ListView {
                    id: hsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: editor.hotspots
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ListRow {
                        id: hrow
                        required property var modelData
                        width: ListView.view.width - 16
                        x: 8
                        implicitHeight: 44
                        selected: editor.selected === modelData.id
                        onClicked: {
                            editor.select(modelData.id)
                            view.forceActiveFocus()
                        }
                        onDoubleClicked: {
                            editor.select(modelData.id)
                            editor.focusName()
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10
                            Icon {
                                name: "hotspot"
                                color: hrow.modelData.links.length ? Theme.accent : Theme.warning
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: hrow.modelData.name || qsTr("Unnamed")
                                    font.weight: Font.Medium
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: hrow.modelData.links.length === 0 ? qsTr("Not linked")
                                          : hrow.modelData.links.map(l => "→ " + l.toName).join(", ")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: hrow.modelData.links.length ? Theme.textSecondary : Theme.warning
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.margins: Theme.padding
                    text: qsTr("Drag on the image to draw a clickable area. Drag inside an area to move it, its corners to resize; click the circle on its right to choose the screen it opens. Del removes the selected one, Esc goes back to the flow.")
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textTertiary
                }
            }
        }
        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

        // ---------------------------------------------------------- image + hotspots
        Item {
            id: view
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            property bool spaceDown: false

            onWidthChanged: if (!editor.userZoomed) Qt.callLater(editor.fit)
            onHeightChanged: if (!editor.userZoomed) Qt.callLater(editor.fit)

            Rectangle { anchors.fill: parent; color: Theme.canvas }

            Item {
                id: imageLayer
                x: editor.panX
                y: editor.panY
                width: editor.imgW
                height: editor.imgH
                scale: editor.zoom
                transformOrigin: Item.TopLeft
                readonly property real px: 1 / editor.zoom

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1 * imageLayer.px
                    anchors.bottomMargin: -4 * imageLayer.px
                    color: "#14000000"
                }
                Image {
                    anchors.fill: parent
                    source: editor.s.imageUrl || ""
                    asynchronous: true
                    mipmap: true
                    smooth: true
                }
                Repeater {
                    model: editor.hotspots
                    delegate: Item {
                        id: hd
                        required property var modelData
                        readonly property bool isSel: editor.selected === modelData.id
                        readonly property color col: modelData.links.length ? Theme.accent : Theme.warning
                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(hd.col.r, hd.col.g, hd.col.b, hd.isSel ? 0.32 : 0.22)
                            border.width: (hd.isSel ? 3 : 2) * imageLayer.px
                            border.color: hd.col
                        }
                        Rectangle {
                            visible: hd.isSel || mouse.hoverId === hd.modelData.id
                            x: 0
                            y: -(height + 3) * imageLayer.px
                            scale: imageLayer.px
                            transformOrigin: Item.TopLeft
                            width: Math.min(nameTag.implicitWidth + 10, Math.max(40, hd.width / imageLayer.px))
                            height: 18
                            radius: 3
                            color: hd.col
                            Text {
                                id: nameTag
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 10)
                                text: hd.modelData.name
                                elide: Text.ElideRight
                                color: "white"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
                // rubber band while drawing a new hotspot
                Rectangle {
                    visible: mouse.mode === "create"
                    x: Math.min(mouse.start.x, mouse.cur.x)
                    y: Math.min(mouse.start.y, mouse.cur.y)
                    width: Math.abs(mouse.cur.x - mouse.start.x)
                    height: Math.abs(mouse.cur.y - mouse.start.y)
                    color: Qt.rgba(0.05, 0.6, 1, 0.22)
                    border.width: 2 * imageLayer.px
                    border.color: Theme.accent
                }
            }

            // Link circle on the middle of each hotspot's right edge (as screens have on the
            // canvas): click it to pick the screen the hotspot opens. Constant size.
            Repeater {
                model: editor.hotspots
                delegate: Rectangle {
                    required property var modelData
                    readonly property point c: mouse.linkPoint(modelData)
                    readonly property bool active: mouse.hoverLink === modelData.id
                    readonly property bool linked: modelData.links.length > 0
                    x: c.x - width / 2
                    y: c.y - height / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: active ? Theme.accent : "white"
                    border.width: 2
                    border.color: linked ? Theme.accent : Theme.warning
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: 2
                        visible: parent.linked && !parent.active
                        color: Theme.accent
                    }
                }
            }

            // Resize handles of the selection, constant size in view pixels
            Repeater {
                model: editor.sel ? 8 : 0
                delegate: Rectangle {
                    required property int index
                    readonly property point p: mouse.handlePoint(index)
                    x: p.x - width / 2
                    y: p.y - height / 2
                    width: 8
                    height: 8
                    color: "white"
                    border.width: 1
                    border.color: Theme.accent
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                hoverEnabled: true
                property string mode: ""        // pan | create | move | resize
                property int handle: -1
                property point start
                property point cur
                property point last
                property var orig: null
                property bool changed: false
                property int hoverCursor: Qt.ArrowCursor
                property string hoverId
                property string hoverLink
                onExited: {
                    hoverId = ""
                    hoverLink = ""
                }

                // Link circle: just outside the middle of the right edge, so it does not sit
                // on the resize handle of the selection (view pixels).
                function linkPoint(h) {
                    return Qt.point(editor.panX + (h.x + h.w) * editor.zoom + 14, editor.panY + (h.y + h.h / 2) * editor.zoom)
                }
                function linkAt(x, y) {
                    for (let i = editor.hotspots.length - 1; i >= 0; --i) {
                        const p = linkPoint(editor.hotspots[i])
                        if (Math.hypot(p.x - x, p.y - y) <= 9)
                            return editor.hotspots[i].id
                    }
                    return ""
                }

                // handles: 0 TL, 1 T, 2 TR, 3 R, 4 BR, 5 B, 6 BL, 7 L (view pixels)
                function handlePoint(i) {
                    const h = editor.sel
                    if (!h)
                        return Qt.point(-100, -100)
                    const x0 = editor.panX + h.x * editor.zoom, y0 = editor.panY + h.y * editor.zoom
                    const x1 = x0 + h.w * editor.zoom, y1 = y0 + h.h * editor.zoom
                    const xm = (x0 + x1) / 2, ym = (y0 + y1) / 2
                    return [Qt.point(x0, y0), Qt.point(xm, y0), Qt.point(x1, y0), Qt.point(x1, ym),
                            Qt.point(x1, y1), Qt.point(xm, y1), Qt.point(x0, y1), Qt.point(x0, ym)][i]
                }
                function handleAt(x, y) {
                    if (!editor.sel)
                        return -1
                    for (let i = 0; i < 8; ++i) {
                        const p = handlePoint(i)
                        if (Math.abs(p.x - x) <= 6 && Math.abs(p.y - y) <= 6)
                            return i
                    }
                    return -1
                }
                function insideImage(p) { return p.x >= 0 && p.y >= 0 && p.x <= editor.imgW && p.y <= editor.imgH }
                function updateHoverCursor(x, y) {
                    hoverLink = linkAt(x, y)
                    if (hoverLink) {
                        hoverCursor = Qt.PointingHandCursor
                        return
                    }
                    const hdl = handleAt(x, y)
                    if (hdl >= 0) {
                        hoverCursor = [Qt.SizeFDiagCursor, Qt.SizeVerCursor, Qt.SizeBDiagCursor, Qt.SizeHorCursor][hdl % 4]
                        return
                    }
                    const p = editor.toImage(x, y)
                    hoverId = Doc.hotspotAt(editor.screenId, p.x, p.y)
                    hoverCursor = hoverId ? Qt.SizeAllCursor : insideImage(p) ? Qt.CrossCursor : Qt.ArrowCursor
                }
                cursorShape: mode === "pan" ? Qt.ClosedHandCursor
                           : view.spaceDown ? Qt.OpenHandCursor
                           : hoverCursor

                onPressed: (m) => {
                    view.forceActiveFocus()
                    last = Qt.point(m.x, m.y)
                    changed = false
                    if (m.button === Qt.MiddleButton || view.spaceDown) {
                        mode = "pan"
                        return
                    }
                    const p = editor.toImage(m.x, m.y)
                    if (m.button === Qt.RightButton) {
                        const hid = Doc.hotspotAt(editor.screenId, p.x, p.y)
                        if (hid) {
                            editor.select(hid)
                            hotspotMenu.popup()
                        } else {
                            mode = "pan"
                        }
                        return
                    }
                    const lnk = linkAt(m.x, m.y)
                    if (lnk) {
                        editor.select(lnk)
                        linkPicker.popup()
                        return
                    }
                    const hdl = handleAt(m.x, m.y)
                    if (hdl >= 0) {
                        mode = "resize"
                        handle = hdl
                        orig = editor.sel
                        start = p
                        return
                    }
                    const hid = Doc.hotspotAt(editor.screenId, p.x, p.y)
                    if (hid) {
                        editor.select(hid)
                        mode = "move"
                        orig = editor.sel
                        start = p
                        return
                    }
                    if (insideImage(p)) {
                        editor.select("")
                        mode = "create"
                        start = Qt.point(Math.round(p.x), Math.round(p.y))
                        cur = start
                        return
                    }
                    editor.select("")
                    mode = "pan"
                }
                onPositionChanged: (m) => {
                    if (!pressed) {
                        updateHoverCursor(m.x, m.y)
                        return
                    }
                    const p = editor.toImage(m.x, m.y)
                    if (mode === "pan") {
                        editor.panX += m.x - last.x
                        editor.panY += m.y - last.y
                        editor.userZoomed = true
                    } else if (mode === "create") {
                        cur = Qt.point(Math.round(Math.max(0, Math.min(editor.imgW, p.x))),
                                       Math.round(Math.max(0, Math.min(editor.imgH, p.y))))
                    } else if (mode === "move" || mode === "resize") {
                        if (!changed) {
                            if (Math.hypot(p.x - start.x, p.y - start.y) * editor.zoom < 2)
                                return
                            changed = true
                            Doc.beginChange()
                        }
                        const dx = p.x - start.x, dy = p.y - start.y
                        let x0 = orig.x, y0 = orig.y, x1 = orig.x + orig.w, y1 = orig.y + orig.h
                        if (mode === "move") {
                            x0 += dx; x1 += dx; y0 += dy; y1 += dy
                        } else {
                            if (handle === 0 || handle === 6 || handle === 7) x0 += dx
                            if (handle === 2 || handle === 3 || handle === 4) x1 += dx
                            if (handle === 0 || handle === 1 || handle === 2) y0 += dy
                            if (handle === 4 || handle === 5 || handle === 6) y1 += dy
                        }
                        Doc.setHotspotRect(editor.screenId, editor.selected, Math.min(x0, x1), Math.min(y0, y1),
                                            Math.max(1, Math.abs(x1 - x0)), Math.max(1, Math.abs(y1 - y0)))
                    }
                    last = Qt.point(m.x, m.y)
                }
                onReleased: (m) => {
                    if (mode === "create") {
                        const w = Math.abs(cur.x - start.x), h = Math.abs(cur.y - start.y)
                        if (w * editor.zoom >= 6 && h * editor.zoom >= 6) {
                            editor.select(Doc.addHotspot(editor.screenId, Math.min(start.x, cur.x), Math.min(start.y, cur.y), w, h))
                        }
                    }
                    mode = ""
                    updateHoverCursor(m.x, m.y)
                }
                onDoubleClicked: (m) => {
                    const p = editor.toImage(m.x, m.y)
                    const hid = Doc.hotspotAt(editor.screenId, p.x, p.y)
                    if (hid) {
                        editor.select(hid)
                        editor.focusName()
                    }
                }
            }

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
                        editor.zoomAt(Math.pow(1.0018, d), pos.x, pos.y)
                    } else {
                        let dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 2
                        let dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
                        if ((event.modifiers & Qt.ShiftModifier) && dx === 0) {
                            dx = dy
                            dy = 0
                        }
                        editor.panX += dx
                        editor.panY += dy
                        editor.userZoomed = true
                    }
                }
            }

            // First-use hint
            Rectangle {
                visible: editor.hotspots.length === 0 && mouse.mode === ""
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                width: firstHint.implicitWidth + 28
                height: 32
                radius: 16
                color: Theme.dark
                Text {
                    id: firstHint
                    anchors.centerIn: parent
                    text: qsTr("Drag on the image to mark something the user can click")
                    color: "white"
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            DropArea {
                id: replaceDrop
                anchors.fill: parent
                onEntered: (drag) => drag.accepted = drag.hasUrls
                onDropped: (drop) => {
                    Doc.replaceImage(editor.screenId, drop.urls[0])
                    drop.accept()
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                visible: replaceDrop.containsDrag
                color: "transparent"
                radius: 8
                border.width: 2
                border.color: Theme.accent
                Rectangle {
                    anchors.centerIn: parent
                    width: replaceText.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: Theme.accent
                    Text {
                        id: replaceText
                        anchors.centerIn: parent
                        text: qsTr("Drop to replace this screen's image")
                        color: "white"
                    }
                }
            }

            Keys.onPressed: (e) => {
                const shift = e.modifiers & Qt.ShiftModifier
                if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
                    spaceDown = true
                } else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && editor.sel) {
                    Doc.deleteHotspot(editor.screenId, editor.selected)
                    editor.select("")
                } else if (e.key === Qt.Key_Escape) {
                    editor.close()
                } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && editor.sel) {
                    editor.focusName()
                } else if (e.key === Qt.Key_Exclam || (e.key === Qt.Key_1 && shift) || e.key === Qt.Key_F) {
                    editor.fit()
                } else if (e.key === Qt.Key_ParenRight || (e.key === Qt.Key_0 && shift)) {
                    editor.setZoom(1)
                } else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) {
                    editor.zoomIn()
                } else if (e.key === Qt.Key_Minus) {
                    editor.zoomOut()
                } else if (editor.sel && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(e.key) >= 0) {
                    const step = shift ? 10 : 1
                    const h = editor.sel
                    if (!e.isAutoRepeat)
                        Doc.beginChange()
                    Doc.setHotspotRect(editor.screenId, h.id,
                                        h.x + (e.key === Qt.Key_Left ? -step : e.key === Qt.Key_Right ? step : 0),
                                        h.y + (e.key === Qt.Key_Up ? -step : e.key === Qt.Key_Down ? step : 0), h.w, h.h)
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

            ScreenPickerMenu {
                id: linkPicker
                onPicked: (to) => Doc.addLink(editor.screenId, editor.selected, to, "")
            }

            FMenu {
                id: hotspotMenu
                FMenuItem { text: qsTr("Rename"); shortcutText: "Enter"; onTriggered: editor.focusName() }
                FMenuSeparator {}
                FMenuItem {
                    text: qsTr("Delete")
                    shortcutText: "Del"
                    danger: true
                    onTriggered: {
                        Doc.deleteHotspot(editor.screenId, editor.selected)
                        editor.select("")
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

        // ---------------------------------------------------------- properties
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.rightPanelWidth
            color: Theme.panel

            Flickable {
                anchors.fill: parent
                contentHeight: props.implicitHeight + 32
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: props
                    x: Theme.padding
                    y: 4
                    width: parent.width - 2 * Theme.padding
                    spacing: 6

                    // --- selected hotspot
                    ColumnLayout {
                        visible: !!editor.sel
                        Layout.fillWidth: true
                        spacing: 6

                        SectionHeader {
                            text: qsTr("Hotspot")
                            FIconButton {
                                iconName: "trash"
                                tip: qsTr("Delete hotspot (Del)")
                                onClicked: {
                                    Doc.deleteHotspot(editor.screenId, editor.selected)
                                    editor.select("")
                                }
                            }
                        }
                        Text { text: qsTr("Name"); font.pixelSize: Theme.fontSizeSmall; color: Theme.textSecondary }
                        FTextField {
                            id: nameField
                            Layout.fillWidth: true
                            selectOnFocus: true
                            value: editor.sel ? editor.sel.name : ""
                            placeholderText: qsTr("e.g. Sign in button")
                            onCommitted: (text) => Doc.setHotspotName(editor.screenId, editor.selected, text)
                            onAccepted: view.forceActiveFocus()
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            columns: 4
                            columnSpacing: 6
                            rowSpacing: 6
                            Repeater {
                                model: ["x", "y", "w", "h"]
                                delegate: FTextField {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 40
                                    leftPadding: 22
                                    value: editor.sel ? String(Math.round(editor.sel[modelData])) : ""
                                    validator: IntValidator { bottom: 0; top: 100000 }
                                    onCommitted: (text) => {
                                        const h = editor.sel
                                        if (!h)
                                            return
                                        const r = { x: h.x, y: h.y, w: h.w, h: h.h }
                                        r[modelData] = parseInt(text) || 0
                                        Doc.beginChange()
                                        Doc.setHotspotRect(editor.screenId, h.id, r.x, r.y, r.w, r.h)
                                    }
                                    Text {
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.toUpperCase()
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.textTertiary
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; implicitHeight: 1; color: Theme.border; Layout.leftMargin: -Theme.padding; Layout.rightMargin: -Theme.padding }
                        SectionHeader {
                            text: qsTr("Opens")
                            FIconButton {
                                iconName: "plus"
                                tip: qsTr("Link this hotspot to a screen")
                                onClicked: hotspotTarget.popup()
                                ScreenPickerMenu {
                                    id: hotspotTarget
                                    onPicked: (to) => Doc.addLink(editor.screenId, editor.selected, to, "")
                                }
                            }
                        }
                        Repeater {
                            model: editor.sel ? editor.sel.links : []
                            delegate: ColumnLayout {
                                id: lrow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Icon { name: "arrow-right"; color: Theme.accent }
                                    Text {
                                        Layout.fillWidth: true
                                        text: lrow.modelData.toName
                                        font.weight: Font.Medium
                                        color: Theme.text
                                        elide: Text.ElideRight
                                    }
                                    FIconButton {
                                        iconName: "edit"
                                        size: 24
                                        tip: qsTr("Edit that screen")
                                        onClicked: Ui.openEditor(lrow.modelData.to, "")
                                    }
                                    FIconButton {
                                        iconName: "trash"
                                        size: 24
                                        tip: qsTr("Remove link")
                                        onClicked: Doc.deleteLink(lrow.modelData.id)
                                    }
                                }
                                FTextField {
                                    Layout.fillWidth: true
                                    value: lrow.modelData.message
                                    placeholderText: qsTr("Note (optional), e.g. when logged in")
                                    onCommitted: (text) => Doc.setLinkMessage(lrow.modelData.id, text)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: editor.sel && editor.sel.links.length === 0
                            text: qsTr("Not linked yet. Pick the screen it opens with +, or drag this hotspot onto a screen in the flow view.")
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.warning
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: editor.sel && editor.sel.links.length > 1
                            text: qsTr("With several links the player asks which one to follow; use the notes to tell them apart.")
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textTertiary
                        }
                    }

                    // --- the screen itself
                    ColumnLayout {
                        visible: !editor.sel
                        Layout.fillWidth: true
                        spacing: 6

                        SectionHeader { text: qsTr("Screen") }
                        FTextField {
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            value: editor.s.name || ""
                            placeholderText: qsTr("Screen name")
                            onCommitted: (text) => Doc.setScreenName(editor.screenId, text)
                        }
                        Text {
                            text: editor.s.imageWidth + " × " + editor.s.imageHeight + " px"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textTertiary
                        }
                        FSwitch {
                            Layout.fillWidth: true
                            text: qsTr("Start screen")
                            checked: !!editor.s.isStart
                            onToggled: {
                                if (checked)
                                    Doc.setStartScreen(editor.screenId)
                                checked = Qt.binding(() => !!editor.s.isStart)
                            }
                        }
                        FButton {
                            Layout.fillWidth: true
                            iconName: "image"
                            text: qsTr("Replace image…")
                            tip: qsTr("Hotspots keep their relative position. You can also drop an image here.")
                            onClicked: Ui.main.replaceImage(editor.screenId)
                        }

                        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; implicitHeight: 1; color: Theme.border; Layout.leftMargin: -Theme.padding; Layout.rightMargin: -Theme.padding }
                        SectionHeader {
                            text: qsTr("Transitions")
                            FIconButton {
                                iconName: "plus"
                                tip: qsTr("Add a described transition (not tied to a hotspot)")
                                onClicked: screenTarget.popup()
                                ScreenPickerMenu {
                                    id: screenTarget
                                    onPicked: (to) => Ui.interactionDialog.openNew(editor.screenId, "", to)
                                }
                            }
                        }
                        Repeater {
                            model: (Doc.revision < 0 ? undefined : Doc.linksFrom(editor.screenId, true))
                            delegate: ListRow {
                                id: trow
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 42
                                onDoubleClicked: Ui.interactionDialog.openEdit(modelData.id)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 8
                                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: Theme.transition }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text { Layout.fillWidth: true; text: trow.modelData.label; elide: Text.ElideRight; color: Theme.text }
                                        Text { Layout.fillWidth: true; text: "→ " + trow.modelData.toName; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeSmall; color: Theme.textSecondary }
                                    }
                                    FIconButton {
                                        visible: trow.hovered
                                        iconName: "trash"
                                        size: 24
                                        onClicked: Doc.deleteLink(trow.modelData.id)
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Transitions are things the user does without clicking a specific area, e.g. “user types command help” or “waits 3 seconds”.")
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textTertiary
                        }

                        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; implicitHeight: 1; color: Theme.border; Layout.leftMargin: -Theme.padding; Layout.rightMargin: -Theme.padding }
                        SectionHeader { text: qsTr("Notes") }
                        FTextArea {
                            Layout.fillWidth: true
                            value: editor.s.notes || ""
                            placeholderText: qsTr("Anything worth knowing about this screen")
                            onCommitted: (text) => Doc.setScreenNotes(editor.screenId, text)
                        }
                    }
                }
            }
        }
    }
}
