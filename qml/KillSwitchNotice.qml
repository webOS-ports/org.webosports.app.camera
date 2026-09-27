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
    visible: blocked || preparing
    z: 1000

    property bool blocked: false

    /* Stays up after the switch is released, while the camera hardware powers
     * back up. Releasing the switch does not give an instant picture: the
     * sensor was unpowered, so the HAL cannot open it for several seconds, and
     * on the FLX1s that takes long enough that a black viewfinder reads as a
     * broken app. Nothing was telling the user it was working on it. */
    property bool preparing: false

    /* The service says the switch has moved but the hardware is not ready yet.
     * Attaching in this window blocks inside the HAL for as long as the sensor
     * takes, which freezes the UI - the spinner included - so the app waits
     * here instead and lets the service do the waiting in its own process. */
    property bool hardwarePending: false

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
            notice.hardwarePending = false;
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
        var anyPending = false;
        for (var i = 0; i < payload.switches.length; i++) {
            var entry = payload.switches[i];
            if (entry.id !== "camera" && entry.id !== "camera-front" && entry.id !== "camera-rear")
                continue;
            if (entry.state === "blocked")
                anyBlocked = true;
            if (entry.actionPending === true)
                anyPending = true;
        }
        /* Pending first, deliberately. These are two property writes from one
         * message, and the release message carries both "not blocked" and "not
         * ready yet". Setting blocked first would fire its handler while
         * hardwarePending still read false, and the app would attach in exactly
         * the window this field exists to describe. */
        notice.hardwarePending = anyPending;
        notice.blocked = anyBlocked;
    }

    function handleError(message) {
        console.log("KillSwitchNotice: " + message.payload);
        notice.blocked = false;
        notice.hardwarePending = false;
    }

    /* Fully opaque: at 0.85 the shutter and mode buttons showed through as
     * ghosts, which read as a broken app rather than a deliberate state. */
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    /*
     * Below centre, not centred. The shell shows its own switch alert dead
     * centre for a couple of seconds whenever a switch moves, and this notice
     * appears at exactly that moment - centred, the alert's glyph landed across
     * this heading and the screen showed two camera icons on top of each other.
     * Leaving the middle free is this side's job: the alert is system-wide and
     * sits where legacy webOS has always put it.
     */
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(notice.height * 0.56)
        spacing: Math.round(notice.height * 0.03)
        width: parent.width * 0.8

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(Math.min(notice.width, notice.height) * 0.22)
            height: width

            Image {
                anchors.fill: parent
                source: "images/camera-blocked.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
                visible: notice.blocked
            }

            /* Built from primitives rather than a BusyIndicator: the app cannot
             * count on QtQuick.Controls being installed on every LuneOS image,
             * and this needs no artwork.
             *
             * Driven by an Animator, not a NumberAnimation, and that is the
             * point rather than a detail: attaching to the camera blocks the
             * main thread for as long as the HAL takes, and an Animator runs on
             * the render thread, which keeps going. Measured during a
             * deliberate 3s block of the main thread: 857 frames still
             * rendered. A NumberAnimation would freeze along with everything
             * else and leave a dead spinner on screen, which is worse than
             * none. */
            Item {
                id: spinner

                anchors.fill: parent
                visible: !notice.blocked

                Repeater {
                    model: 12

                    Rectangle {
                        readonly property real angle: index * 30 * Math.PI / 180

                        width: Math.max(2, Math.round(spinner.width * 0.075))
                        height: width
                        radius: width / 2
                        color: "white"
                        opacity: 0.15 + 0.85 * (index / 12)
                        x: spinner.width / 2 - width / 2 + Math.sin(angle) * spinner.width * 0.4
                        y: spinner.height / 2 - height / 2 - Math.cos(angle) * spinner.height * 0.4
                    }
                }

                RotationAnimator on rotation {
                    running: spinner.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1200
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            color: "white"
            font.pixelSize: Math.round(notice.height * 0.032)
            font.bold: true
            text: notice.blocked ? qsTr("Camera turned off") : qsTr("Starting camera")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            color: "#cccccc"
            font.pixelSize: Math.round(notice.height * 0.022)
            text: notice.blocked
                  ? qsTr("The hardware privacy switch is on. Flip it back to use the camera.")
                  : qsTr("The camera is powering back up. This takes a few seconds.")
        }
    }

    /* Swallow taps so the shutter cannot be pressed behind the notice. */
    MouseArea {
        anchors.fill: parent
    }
}
