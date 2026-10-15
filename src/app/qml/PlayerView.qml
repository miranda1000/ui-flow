import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// The emulator: shows one screen at a time; clicking its hotspots (or picking a described
// transition) moves through the flow.
Rectangle {
    id: player
    color: Theme.dark
    focus: true

    readonly property string current: Ui.playScreen
    readonly property var s: (Doc.revision < 0 ? undefined : Doc.screen(current))
    readonly property var hotspots: (Doc.revision < 0 ? undefined : Doc.hotspots(current))
    readonly property var actions: (Doc.revision < 0 ? undefined : Doc.linksFrom(current, true))
    readonly property int hotspotLinks: {
        let n = 0
        for (let i = 0; i < hotspots.length; ++i)
            n += hotspots[i].links.length
        return n
    }
    property var history: []          // [{ screen, name, action }]
    property bool showHotspots: false
    property real flash: 0
    property string missed

    function go(link) {
        history = history.concat([{ screen: current, name: s.displayName, action: link.label }])
        Ui.playScreen = link.to
        if (link.message)
            messageToast.show(link.message, link.isHotspotLink)
        fadeIn.restart()
    }
    function back() {
        if (history.length === 0)
            return
        const h = history[history.length - 1]
        history = history.slice(0, -1)
        Ui.playScreen = h.screen
        fadeIn.restart()
    }
    function restart() {
        history = []
        Ui.playScreen = Doc.startScreen
        fadeIn.restart()
    }
    function jumpTo(i) {
        const h = history[i]
        history = history.slice(0, i)
        Ui.playScreen = h.screen
        fadeIn.restart()
    }
    function clickHotspot(h, x, y) {
        if (h.links.length === 1) {
            go(h.links[0])
        } else if (h.links.length > 1) {
            choiceMenu.links = h.links
            choiceMenu.popup()
        } else {
            missed = h.id
            missTimer.restart()
        }
    }

    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape)
            Ui.stopPlay()
        else if (e.key === Qt.Key_Backspace || (e.key === Qt.Key_Left && (e.modifiers & Qt.AltModifier)))
            back()
        else if (e.key === Qt.Key_R)
            restart()
        else if (e.key === Qt.Key_H)
            showHotspots = !showHotspots
        else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && e.key - Qt.Key_1 < actions.length)
            go(actions[e.key - Qt.Key_1])
        else
            return
        e.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- top bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: Theme.darkPanel
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#000000" }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: 4
                FIconButton { dark: true; iconName: "close"; tip: qsTr("Stop playing (Esc)"); onClicked: Ui.stopPlay() }
                Text {
                    Layout.leftMargin: 6
                    text: Doc.appName
                    color: Theme.darkTextSecondary
                    font.pixelSize: Theme.fontSizeLarge
                }
                Text { text: "/"; color: "#666666"; font.pixelSize: Theme.fontSizeLarge }
                Text {
                    text: player.s.displayName || ""
                    color: Theme.darkText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.maximumWidth: 320
                }
                Item { Layout.fillWidth: true }
                FIconButton { dark: true; iconName: "back"; enabled: player.history.length > 0; tip: qsTr("Back (Backspace)"); onClicked: player.back() }
                FIconButton { dark: true; iconName: "restart"; tip: qsTr("Restart from the start screen (R)"); onClicked: player.restart() }
                Rectangle { implicitWidth: 1; implicitHeight: 20; color: Theme.darkBorder; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                FIconButton {
                    dark: true
                    iconName: "eye"
                    checkable: true
                    checked: player.showHotspots
                    onToggled: player.showHotspots = checked
                    tip: qsTr("Show hotspots (H)")
                }
                Text {
                    Layout.leftMargin: 8
                    text: qsTr("Step %1").arg(player.history.length + 1)
                    color: Theme.darkTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // --- the screen
            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property real fitScale: Math.min(1.5, (width - 64) / Math.max(1, player.s.imageWidth || 1),
                                                          (height - 64) / Math.max(1, player.s.imageHeight || 1))

                MouseArea {
                    anchors.fill: parent
                    onClicked: flashAnim.restart()
                }

                Item {
                    id: device
                    anchors.centerIn: parent
                    width: (player.s.imageWidth || 0) * stage.fitScale
                    height: (player.s.imageHeight || 0) * stage.fitScale

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        color: "transparent"
                        border.width: 1
                        border.color: "#3A3A3A"
                    }
                    Image {
                        id: shown
                        anchors.fill: parent
                        source: player.s.imageUrl || ""
                        mipmap: true
                        smooth: true
                        NumberAnimation on opacity { id: fadeIn; from: 0.35; to: 1; duration: 160; easing.type: Easing.OutCubic }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: flashAnim.restart()
                    }
                    Repeater {
                        model: player.hotspots
                        delegate: Rectangle {
                            id: hsp
                            required property var modelData
                            readonly property bool live: modelData.links.length > 0
                            x: modelData.x * stage.fitScale
                            y: modelData.y * stage.fitScale
                            width: modelData.w * stage.fitScale
                            height: modelData.h * stage.fitScale
                            radius: 3
                            color: player.missed === modelData.id ? Qt.rgba(0.95, 0.28, 0.13, 0.25)
                                                                 : Qt.rgba(0.05, 0.6, 1, 0.18)
                            border.width: 2
                            border.color: player.missed === modelData.id ? Theme.danger : Theme.accent
                            opacity: player.missed === modelData.id ? 1
                                     : player.showHotspots ? (live ? 0.9 : 0.35)
                                     : hspMouse.containsMouse && live ? 0.35 : player.flash * (live ? 1 : 0.4)
                            MouseArea {
                                id: hspMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: hsp.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: (m) => player.clickHotspot(hsp.modelData, m.x, m.y)
                            }
                        }
                    }
                }

                // Description of the transition just taken
                Rectangle {
                    id: messageToast
                    property bool hotspot: false
                    function show(text, isHotspot) {
                        messageText.text = text
                        hotspot = isHotspot
                        opacity = 1
                        messageTimer.restart()
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 22
                    width: Math.min(messageRow.implicitWidth + 32, parent.width - 48)
                    height: 36
                    radius: 18
                    color: Theme.darkPanel
                    border.width: 1
                    border.color: Theme.darkBorder
                    opacity: 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Row {
                        id: messageRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: messageToast.hotspot ? Theme.accent : Theme.transition
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: messageText
                            color: Theme.darkText
                            font.pixelSize: Theme.fontSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Timer { id: messageTimer; interval: 2600; onTriggered: messageToast.opacity = 0 }
                }

                // Dead end
                Rectangle {
                    visible: player.hotspotLinks === 0 && player.actions.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    width: deadText.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: Theme.darkPanel
                    Text {
                        id: deadText
                        anchors.centerIn: parent
                        text: qsTr("End of the flow: nothing leads away from this screen")
                        color: Theme.darkTextSecondary
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // --- side panel: transitions and the path so far
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                color: Theme.darkPanel
                Rectangle { width: 1; height: parent.height; color: "#000000" }

                Flickable {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    contentHeight: side.implicitHeight + 32
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: side
                        x: Theme.padding
                        y: 8
                        width: parent.width - 2 * Theme.padding
                        spacing: 6

                        Text {
                            Layout.topMargin: 6
                            text: qsTr("What the user can do")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.darkText
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: player.hotspotLinks > 0
                            text: qsTr("Click the screen – %n area(s) lead somewhere.", "", player.hotspots.filter(h => h.links.length).length)
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.darkTextSecondary
                        }
                        Repeater {
                            model: player.actions
                            delegate: ListRow {
                                id: arow
                                required property var modelData
                                required property int index
                                dark: true
                                Layout.fillWidth: true
                                implicitHeight: Math.max(44, acol.implicitHeight + 14)
                                onClicked: player.go(modelData)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10
                                    Rectangle {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 4
                                        color: Theme.transition
                                        Text {
                                            anchors.centerIn: parent
                                            text: arow.index < 9 ? arow.index + 1 : ""
                                            color: "white"
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    ColumnLayout {
                                        id: acol
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: arow.modelData.label
                                            wrapMode: Text.Wrap
                                            color: Theme.darkText
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "→ " + arow.modelData.toName
                                            elide: Text.ElideRight
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.darkTextSecondary
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: player.actions.length === 0 && player.hotspotLinks > 0
                            text: qsTr("No other transitions on this screen.")
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#7A7A7A"
                        }

                        Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 4; implicitHeight: 1; color: Theme.darkBorder }
                        Text {
                            text: qsTr("Path")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.darkText
                        }
                        Repeater {
                            model: player.history
                            delegate: ListRow {
                                id: hrow
                                required property var modelData
                                required property int index
                                dark: true
                                Layout.fillWidth: true
                                implicitHeight: hcol.implicitHeight + 12
                                onClicked: player.jumpTo(index)
                                ColumnLayout {
                                    id: hcol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: (hrow.index + 1) + ".  " + hrow.modelData.name
                                        color: Theme.darkTextSecondary
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 18
                                        text: hrow.modelData.action
                                        color: "#8A8A8A"
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.radius
                            color: Theme.darkHover
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: (player.history.length + 1) + ".  " + (player.s.displayName || "")
                                color: Theme.darkText
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: flashAnim
        target: player
        property: "flash"
        from: 0.9
        to: 0
        duration: 900
        easing.type: Easing.InQuad
    }
    Timer {
        id: missTimer
        interval: 450
        onTriggered: player.missed = ""
    }

    FMenu {
        id: choiceMenu
        property var links: []
        menuWidth: 260
        Instantiator {
            model: choiceMenu.links
            delegate: FMenuItem {
                required property var modelData
                text: (modelData.message ? modelData.message + "  →  " : qsTr("Go to ")) + modelData.toName
                onTriggered: player.go(modelData)
            }
            onObjectAdded: (index, object) => choiceMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => choiceMenu.removeItem(object)
        }
    }
}
