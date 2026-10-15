import QtQuick
import QtQuick.Controls.Basic

ToolTip {
    id: tip
    delay: 500
    padding: 6
    leftPadding: 8
    rightPadding: 8
    font.pixelSize: Theme.fontSizeSmall
    contentItem: Text {
        text: tip.text
        font: tip.font
        color: Theme.darkText
        wrapMode: Text.Wrap
    }
    background: Rectangle {
        color: Theme.dark
        radius: Theme.radius
    }
}
