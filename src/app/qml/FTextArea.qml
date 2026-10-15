import QtQuick
import QtQuick.Controls.Basic

// Multi-line field; emits committed(text) on focus-out when the text changed.
TextArea {
    id: control
    signal committed(string text)
    // Bind the model value here (not `text`): it is pushed into the field whenever it
    // changes and the user is not typing, also after an edit was committed.
    property string value
    property string initialText
    onValueChanged: if (!activeFocus) text = value
    Component.onCompleted: text = value

    leftPadding: 8
    rightPadding: 8
    topPadding: 7
    bottomPadding: 7
    font.pixelSize: Theme.fontSize
    color: Theme.text
    placeholderTextColor: Theme.textTertiary
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.text
    selectByMouse: true
    wrapMode: TextEdit.Wrap
    hoverEnabled: true

    background: Rectangle {
        implicitHeight: 64
        radius: Theme.radius
        color: control.activeFocus ? Theme.panel : control.hovered ? Theme.fieldHover : Theme.field
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.accent
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            initialText = text
        } else {
            if (text !== initialText)
                committed(text)
            Qt.callLater(() => { if (!control.activeFocus) control.text = control.value })
        }
    }
    Keys.onEscapePressed: focus = false
}
