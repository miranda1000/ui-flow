import QtQuick
import QtQuick.Controls.Basic

// Borderless filled field; blue outline while editing. Emits committed(text) on
// Enter/focus-out when the text changed, so callers can record one undo step.
TextField {
    id: control
    signal committed(string text)
    // Bind the model value here (not `text`): it is pushed into the field whenever it
    // changes and the user is not typing, also after an edit was committed.
    property string value
    property string initialText
    onValueChanged: if (!activeFocus) text = value
    Component.onCompleted: text = value
    property bool selectOnFocus: false

    implicitHeight: Theme.controlHeight
    leftPadding: 8
    rightPadding: 8
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    font.pixelSize: Theme.fontSize
    color: Theme.text
    placeholderTextColor: Theme.textTertiary
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.text
    selectByMouse: true
    hoverEnabled: true

    background: Rectangle {
        radius: Theme.radius
        color: control.activeFocus ? Theme.panel : control.hovered ? Theme.fieldHover : Theme.field
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.accent
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            initialText = text
            if (selectOnFocus)
                selectAll()
        } else {
            if (text !== initialText)
                committed(text)
            Qt.callLater(() => { if (!control.activeFocus) control.text = control.value })
        }
    }
    onAccepted: {
        if (text !== initialText) {
            initialText = text
            committed(text)
        }
        focus = false
    }
    Keys.onEscapePressed: {
        text = initialText
        focus = false
    }
}
