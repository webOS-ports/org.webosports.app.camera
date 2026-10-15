import QtQuick

import LuneOS.Components 1.0

/*
 * A button drawn from the legacy camera's artwork, redrawn as SVG
 * (qml/images): "<image>" normally and "<image>-pressed" while it is held.
 * Both are ArtworkImages at the size the button is shown, and both are loaded
 * up front, so the first press does not wait for its picture.
 */
Item {
    id: spriteButton

    /// The artwork's name in qml/images, without "-pressed" or ".svg".
    property string image
    readonly property alias pressed: area.pressed

    signal clicked()

    ArtworkImage {
        anchors.fill: parent
        svg: spriteButton.image ? Qt.resolvedUrl("../images/" + spriteButton.image + ".svg") : ""
        visible: !area.pressed
    }

    ArtworkImage {
        anchors.fill: parent
        svg: spriteButton.image ? Qt.resolvedUrl("../images/" + spriteButton.image + "-pressed.svg") : ""
        visible: area.pressed
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: spriteButton.clicked()
    }
}
