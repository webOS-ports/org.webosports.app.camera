import QtQuick 2.6

import LuneOS.Components 1.0

/*
 * A button drawn from one of the legacy camera's sprite strips: the frames sit
 * one above the other, each state's normal frame followed by its pressed one
 * (capture-buttons.png, flash-buttons.png, toggle-buttons.png).
 */
Item {
    id: spriteButton

    /// Resolved by the caller (Qt.resolvedUrl): a plain path would be taken
    /// relative to ClippedImage, where the Image that loads it is declared.
    property url source
    /// How many frames the strip holds.
    property int frames: 2
    /// The frame for the current state; the pressed look is the one after it.
    property int frame: 0
    readonly property alias pressed: area.pressed

    signal clicked()

    ClippedImage {
        anchors.fill: parent
        source: spriteButton.source
        // Both given, so the frame is stretched to exactly this size rather
        // than to proportions guessed before the image has loaded.
        wantedWidth: spriteButton.width
        wantedHeight: spriteButton.height
        patchGridSize: Qt.size(1, spriteButton.frames)
        patch: Qt.point(0, spriteButton.frame + (area.pressed ? 1 : 0))
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: spriteButton.clicked()
    }
}
