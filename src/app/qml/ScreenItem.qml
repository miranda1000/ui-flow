import QtQuick

// One screen on the canvas (world coordinates). Labels and handles are counter-scaled so
// they keep the same size on screen at any zoom.
Item {
    id: item
    required property var canvas
    required property string screenId
    required property string name
    required property string imageUrl
    required property real posX
    required property real posY
    required property real screenWidth
    required property real screenHeight
    required property bool isStart
    required property var hotspots

    readonly property real px: 1 / canvas.zoom   // one screen pixel, in world units
    readonly property bool selected: Ui.selectedScreen === screenId
    readonly property bool hovered: hover.hovered || titleMouse.containsMouse
    readonly property bool isTarget: canvas.linking && canvas.linkTarget === screenId
    readonly property bool showHotspots: selected || hovered || canvas.linking

    // Moving (shared by the title and the body)
    property point grab
    property point pressWorld
    property bool moved: false
    function pressAt(w) {
        canvas.forceActiveFocus()
        Ui.selectScreen(screenId)
        grab = Qt.point(w.x - posX, w.y - posY)
        pressWorld = w
        moved = false
    }
    function dragTo(w) {
        if (!moved) {
            if (Math.hypot(w.x - pressWorld.x, w.y - pressWorld.y) * canvas.zoom < 3)
                return
            moved = true
            Doc.beginChange()
        }
        Doc.moveScreen(screenId, Math.round(w.x - grab.x), Math.round(w.y - grab.y))
    }

    x: posX
    y: posY
    width: screenWidth
    height: screenHeight

    HoverHandler { id: hover }

    // Soft shadow + image
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1 * item.px
        anchors.bottomMargin: -3 * item.px
        anchors.leftMargin: -1 * item.px
        anchors.rightMargin: -1 * item.px
        color: "#12000000"
        radius: 3 * item.px
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.panel
    }
    Image {
        anchors.fill: parent
        source: item.imageUrl
        asynchronous: true
        mipmap: true
        smooth: true
        sourceSize.width: Math.min(4096, Math.round(item.screenWidth * 2))
        fillMode: Image.Stretch
    }
    Rectangle {
        readonly property real bw: (item.selected || item.isTarget ? 2 : 1) * item.px
        anchors.fill: parent
        anchors.margins: -bw
        color: "transparent"
        border.width: bw
        border.color: item.selected || item.isTarget || item.hovered ? Theme.accent : "#1A000000"
    }

    // Title above the frame
    Item {
        id: title
        width: item.width / item.px
        height: 22
        x: 0
        y: -(height + 2) * item.px
        scale: item.px
        transformOrigin: Item.TopLeft

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
                id: badge
                visible: item.isStart
                width: badgeRow.implicitWidth + 10
                height: 16
                radius: 3
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 3
                    Icon {
                        name: "play"
                        width: 9
                        height: 9
                        sourceSize: Qt.size(9, 9)
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: qsTr("Start")
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Text {
                text: item.name
                width: Math.min(implicitWidth, title.width - (badge.visible ? badge.width + 6 : 0))
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                font.weight: item.selected ? Font.DemiBold : Font.Medium
                color: item.selected ? Theme.accent : Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: titleMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            onPressed: (m) => {
                if (canvas.spaceDown) {
                    m.accepted = false
                    return
                }
                item.pressAt(mapToItem(canvas.world, m.x, m.y))
            }
            onPositionChanged: (m) => { if (pressed && (m.buttons & Qt.LeftButton)) item.dragTo(mapToItem(canvas.world, m.x, m.y)) }
            onReleased: (m) => { if (m.button === Qt.RightButton) canvas.screenMenu.popupFor(item.screenId) }
            onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) Ui.openEditor(item.screenId, "") }
        }
    }

    // Body: select, move, open the editor, context menu
    MouseArea {
        id: body
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool onLink: false
        onPressed: (m) => {
            if (canvas.spaceDown) {
                m.accepted = false
                return
            }
            const w = mapToItem(canvas.world, m.x, m.y)
            const l = Doc.linkAt(w.x, w.y, 5 * item.px)
            onLink = !!l
            if (l) {
                canvas.forceActiveFocus()
                Ui.selectLink(l)
                return
            }
            item.pressAt(w)
        }
        onPositionChanged: (m) => {
            if (pressed && !onLink && (m.buttons & Qt.LeftButton))
                item.dragTo(mapToItem(canvas.world, m.x, m.y))
        }
        onReleased: (m) => {
            if (m.button === Qt.RightButton) {
                if (onLink)
                    canvas.linkMenu.popup()
                else
                    canvas.screenMenu.popupFor(item.screenId)
            }
        }
        onDoubleClicked: (m) => {
            if (m.button !== Qt.LeftButton)
                return
            if (onLink)
                Ui.interactionDialog.openEdit(Ui.selectedLink)
            else
                Ui.openEditor(item.screenId, "")
        }
    }

    // Hotspots: drag one onto another screen to link it
    Repeater {
        model: item.hotspots
        delegate: Item {
            id: hs
            required property var modelData
            readonly property bool active: hsMouse.containsMouse || hsMouse.pressed
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            opacity: item.showHotspots || active ? 1 : 0.85

            Rectangle {
                anchors.fill: parent
                radius: 2 * item.px
                color: hs.modelData.linked ? Qt.rgba(0.05, 0.6, 1, hs.active ? 0.32 : 0.2)
                                           : Qt.rgba(0.85, 0.54, 0, hs.active ? 0.3 : 0.18)
                border.width: (hs.active ? 2.5 : 1.5) * item.px
                border.color: hs.modelData.linked ? Theme.accent : Theme.warning
            }
            // name tag while hovered
            Rectangle {
                visible: hs.active && !hsMouse.dragging
                x: 0
                y: -(height + 3) * item.px
                scale: item.px
                transformOrigin: Item.TopLeft
                width: tagText.implicitWidth + 12
                height: 20
                radius: 4
                color: Theme.dark
                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: (hs.modelData.name || qsTr("Hotspot")) + (hs.modelData.linked ? "" : "  –  " + qsTr("drag onto a screen to link"))
                    color: "white"
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            MouseArea {
                id: hsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property bool dragging: false
                property point start
                onPressed: (m) => {
                    if (canvas.spaceDown || m.button !== Qt.LeftButton) {
                        m.accepted = false
                        return
                    }
                    canvas.forceActiveFocus()
                    start = mapToItem(canvas.world, m.x, m.y)
                    dragging = false
                }
                onPositionChanged: (m) => {
                    if (!pressed)
                        return
                    const w = mapToItem(canvas.world, m.x, m.y)
                    if (!dragging) {
                        if (Math.hypot(w.x - start.x, w.y - start.y) * canvas.zoom < 4)
                            return
                        dragging = true
                        canvas.startLink(item.screenId, hs.modelData.id,
                                         Qt.point(item.posX + hs.x + hs.width, item.posY + hs.y + hs.height / 2))
                    }
                    canvas.moveLink(w)
                }
                onReleased: {
                    if (dragging)
                        canvas.endLink()
                    else
                        Ui.selectScreen(item.screenId)
                    dragging = false
                }
                onDoubleClicked: Ui.openEditor(item.screenId, hs.modelData.id)
            }

            // Link circle on the middle of the right edge: drag it onto another screen.
            Rectangle {
                readonly property bool active: hsHandle.containsMouse || hsHandle.pressed
                visible: (item.selected || item.hovered || hs.active || active) && !(canvas.linking && !hsHandle.pressed)
                width: 12 * item.px
                height: width
                radius: width / 2
                x: hs.width - width / 2
                y: hs.height / 2 - height / 2
                color: active ? Theme.accent : "white"
                border.width: 2 * item.px
                border.color: hs.modelData.linked ? Theme.accent : Theme.warning
                MouseArea {
                    id: hsHandle
                    anchors.fill: parent
                    anchors.margins: -4 * item.px
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    onPressed: {
                        canvas.forceActiveFocus()
                        canvas.startLink(item.screenId, hs.modelData.id,
                                         Qt.point(item.posX + hs.x + hs.width, item.posY + hs.y + hs.height / 2))
                    }
                    onPositionChanged: (m) => { if (pressed) canvas.moveLink(mapToItem(canvas.world, m.x, m.y)) }
                    onReleased: canvas.endLink()
                }
            }
        }
    }

    // Round handle on the right edge: drag it to another screen for a described transition
    Rectangle {
        id: handle
        readonly property bool active: handleMouse.containsMouse || handleMouse.pressed
        visible: (item.selected || item.hovered || active) && !(canvas.linking && !handleMouse.pressed)
        width: 14 * item.px
        height: width
        radius: width / 2
        x: item.width - width / 2
        y: item.height / 2 - height / 2
        color: active ? Theme.transition : "white"
        border.width: 2 * item.px
        border.color: Theme.transition
        MouseArea {
            id: handleMouse
            anchors.fill: parent
            anchors.margins: -5 * item.px
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            onPressed: (m) => {
                canvas.forceActiveFocus()
                canvas.startLink(item.screenId, "", Qt.point(item.posX + item.width, item.posY + item.height / 2))
            }
            onPositionChanged: (m) => { if (pressed) canvas.moveLink(mapToItem(canvas.world, m.x, m.y)) }
            onReleased: canvas.endLink()
        }
    }
    Rectangle {
        visible: handleMouse.containsMouse && !handleMouse.pressed
        x: handle.x + handle.width + 6 * item.px
        y: handle.y + handle.height / 2 - height / 2 * item.px
        scale: item.px
        transformOrigin: Item.TopLeft
        width: handleTip.implicitWidth + 16
        height: 24
        radius: 4
        color: Theme.dark
        z: 10
        Text {
            id: handleTip
            anchors.centerIn: parent
            text: qsTr("Drag to another screen to add a described transition")
            color: "white"
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
