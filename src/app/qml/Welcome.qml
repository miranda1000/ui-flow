import QtQuick
import QtQuick.Layouts

// Shown when no app is open.
Rectangle {
    color: Theme.canvas

    FIconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        iconName: "github"
        tip: qsTr("Help and feedback on GitHub")
        onClicked: Qt.openUrlExternally(Ui.issuesUrl)
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 440
        spacing: 0

        Image {
            source: "icons/app.svg"
            sourceSize: Qt.size(48, 48)
        }
        Text {
            Layout.topMargin: 18
            text: "ui-flow"
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            Layout.topMargin: 6
            Layout.fillWidth: true
            text: qsTr("Map how the screens of an app connect. Drop screenshots, mark what can be clicked, draw the flow between screens, then press Play to click through it.")
            wrapMode: Text.Wrap
            lineHeight: 1.3
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.textSecondary
        }
        RowLayout {
            Layout.topMargin: 24
            spacing: 8
            FButton {
                variant: "primary"
                iconName: "plus"
                text: qsTr("New app")
                onClicked: Ui.main.newApp()
            }
            FButton {
                iconName: "folder"
                text: qsTr("Open…")
                onClicked: Ui.main.openApp()
            }
        }

        Rectangle {
            Layout.topMargin: 28
            Layout.fillWidth: true
            visible: Doc.recentFiles.length > 0
            implicitHeight: recentColumn.implicitHeight + 12
            radius: 8
            color: Theme.panel
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: recentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 0
                Text {
                    Layout.leftMargin: 10
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    text: qsTr("Recent")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }
                Repeater {
                    model: Doc.recentFiles.slice(0, 6)
                    delegate: ListRow {
                        id: row
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 40
                        onClicked: Doc.openApp(modelData)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Icon { name: "file"; color: Theme.textSecondary }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.replace(/^.*[\/\\]/, "")
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.Medium
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.replace(/[\/\\][^\/\\]*$/, "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.textTertiary
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.topMargin: 20
            Layout.fillWidth: true
            text: qsTr("Tip: drop screenshots or an app file (.json) anywhere in this window.")
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textTertiary
        }
        Text {
            Layout.topMargin: 6
            text: qsTr("Need help? <a href=\"%1\">Ask or report an issue on GitHub</a>").arg(Ui.issuesUrl)
            textFormat: Text.StyledText
            linkColor: Theme.accent
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textTertiary
            onLinkActivated: (link) => Qt.openUrlExternally(link)
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }
}
