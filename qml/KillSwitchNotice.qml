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
import LuneOS.Service 1.0

/*
 * Says so when the camera is off because the hardware privacy switch is on.
 *
 * Without this the app opens on a dead viewfinder: the switch stops the camera
 * HAL, so every capture path fails somewhere in the stack and the user is left
 * looking at a black rectangle that is indistinguishable from a broken camera.
 * The one thing they need to know - that they turned it off themselves, with a
 * switch on the side of the phone - is the one thing nothing was telling them.
 *
 * Covers the app rather than preventing launch on purpose. The switch can be
 * flipped while the app is open, and being able to see the notice disappear
 * when you flip it back is what makes the connection.
 */
Item {
    id: notice

    anchors.fill: parent
    visible: blocked
    z: 1000

    property bool blocked: false

    LunaService {
        id: killSwitchService
        name: "org.webosports.app.camera"

        onInitialized: {
            killSwitchService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                                        JSON.stringify({"serviceName": "org.webosports.service.killswitch"}),
                                        handleServiceStatus, handleError);
        }
    }

    function handleServiceStatus(message) {
        var response = JSON.parse(message.payload);
        if (response.connected !== true) {
            /* No service, no claim. A device with no switches must not have the
             * camera app permanently telling it the camera is blocked. */
            notice.blocked = false;
            return;
        }

        killSwitchService.subscribe("luna://org.webosports.service.killswitch/getStatus",
                                    JSON.stringify({"subscribe": true}),
                                    handleStatus, handleError);
    }

    function handleStatus(message) {
        var payload = JSON.parse(message.payload);
        if (!payload.hasOwnProperty("switches"))
            return;

        var anyBlocked = false;
        for (var i = 0; i < payload.switches.length; i++) {
            var entry = payload.switches[i];
            if (entry.state !== "blocked")
                continue;
            if (entry.id === "camera" || entry.id === "camera-front" || entry.id === "camera-rear")
                anyBlocked = true;
        }
        notice.blocked = anyBlocked;
    }

    function handleError(message) {
        console.log("KillSwitchNotice: " + message.payload);
        notice.blocked = false;
    }

    /* Fully opaque: at 0.85 the shutter and mode buttons showed through as
     * ghosts, which read as a broken app rather than a deliberate state. */
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(notice.height * 0.03)
        width: parent.width * 0.8

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/camera-blocked.png"
            width: Math.round(Math.min(notice.width, notice.height) * 0.22)
            height: width
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            color: "white"
            font.pixelSize: Math.round(notice.height * 0.032)
            font.bold: true
            text: qsTr("Camera turned off")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            color: "#cccccc"
            font.pixelSize: Math.round(notice.height * 0.022)
            text: qsTr("The hardware privacy switch is on. Flip it back to use the camera.")
        }
    }

    /* Swallow taps so the shutter cannot be pressed behind the notice. */
    MouseArea {
        anchors.fill: parent
    }
}
