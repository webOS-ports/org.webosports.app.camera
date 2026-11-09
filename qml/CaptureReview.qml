/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

/*
 * The photo taken for another app, to keep or take again (CaptureRequest).
 */
Rectangle {
    id: review

    // The photo's path; shown while it is not "".
    property string path: ""

    signal retake()
    signal accept()

    color: "black"
    visible: path !== ""

    // Clicks stay here, off the viewfinder's tap-to-focus underneath.
    MouseArea {
        anchors.fill: parent
    }

    Image {
        objectName: "reviewPhoto"
        anchors.fill: parent
        anchors.bottomMargin: buttons.height + Units.gu(2)
        fillMode: Image.PreserveAspectFit
        // The JPEG is stored as the sensor sees it; its EXIF orientation turns it.
        autoTransform: true
        asynchronous: true
        sourceSize.width: Math.max(review.width, review.height)
        source: review.path !== "" ? "file://" + review.path : ""
    }

    Row {
        id: buttons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Units.gu(1.5)
        spacing: Units.gu(2)

        readonly property real buttonWidth: Math.min(Units.gu(18), (review.width - Units.gu(6)) / 2)

        Button {
            objectName: "retakeButton"
            width: buttons.buttonWidth
            text: qsTr("Retake")
            onClicked: review.retake()
        }
        Button {
            objectName: "usePhotoButton"
            width: buttons.buttonWidth
            text: qsTr("Use Photo")
            LuneOSButton.mainColor: LuneOSButton.affirmativeColor
            onClicked: review.accept()
        }
    }
}
