import QtQuick
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0
import Eos.Window 0.1

import LuneOS.Service 1.0
import LuneOS.System 1.0
import LuneOS.Camera 1.0
import CameraApp 0.1

import "components"
import "prefs"

WebOSWindow {
    id: root

    visible: true

    width: 600
    height: 800

    color: "black"

    PreferencesModel {
        id: preferences
    }

    LunaService {
        id: lunaService
        name: "org.webosports.app.camera"
        onInitialized: {
            root.busReady = true;
            root.updateLocationRequest();
        }
    }

    /* The status bar's app menu draws nothing itself: it relaunches the app
     * with this command and the app puts up its own menu. */
    function handleLaunchParams(params) {
        if (!params)
            return;
        var command = params["palm-command"] || (params.params ? params.params["palm-command"] : undefined);
        if (command === "open-app-menu")
            appMenu.popup(0, 0);
    }

    /* qml-runner, which starts this app, hands the parameters over as the
     * window's launchParams, at launch and again on every relaunch; the
     * "application" object below only exists under the older launcher.
     * launchParams only notifies when it changes, and opening the app menu
     * twice relaunches with the same parameters, so it is cleared once
     * handled and the next one is a change again. */
    function handleLaunchString(text) {
        if (!text)
            return;
        try {
            handleLaunchParams(JSON.parse(text));
        } catch (error) {
            console.warn("Could not parse launch parameters: " + error);
        }
        root.launchParams = "";
    }

    onLaunchParamsChanged: handleLaunchString(root.launchParams)

    Component.onCompleted: {
        if (root.launchParams)
            handleLaunchString(root.launchParams);
        else if (typeof application !== "undefined")
            handleLaunchString(application.launchParameters);
    }

    Connections {
        target: typeof application !== "undefined" ? application : null
        function onRelaunched(parameters) {
            try {
                root.handleLaunchParams(JSON.parse(parameters));
            } catch (error) {
                console.warn("Could not parse relaunch parameters: " + error);
            }
        }
    }

    Menu {
        id: appMenu
        // The app menu is the dark one that drops out of the corner.
        LuneOSMenu.appMenuStyle: true

        MenuItem {
            text: qsTr("Preferences")
            onTriggered: preferencesPage.open = true
        }
        MenuItem {
            text: qsTr("Photos & Videos")
            onTriggered: root.openPhotos()
        }
    }

    // Needs "application.launcher" and, for open, "appmanager.management"
    // in sysbus/org.webosports.app.camera.perm.json.
    AppLauncher {
        id: launcher
        clientName: "org.webosports.app.camera"
    }

    function openPhotos() {
        launcher.launch("org.webosports.app.photos", null, undefined,
                        function(error) { console.warn("Could not open Photos: " + error); });
    }

    // The OSE application manager has no "open"; AppLauncher sends it to the
    // one that does, which hands the URL to whatever handles it.
    function openUrl(url) {
        launcher.open(url, undefined,
                      function(error) { console.warn("Could not open " + url + ": " + error); });
    }

    /* Where the phone is, for geotags. Only asked while tagging is on and the
     * app is in front, and a fix older than two minutes is not used: a stale
     * position would tag a photo with somewhere it was not taken.
     *
     * Asked of the location service directly, on the app's own bus name, and
     * not through Qt Positioning: the LuneOS position plugin connects to the
     * bus without a name, so the hub gives it none of the app's permissions
     * and refuses getLocationUpdates. */
    property var locationCall: null
    property var lastFix: null
    property bool busReady: false
    readonly property bool wantLocation: preferences.gpsEnabled
                                         && Qt.application.state === Qt.ApplicationActive
    onWantLocationChanged: updateLocationRequest()

    function updateLocationRequest() {
        if (wantLocation && busReady && !locationCall) {
            locationCall = lunaService.subscribe("luna://com.webos.service.location/getLocationUpdates",
                                                 JSON.stringify({ subscribe: true }),
                                                 handleLocation, handleLocationError);
        } else if (!wantLocation && locationCall) {
            locationCall.cancel();
            locationCall = null;
        }
    }
    function handleLocation(message) {
        var response = JSON.parse(message.payload);
        if (response.returnValue === false) {
            // "Location source is off" and the like; the request has ended.
            console.warn("No location for geotags: " + (response.errorText || message.payload));
            locationCall = null;
            return;
        }
        var fix = fixFrom(response);
        if (fix)
            lastFix = fix;
    }
    /* A fix usable for a geotag from a location service reply, or null. Not
     * one: no position, the 0, 0 the Q25's service has answered with while it
     * had no fix at all, and anything less precise than 500 m or of unknown
     * precision (beaconDB's fallback from the IP address is 25 km). */
    readonly property real geotagAccuracyLimit: 500
    function fixFrom(response) {
        if (response.latitude === undefined || response.longitude === undefined)
            return null;
        if (response.latitude === 0 && response.longitude === 0)
            return null;
        if (!(response.horizAccuracy > 0 && response.horizAccuracy <= geotagAccuracyLimit))
            return null;
        return {
            latitude: response.latitude,
            longitude: response.longitude,
            // A network fix has no altitude: the service then says -1 for both the
            // altitude and its accuracy, which would be written as 1 m below the sea.
            altitude: (response.altitude !== undefined && response.vertAccuracy > 0) ? response.altitude : NaN,
            time: response.timestamp !== undefined ? response.timestamp : Date.now()
        };
    }
    // A request that ended (location switched off, the service restarted) is
    // made again while tagging is wanted, so switching location on in the
    // system settings is picked up without restarting the camera.
    Timer {
        interval: 30000
        repeat: true
        running: root.wantLocation && root.busReady && !root.locationCall
        onTriggered: root.updateLocationRequest()
    }
    /* Standing still, the service sends no new position and does not look
     * again on its own, so the one it sent goes past two minutes while the
     * camera is still open (seen on the Pixel 3a: a fix at 10:20:15, a photo
     * at 10:23:53 untagged). Ask anew every minute while the camera is in
     * front with tagging on: one WiFi scan and one lookup. */
    Timer {
        interval: 60000
        repeat: true
        running: root.wantLocation && root.busReady && !!root.locationCall
        onTriggered: {
            root.locationCall.cancel();
            root.locationCall = null;
            root.updateLocationRequest();
        }
    }
    function handleLocationError(error) {
        console.warn("Location request failed: " + JSON.stringify(error));
        locationCall = null;
    }
    function currentLocation() {
        if (!preferences.gpsEnabled || !lastFix)
            return null;
        if (Date.now() - lastFix.time > 2 * 60 * 1000)
            return null;
        return lastFix;
    }

    /* Once saved, a photo is turned (EXIF Orientation), tagged with where it
     * was taken and, where the camera could not zoom itself, cropped; the
     * thumbnail follows when that is done. */
    ImageTools {
        id: imageTools
        onFinished: (path, ok, error) => {
            if (!ok)
                console.warn("could not finish " + path + ": " + error);
            captureOverlayItem.setLastCapturedImage(path);
        }
    }
    function photoTaken(path) {
        if (!/\.jpe?g$/i.test(path)) {
            captureOverlayItem.setLastCapturedImage(path);
            return;
        }
        var options = { rotation: cameraViewItem.recordingRotation };
        if (cameraViewItem.useDroidCamera && DroidCameraFactory.controlsReady)
            options.exposureBias = DroidCameraFactory.appliedExposureCompensation();
        if (!cameraViewItem.halZoom && cameraViewItem.zoomFactor > 1.001)
            options.zoom = cameraViewItem.zoomFactor;

        var done = false;
        function finish(where) {
            if (done)
                return;
            done = true;
            if (where) {
                options.latitude = where.latitude;
                options.longitude = where.longitude;
                if (!isNaN(where.altitude))
                    options.altitude = where.altitude;
            }
            imageTools.process(path, options);
        }

        var where = currentLocation();
        if (where || !preferences.gpsEnabled || !busReady) {
            finish(where);
            return;
        }
        /* The subscription only reports a position when it changes; standing
         * still, the last one it sent goes past two minutes while the service
         * keeps confirming it. Ask for that, as fresh as the service has it,
         * and finish the photo with or without it - in 3 s at the latest. */
        lunaService.call("luna://com.webos.service.location/getCachedPosition",
                         JSON.stringify({ maximumAge: 2 * 60 * 1000 }),
                         function (message) {
                             var fix = fixFrom(JSON.parse(message.payload));
                             if (fix)
                                 lastFix = fix;
                             finish(currentLocation());
                         },
                         function (error) { finish(null); });
        var fallback = Qt.createQmlObject("import QtQuick; Timer { interval: 3000; running: true }", root);
        fallback.triggered.connect(function () { finish(null); fallback.destroy(); });
    }

    CameraView {
        id: cameraViewItem

        anchors.fill: parent
        prefs: preferences

        onCaptureDone: (filepath) => root.photoTaken(filepath)
        onCodeDetected: (text, format) => captureOverlayItem.showCode(text, format)
    }

    CaptureOverlay {
        id: captureOverlayItem

        anchors.fill: parent
        /* Nothing to drive while the camera is off, and a shutter button
         * showing through the notice just looks broken. */
        visible: !killSwitchNotice.blocked && !preferencesPage.open

        captureSession: cameraViewItem.captureSessionItem
        cameraView: cameraViewItem
        prefs: preferences

        onGalleryButtonClicked: root.openPhotos()
        onSettingsButtonClicked: preferencesPage.open = true
        onCodeOpenRequested: (url) => root.openUrl(url)
    }

    /* The preferences scene slides up over the viewfinder. */
    PreferencesPage {
        id: preferencesPage

        property bool open: false

        width: parent.width
        height: parent.height
        y: open ? 0 : parent.height
        visible: y < parent.height
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        prefs: preferences
        onClosed: open = false
    }

    /* Last, so it covers the viewfinder and the capture controls alike. */
    KillSwitchNotice {
        id: killSwitchNotice

        /* Keep covering the viewfinder until frames are actually flowing, so
         * the notice hands straight over to "starting" instead of uncovering a
         * black rectangle. Covers the wait for the hardware too, which is the
         * longer half of it. */
        preparing: hardwarePending || cameraViewItem.previewStarting

        /* The HAL is stopped while the switch is on and the camera source does
         * not survive it, so ask for a fresh one once it is released - but only
         * once the service says the hardware is actually ready. Attaching while
         * it is not blocks inside the HAL and freezes the UI, so waiting is
         * what keeps the "starting" spinner moving. */
        onBlockedChanged: reopenWhenReady()
        onHardwarePendingChanged: reopenWhenReady()

        function reopenWhenReady() {
            if (!blocked && !hardwarePending)
                cameraViewItem.reopenCamera();
        }
    }
}
