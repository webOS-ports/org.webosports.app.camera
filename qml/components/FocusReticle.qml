import QtQuick 2.6

import LunaNext.Common 0.1

import LuneOS.Camera 1.0

/*
 * The legacy camera's viewfinder mark: corner brackets at rest, the green
 * circle while focusing, and the closed ring once focus has locked. It sits in
 * the middle, or where the user tapped to focus.
 */
Item {
    id: reticle

    /// DroidCameraFactory.focusStatus, or FocusIdle where there is no autofocus.
    property int focusStatus: DroidCameraFactory.FocusIdle

    // 100 px in the legacy stylesheet.
    width: Units.gu(12.5)
    height: width

    Image {
        anchors.fill: parent
        source: "../images/legacy/view-finder.png"
        opacity: reticle.focusStatus === DroidCameraFactory.FocusIdle
                 || reticle.focusStatus === DroidCameraFactory.FocusFailed ? 1 : 0
    }

    Image {
        id: focusing
        anchors.fill: parent
        source: "../images/legacy/view-finder-autofocus.png"
        opacity: reticle.focusStatus === DroidCameraFactory.FocusRunning ? 1 : 0
        // The legacy focusing circle closed in on the subject.
        scale: opacity > 0 ? 0.8 : 1.0
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    }

    Image {
        anchors.fill: parent
        source: "../images/legacy/view-finder-autofocus-lock.png"
        opacity: reticle.focusStatus === DroidCameraFactory.FocusSucceeded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
