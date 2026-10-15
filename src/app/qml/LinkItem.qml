import QtQuick
import QtQuick.Shapes

// One arrow on the canvas: a cubic bezier computed in C++ (world coordinates), stroke and
// arrow head kept at a constant on-screen size.
Item {
    id: link
    required property var canvas
    required property string linkId
    required property bool isHotspotLink
    required property string message
    required property point p0
    required property point c0
    required property point c1
    required property point p1
    required property point mid

    readonly property real px: 1 / canvas.zoom
    readonly property bool selected: Ui.selectedLink === linkId
    readonly property color col: isHotspotLink ? Theme.accent : Theme.transition
    readonly property real head: 9 * px
    readonly property point dir: {
        let dx = p1.x - c1.x, dy = p1.y - c1.y
        let len = Math.hypot(dx, dy)
        if (len < 0.001) {
            dx = p1.x - p0.x
            dy = p1.y - p0.y
            len = Math.hypot(dx, dy) || 1
        }
        return Qt.point(dx / len, dy / len)
    }
    readonly property point base: Qt.point(p1.x - dir.x * head, p1.y - dir.y * head)
    opacity: canvas.linking ? 0.45 : 1

    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            // selection halo
            strokeColor: link.selected ? Qt.rgba(link.col.r, link.col.g, link.col.b, 0.22) : "transparent"
            strokeWidth: 7 * link.px
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: link.p0.x
            startY: link.p0.y
            PathCubic {
                control1X: link.c0.x; control1Y: link.c0.y
                control2X: link.c1.x; control2Y: link.c1.y
                x: link.p1.x; y: link.p1.y
            }
        }
        ShapePath {
            strokeColor: link.col
            strokeWidth: (link.selected ? 2.2 : 1.5) * link.px
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: link.p0.x
            startY: link.p0.y
            PathCubic {
                control1X: link.c0.x; control1Y: link.c0.y
                control2X: link.c1.x - link.dir.x * link.head * 0.5
                control2Y: link.c1.y - link.dir.y * link.head * 0.5
                x: link.base.x; y: link.base.y
            }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: link.col
            startX: link.p1.x
            startY: link.p1.y
            PathLine { x: link.base.x - link.dir.y * link.head * 0.55; y: link.base.y + link.dir.x * link.head * 0.55 }
            PathLine { x: link.base.x + link.dir.y * link.head * 0.55; y: link.base.y - link.dir.x * link.head * 0.55 }
            PathLine { x: link.p1.x; y: link.p1.y }
        }
    }
    Rectangle {
        width: 6 * link.px
        height: width
        radius: width / 2
        x: link.p0.x - width / 2
        y: link.p0.y - height / 2
        color: link.col
    }

    // Description pill at the middle of the curve
    Item {
        visible: link.message.length > 0
        x: link.mid.x
        y: link.mid.y
        scale: link.px
        transformOrigin: Item.TopLeft

        Rectangle {
            x: -width / 2
            y: -height / 2
            width: Math.min(pillText.implicitWidth + 18, 260)
            height: 22
            radius: 11
            color: link.selected ? link.col : Theme.panel
            border.width: 1
            border.color: link.col
            Text {
                id: pillText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 18)
                text: link.message
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: link.selected ? "white" : link.col
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    link.canvas.forceActiveFocus()
                    Ui.selectLink(link.linkId)
                }
                onReleased: (m) => { if (m.button === Qt.RightButton) link.canvas.linkMenu.popup() }
                onDoubleClicked: Ui.interactionDialog.openEdit(link.linkId)
            }
        }
    }
}
