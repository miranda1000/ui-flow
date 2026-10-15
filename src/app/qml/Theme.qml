pragma Singleton
import QtQuick

// Design tokens: a light, quiet UI in the spirit of Figma's UI3.
QtObject {
    // Surfaces
    readonly property color panel: "#FFFFFF"
    readonly property color canvas: "#F5F5F5"
    readonly property color field: "#F5F5F5"
    readonly property color fieldHover: "#EDEDED"
    readonly property color hover: "#F2F2F2"
    readonly property color pressed: "#E6E6E6"
    readonly property color border: "#E6E6E6"
    readonly property color borderStrong: "#D4D4D4"

    // Text
    readonly property color text: "#1E1E1E"
    readonly property color textSecondary: "#6B6B6B"
    readonly property color textTertiary: "#A6A6A6"
    readonly property color textOnAccent: "#FFFFFF"

    // Accents
    readonly property color accent: "#0D99FF"
    readonly property color accentHover: "#0A8BEB"
    readonly property color accentPressed: "#087ACF"
    readonly property color accentSoft: "#E5F4FF"
    readonly property color transition: "#9747FF"      // described screen-to-screen transitions
    readonly property color transitionSoft: "#F3EBFF"
    readonly property color success: "#14AE5C"
    readonly property color successSoft: "#E3F7EC"
    readonly property color warning: "#D98A00"
    readonly property color warningSoft: "#FFF4DB"
    readonly property color danger: "#F24822"
    readonly property color dangerSoft: "#FFEBE6"

    // Dark surfaces (menus, tooltips, player)
    readonly property color dark: "#1E1E1E"
    readonly property color darkPanel: "#2C2C2C"
    readonly property color darkHover: "#383838"
    readonly property color darkBorder: "#444444"
    readonly property color darkText: "#FFFFFF"
    readonly property color darkTextSecondary: "#B3B3B3"

    // Type
    readonly property string fontFamily: Qt.application.font.family
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeLarge: 13
    readonly property int fontSizeTitle: 22

    // Metrics
    readonly property int radius: 5
    readonly property int radiusLarge: 12
    readonly property int controlHeight: 28
    readonly property int rowHeight: 32
    readonly property int topBarHeight: 48
    readonly property int leftPanelWidth: 248
    readonly property int rightPanelWidth: 272
    readonly property int padding: 16
    readonly property int iconSize: 16
}
