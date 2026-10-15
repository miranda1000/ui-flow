import QtQuick

// Menu listing every screen; emits picked(screenId).
FMenu {
    id: menu
    signal picked(string screenId)
    property string exclude

    Instantiator {
        model: (Doc.revision < 0 ? undefined : Doc.screenList())
        delegate: FMenuItem {
            required property var modelData
            text: modelData.name
            enabled: !menu || modelData.id !== menu.exclude
            onTriggered: menu.picked(modelData.id)
        }
        onObjectAdded: (index, object) => menu.insertItem(index, object)
        onObjectRemoved: (index, object) => menu.removeItem(object)
    }
}
