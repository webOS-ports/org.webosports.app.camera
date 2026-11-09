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

/*
 * A photo taken for another app, as a phone's camera does for a chat app:
 * the app launches the camera with
 *
 *     {"capture": {"returnTo": "<its app id>"}}
 *
 * the photo is shown to keep or take again, and the camera then relaunches
 * that app and closes:
 *
 *     {"cameraCapture": {"path": "/media/internal/DCIM/....jpg"}}   kept
 *     {"cameraCapture": {"cancelled": true}}                         Back
 *
 * A photo taken again is deleted: it was never wanted. The kept one stays in
 * the photo folder, like any other.
 */
QtObject {
    id: request

    // The app the photo is for, while one is being taken; "" otherwise.
    property string returnTo: ""
    readonly property bool active: returnTo !== ""
    // The photo taken, waiting to be kept or taken again.
    property string photo: ""
    readonly property bool reviewing: active && photo !== ""

    // Relaunch the app the photo was for, with what came of it.
    signal sendBack(string appId, var params)
    // A photo taken for it and not kept.
    signal discard(string path)

    // An application id, as the application manager has them.
    function isAppId(id) {
        return typeof id === "string" && id.length <= 255
                && /^[A-Za-z0-9][A-Za-z0-9_-]*(\.[A-Za-z0-9][A-Za-z0-9_-]*)+$/.test(id);
    }

    // A launch's "capture"; false when it is not one to take a photo for.
    function start(capture) {
        if (!capture || typeof capture !== "object" || !isAppId(capture.returnTo)) {
            console.warn("A photo was asked for with no app to give it to");
            return false;
        }
        returnTo = capture.returnTo;
        return true;
    }

    // The photo, saved and finished.
    function photoReady(path) {
        if (!active || !path)
            return;
        if (photo && photo !== path)
            discard(photo);
        photo = path;
    }

    function retake() {
        if (!reviewing)
            return;
        var path = photo;
        photo = "";
        discard(path);
    }

    function accept() {
        if (!reviewing)
            return;
        var app = returnTo, path = photo;
        photo = "";
        returnTo = "";
        sendBack(app, { cameraCapture: { path: path } });
    }

    function cancel() {
        if (!active)
            return;
        var app = returnTo;
        if (photo)
            discard(photo);
        photo = "";
        returnTo = "";
        sendBack(app, { cameraCapture: { cancelled: true } });
    }

    // Opened for itself meanwhile: no app waits for a photo any more. One
    // taken and not yet kept or taken again stays where it was saved.
    function drop() {
        photo = "";
        returnTo = "";
    }

    // The back gesture: from the photo, take it again; from the viewfinder,
    // give up. False when no photo is being taken for an app.
    function back() {
        if (reviewing) {
            retake();
            return true;
        }
        if (active) {
            cancel();
            return true;
        }
        return false;
    }
}
