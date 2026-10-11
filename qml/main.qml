import QtQuick
import QtQuick.Controls
import QtQuick.Controls.LuneOS 2.0
import Eos.Window 0.1

import LuneOS.Service 1.0
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

    Component.onCompleted: {
        if (typeof application !== "undefined") {
            try {
                handleLaunchParams(JSON.parse(application.launchParameters));
            } catch (error) {
                console.warn("Could not parse launch parameters: " + error);
            }
        }
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

    function openPhotos() {
        lunaService.call("luna://com.webos.service.applicationmanager/launch",
                         JSON.stringify({ id: "org.webosports.app.photos" }), undefined,
                         function(error) { console.warn("Could not open Photos: " + error); });
    }

    function openUrl(url) {
        lunaService.call("luna://com.webos.service.applicationmanager/open",
                         JSON.stringify({ target: url }), undefined,
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
        if (response.latitude === undefined || response.longitude === undefined)
            return;
        // Not a position: the Q25's location service has answered with
        // latitude 0, longitude 0 and accuracy 0 while it had no fix at all.
        if (response.latitude === 0 && response.longitude === 0)
            return;
        lastFix = {
            latitude: response.latitude,
            longitude: response.longitude,
            altitude: response.altitude !== undefined ? response.altitude : NaN,
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
        var where = currentLocation();
        if (where) {
            options.latitude = where.latitude;
            options.longitude = where.longitude;
            if (!isNaN(where.altitude))
                options.altitude = where.altitude;
        }
        if (!cameraViewItem.halZoom && cameraViewItem.zoomFactor > 1.001)
            options.zoom = cameraViewItem.zoomFactor;
        imageTools.process(path, options);
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
