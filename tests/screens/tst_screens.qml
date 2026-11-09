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
import QtTest

import LunaNext.Common 0.1
import LuneOS.Camera 1.0

/*
 * The app as a whole - qml/main.qml - on one screen per run (see
 * tests/run-qml-tests.sh), each of its screens opened in turn and saved as
 * build/test-output/ui/<profile>-<screen>.png to look at.
 *
 * The host has no camera, so the droid camera of the phones is stood in by
 * the mock DroidCameraFactory in tests/qml/imports: a back camera with a
 * second lens and a front one, with flash. The viewfinder stays black; what
 * is checked is the chrome around it. On a screen with a notch and rounded
 * corners (radon) the shots show the parts of the panel that are not there
 * in red.
 */
TestCase {
    id: test
    name: "Screens"
    when: windowShown

    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    readonly property string profile: Settings.profileName
    property var app: null

    function init_data() {
        return [{ tag: Settings.profileName + " " + Settings.displayWidth + "x" + Settings.displayHeight }];
    }

    Component {
        id: panelMask
        // What the panel does not show: the cutouts and the rounded corners.
        Canvas {
            anchors.fill: parent
            z: 100000
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "rgba(255, 0, 0, 0.6)";
                var r = Settings.displayCornerRadii;
                var w = width, h = height;
                if (r.length === 4) {
                    // top left, top right, bottom right, bottom left
                    ctx.beginPath();
                    ctx.moveTo(0, 0); ctx.lineTo(r[0], 0); ctx.arc(r[0], r[0], r[0], -Math.PI / 2, Math.PI, true); ctx.closePath();
                    ctx.moveTo(w, 0); ctx.lineTo(w, r[1]); ctx.arc(w - r[1], r[1], r[1], 0, -Math.PI / 2, true); ctx.closePath();
                    ctx.moveTo(w, h); ctx.lineTo(w - r[2], h); ctx.arc(w - r[2], h - r[2], r[2], Math.PI / 2, 0, true); ctx.closePath();
                    ctx.moveTo(0, h); ctx.lineTo(0, h - r[3]); ctx.arc(r[3], h - r[3], r[3], Math.PI, Math.PI / 2, true); ctx.closePath();
                    ctx.fill();
                }
                var cuts = Settings.displayCutouts;
                for (var i = 0; i < cuts.length; i++)
                    ctx.fillRect(cuts[i].x, cuts[i].y, cuts[i].width, cuts[i].height);
            }
        }
    }

    Component {
        id: windowColour
        // The window's own colour, which a grab of its content leaves out.
        Rectangle {
            anchors.fill: parent
            z: -100000
            color: test.app ? test.app.color : "black"
        }
    }

    function shot(name) {
        wait(300);
        var background = windowColour.createObject(app.contentItem);
        var mask = null;
        if (Settings.displayCutouts.length > 0 || Settings.displayCornerRadii.length > 0) {
            mask = panelMask.createObject(app.contentItem);
            mask.requestPaint();
            wait(100);
        }
        var done = false;
        var ok = app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + profile + "-" + name + ".png");
            done = true;
        });
        verify(ok, "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
        background.destroy();
        if (mask)
            mask.destroy();
    }

    function find(objectName) {
        function look(item) {
            if (!item)
                return null;
            if (item.objectName === objectName)
                return item;
            var kids = item.data || item.children || [];
            for (var i = 0; i < kids.length; i++) {
                var found = look(kids[i]);
                if (found)
                    return found;
            }
            return null;
        }
        var it = look(app.contentItem);
        verify(it !== null, "found " + objectName);
        return it;
    }

    // Shown, of some size, and wholly inside the window.
    function onScreen(item, what) {
        verify(item.visible, what + " shown");
        verify(item.width > 0 && item.height > 0, what + " has a size: " + item.width + "x" + item.height);
        var box = item.mapToItem(app.contentItem, 0, 0, item.width, item.height);
        verify(box.x >= -0.5 && box.y >= -0.5
               && box.x + box.width <= app.width + 0.5 && box.y + box.height <= app.height + 0.5,
               what + " inside the " + app.width + "x" + app.height + " window: "
               + box.x + "," + box.y + " " + box.width + "x" + box.height);
        return box;
    }

    function apart(a, b, what) {
        verify(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y,
               what + " do not overlap");
    }

    function init() {
        DroidCameraFactory.available = true;
        DroidCameraFactory.controlsReady = true;
        DroidCameraFactory.recording = false;
        DroidCameraFactory.cameraCount = 2;
        DroidCameraFactory.cameraList = [{ index: 0, facing: "back" }, { index: 2, facing: "back" },
                                         { index: 1, facing: "front" }];
        DroidCameraFactory.supportedFlashModes = ["off", "auto", "on"];
        // Something in each of the Picture preferences, as a phone's HAL lists.
        DroidCameraFactory.hdrSupported = true;
        DroidCameraFactory.zslSupported = true;
        DroidCameraFactory.supportedFocusModes = ["auto", "continuous", "macro"];
        DroidCameraFactory.supportedWhiteBalanceModes = ["auto", "daylight", "cloudy-daylight", "incandescent"];
        DroidCameraFactory.supportedSceneModes = ["auto", "night", "portrait", "landscape"];
        DroidCameraFactory.supportedColorTones = ["none", "mono", "sepia"];
        DroidCameraFactory.supportedFlickerModes = ["auto", "50hz", "60hz"];
        DroidCameraFactory.supportedIsoSpeeds = ["auto", "100", "200", "400"];
        DroidCameraFactory.minimumExposureCompensation = -2;
        DroidCameraFactory.maximumExposureCompensation = 2;
        DroidCameraFactory.exposureCompensationStep = 0.5;
        var component = Qt.createComponent(Qt.resolvedUrl("../../qml/main.qml"));
        if (component.status === Component.Error)
            fail(component.errorString());
        app = component.createObject(null, { width: Settings.displayWidth, height: Settings.displayHeight });
        verify(app !== null, "main.qml made");
        // The app quits once a photo for another app is done with; the tests go on.
        app.quitWhenDone = false;
        app.requestActivate();
        var prefs = find("cameraView").prefs;
        prefs.captureMode = 0;
        prefs.flashMode = "auto";
        prefs.gpsEnabled = false;
        prefs.selfTimerDelay = 0;
        prefs.gridEnabled = false;
        prefs.position = 1;   // CameraDevice.BackFace
        // A click before the window has been shown for a moment goes nowhere.
        waitForRendering(app.contentItem);
        wait(500);
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        DroidCameraFactory.available = false;
        DroidCameraFactory.recording = false;
        wait(50);
    }

    // The chrome around the viewfinder, with the buttons a user takes a
    // picture with all on the screen and clear of each other.
    function checkChrome(video) {
        var view = onScreen(find("cameraView"), "viewfinder");
        compare(view.width, app.width, "viewfinder fills the window's width");
        compare(view.height, app.height, "viewfinder fills the window's height");
        onScreen(find("captureBar"), "capture bar");
        var shutter = onScreen(find("shutterButton"), "shutter");
        var gallery = onScreen(find("galleryButton"), "gallery button");
        var mode = onScreen(find("modeButton"), "photo / video switch");
        var settings = onScreen(find("settingsButton"), "preferences button");
        var flip = onScreen(find("flipButton"), "front / back button");
        apart(shutter, gallery, "shutter and gallery");
        apart(shutter, mode, "shutter and mode switch");
        apart(settings, flip, "preferences and front / back");
        compare(find("modeButton").image, video ? "mode-photo" : "mode-video");
    }

    function test_photo() {
        checkChrome(false);
        shot("photo");
    }

    function test_video() {
        mouseClick(find("modeButton"));
        tryVerify(function() { return find("captureOverlay").videoMode; }, 2000, "video mode");
        checkChrome(true);
        shot("video");

        DroidCameraFactory.recording = true;
        tryVerify(function() { return find("captureOverlay").recording; }, 2000, "recording");
        onScreen(find("shutterButton"), "stop button");
        compare(find("shutterButton").image, "stop");
        verify(!find("modeButton").visible, "no mode switch while recording");
        shot("recording");
    }

    function test_code_banner() {
        find("captureOverlay").showCode("https://www.webos-ports.org/wiki/Main_Page", "QR-Code");
        var banner = onScreen(find("codeBanner"), "code banner");
        verify(banner.width <= app.width, "banner fits across");
        shot("code-link");
        find("captureOverlay").showCode("otpauth://totp/LuneOS:user@example.org?secret=JBSWY3DPEHPK3PXP&issuer=LuneOS",
                                        "QR-Code");
        onScreen(find("codeBanner"), "code banner");
        shot("code-otpauth");
    }

    function test_preferences() {
        mouseClick(find("settingsButton"));
        var page = find("preferencesPage");
        tryVerify(function() { return page.y === 0; }, 2000, "preferences slid up");
        onScreen(page, "preferences");
        compare(page.width, app.width);
        verify(!find("captureOverlay").visible, "the capture controls are hidden behind the preferences");
        // Nothing in the page reaches out sideways.
        function widest(item) {
            var right = 0;
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++) {
                if (!kids[i].visible)
                    continue;
                if (kids[i].contentWidth !== undefined && kids[i].width > 0)
                    verify(kids[i].contentWidth <= kids[i].width + 1,
                           "no sideways scrolling: " + kids[i] + " " + kids[i].contentWidth + " > " + kids[i].width);
                widest(kids[i]);
            }
        }
        widest(page);
        shot("preferences");
        // The list that scrolls furthest is the page's own.
        var flick = null;
        (function look(item) {
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++) {
                if (!kids[i].visible)
                    continue;
                if (kids[i].contentHeight !== undefined && kids[i].flick !== undefined
                        && (!flick || kids[i].contentHeight - kids[i].height > flick.contentHeight - flick.height))
                    flick = kids[i];
                look(kids[i]);
            }
        })(page);
        if (flick && flick.contentHeight > flick.height + 1) {
            flick.contentY = flick.contentHeight - flick.height;
            shot("preferences-end");
        }
    }

    function test_app_menu() {
        var menu = find("appMenu");
        menu.popup(0, 0);
        tryVerify(function() { return menu.opened; }, 2000, "app menu open");
        verify(menu.width > 0 && menu.height > 0, "app menu has a size");
        verify(menu.x + menu.width <= app.width + 0.5 && menu.y + menu.height <= app.height + 0.5,
               "app menu inside the window");
        shot("app-menu");
        menu.close();
    }

    function test_kill_switch() {
        var notice = find("killSwitchNotice");
        notice.blocked = true;
        onScreen(notice, "kill switch notice");
        onScreen(find("killSwitchWords"), "the kill switch notice's words");
        verify(!find("captureOverlay").visible, "no shutter through the notice");
        shot("kill-switch");
    }

    SignalSpy {
        id: sentBack
        signalName: "sendBack"
    }

    // As another app launches the camera for a photo: {"capture": {"returnTo": ...}}.
    function askForPhoto() {
        var request = find("captureRequest");
        sentBack.target = request;
        sentBack.clear();
        find("captureOverlay").prefs.captureMode = 1;   // left in video
        app.launchParams = JSON.stringify({ capture: { returnTo: "org.webosports.app.messaging" } });
        tryVerify(function() { return request.active; }, 2000, "taking a photo for Messaging");
        return request;
    }

    function takeFor(request, path) {
        app.photoTaken(path);
        tryVerify(function() { return request.reviewing; }, 2000, "the photo is shown to keep or take again");
        compare(request.photo, path);
    }

    function test_photo_for_another_app() {
        var request = askForPhoto();
        var overlay = find("captureOverlay");
        verify(!overlay.videoMode, "photos only");
        onScreen(find("shutterButton"), "shutter");
        verify(!find("modeButton").visible, "no switch to video");
        verify(!find("galleryButton").visible, "no way off to Photos");
        shot("capture");

        // Not tagged with where it was taken, with a fix at hand and tagging on.
        overlay.prefs.gpsEnabled = true;
        app.lastFix = { latitude: 52.1, longitude: 5.1, altitude: NaN, time: Date.now() };
        verify(app.currentLocation() !== null, "a fix to tag with");
        takeFor(request, "/media/internal/DCIM/one.jpg");
        verify(find("imageTools").lastOptions.latitude === undefined, "no geotag on a photo for another app");
        var review = onScreen(find("captureReview"), "the photo to keep or take again");
        compare(review.width, app.width);
        var retake = onScreen(find("retakeButton"), "Retake");
        var use = onScreen(find("usePhotoButton"), "Use Photo");
        apart(retake, use, "Retake and Use Photo");
        shot("capture-review");

        // Retake: deleted, back to the viewfinder, nothing sent yet.
        mouseClick(find("retakeButton"));
        verify(!request.reviewing, "back to the viewfinder");
        verify(!find("captureReview").visible, "the photo is gone");
        compare(find("fileOperations").removed, ["/media/internal/DCIM/one.jpg"]);
        compare(sentBack.count, 0);

        takeFor(request, "/media/internal/DCIM/two.jpg");
        mouseClick(find("usePhotoButton"));
        compare(sentBack.count, 1, "Messaging relaunched once");
        compare(sentBack.signalArguments[0][0], "org.webosports.app.messaging");
        compare(JSON.stringify(sentBack.signalArguments[0][1]),
                JSON.stringify({ cameraCapture: { path: "/media/internal/DCIM/two.jpg" } }));
        compare(find("fileOperations").removed, ["/media/internal/DCIM/one.jpg"], "the kept one stays");
        verify(!request.active, "done");
        verify(overlay.videoMode, "back in the mode it was in");
        verify(find("modeButton").visible && find("galleryButton").visible, "the usual buttons again");
    }

    function test_back_while_taking_a_photo_for_another_app() {
        var request = askForPhoto();
        takeFor(request, "/media/internal/DCIM/one.jpg");
        // Back from the photo takes it again.
        keyClick(Qt.Key_Escape);
        verify(!request.reviewing, "back to the viewfinder");
        compare(find("fileOperations").removed, ["/media/internal/DCIM/one.jpg"]);
        compare(sentBack.count, 0);
        // The preferences close first.
        find("preferencesPage").open = true;
        keyClick(Qt.Key_Escape);
        verify(!find("preferencesPage").open, "preferences closed");
        verify(request.active, "still taking a photo");
        // Back from the viewfinder gives up and goes back.
        keyClick(Qt.Key_Escape);
        compare(sentBack.count, 1);
        compare(JSON.stringify(sentBack.signalArguments[0][1]), JSON.stringify({ cameraCapture: { cancelled: true } }));
        verify(!request.active, "done");
        // Back on its own camera does nothing it did not do before.
        keyClick(Qt.Key_Escape);
        compare(sentBack.count, 1);
    }

    function test_opened_for_itself_while_taking_a_photo() {
        var request = askForPhoto();
        takeFor(request, "/media/internal/DCIM/one.jpg");
        app.launchParams = JSON.stringify({ scan: true });
        tryVerify(function() { return !request.active; }, 2000, "no app waits any more");
        verify(!find("captureReview").visible);
        compare(find("fileOperations").removed, [], "the photo stays");
        compare(sentBack.count, 0);
        // An app id that is not one is not taken.
        app.launchParams = JSON.stringify({ capture: { returnTo: "../../bin/sh" } });
        wait(50);
        verify(!request.active, "no photo for that");
    }

    // A camera that lists none of the picture settings: no Picture box,
    // empty under its heading.
    function test_preferences_without_picture_settings() {
        DroidCameraFactory.hdrSupported = false;
        DroidCameraFactory.zslSupported = false;
        DroidCameraFactory.supportedFocusModes = ["auto"];
        DroidCameraFactory.supportedWhiteBalanceModes = [];
        DroidCameraFactory.supportedSceneModes = ["auto"];
        DroidCameraFactory.supportedColorTones = [];
        DroidCameraFactory.supportedFlickerModes = [];
        DroidCameraFactory.supportedIsoSpeeds = [];
        DroidCameraFactory.minimumExposureCompensation = 0;
        DroidCameraFactory.maximumExposureCompensation = 0;
        mouseClick(find("settingsButton"));
        var page = find("preferencesPage");
        tryVerify(function() { return page.y === 0; }, 2000, "preferences slid up");
        verify(!find("pictureGroup").visible, "no empty Picture group");
        DroidCameraFactory.hdrSupported = true;
        verify(find("pictureGroup").visible, "with HDR, a Picture group");
    }
}
