import QtQuick
import QtMultimedia

import LunaNext.Common 0.1
import LuneOS.Service 1.0

import CameraApp 0.1
import LuneOS.Camera 1.0
import LuneOS.Components 1.0
import "components"

/*
 * The camera's controls, laid out as in the camera app of the legacy webOS
 * phones: a bar with the last picture on one end, the shutter and the flash
 * on a bezel in the middle and the photo/video switch on the other end. The
 * bar runs along the bottom of a tall window and down the right edge of a wide
 * one, with the buttons themselves kept upright.
 *
 * Measurements are the legacy stylesheet's (camera.css), in its 1x pixels:
 * Units.gu(1) is 8 of them.
 */
Item {
    id: overlay

    property CaptureSession captureSession
    property Item cameraView
    property PreferencesModel prefs

    readonly property int cameraCount: cameraView ? cameraView.cameraCount : 0
    readonly property bool videoMode: prefs.captureMode === PreferencesModel.CaptureVideo
    readonly property bool useDroid: DroidCameraFactory.available
    readonly property bool recording: useDroid ? DroidCameraFactory.recording
        : (captureSession && captureSession.recorder
           && captureSession.recorder.recorderState === MediaRecorder.RecordingState)

    // A clearly wide window. The Q25's square screen is a little wider than tall once the status
    // bar is off, and does not count.
    readonly property bool landscape: width > height * 1.2
    // Which edge of the window the bar runs along. On a square screen the shell turns the card
    // with the device and the window keeps its shape, so the bar follows the device's own bottom
    // edge, where the Q25's keyboard is: held right side up (the card turned 270) that is the
    // window's right edge, held left side up (turned 90) its left edge.
    readonly property string barSide: {
        if (cameraView && cameraView.squareScreen) {
            if (cameraView.screenRotation === 270)
                return "right";
            if (cameraView.screenRotation === 90)
                return "left";
            return "bottom";
        }
        return landscape ? "right" : "bottom";
    }
    readonly property bool barUpright: barSide !== "bottom"

    /* Where the controls go. The picture leaves black strips beside or above it;
     * a strip wide enough for a control (the Q25's, 132 px either side) holds
     * the controls at the window's edge, a narrow one (the Pixel 3a's, 54 px)
     * would leave them half on the picture, so they go to the picture's edge. */
    readonly property rect picture: cameraView && cameraView.pictureRect.width > 0
                                    ? cameraView.pictureRect : Qt.rect(0, 0, width, height)
    readonly property real roomForControl: Units.gu(8)
    readonly property real areaLeft: picture.x >= roomForControl ? 0 : picture.x
    readonly property real areaRight: width - (picture.x + picture.width) >= roomForControl
                                      ? width : picture.x + picture.width
    readonly property real areaTop: picture.y >= roomForControl ? 0 : picture.y
    readonly property real areaBottom: height - (picture.y + picture.height) >= roomForControl
                                       ? height : picture.y + picture.height
    // The bar is 100 px deep.
    readonly property real barDepth: Units.gu(12.5)

    signal galleryButtonClicked()
    signal settingsButtonClicked()
    signal codeOpenRequested(string url)

    function setLastCapturedImage(path) {
        lastCapture.path = path;
    }

    function showCode(text, format) {
        codeBanner.show(text, format);
    }

    LunaService {
        id: lunaService
        name: "org.webosports.app.camera"
    }

    function playShutterSound() {
        if (!prefs.playShutterSound)
            return;
        lunaService.call("luna://com.palm.audio/systemsounds/playFeedback",
                         JSON.stringify({ name: "shutter" }), undefined,
                         function(error) { console.warn("shutter sound: " + error); });
    }

    function outputBaseName() {
        return new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd-hh-mm-ss");
    }

    function toggleRecording() {
        var videoPath = StorageLocations.videosLocation + "/" + outputBaseName() + ".mp4";
        if (useDroid) {
            if (DroidCameraFactory.recording)
                DroidCameraFactory.stopRecording();
            else
                DroidCameraFactory.startRecording(videoPath, cameraView.recordingRotation);
        } else if (captureSession && captureSession.recorder) {
            if (captureSession.recorder.recorderState === MediaRecorder.RecordingState)
                captureSession.recorder.stop();
            else
                captureSession.recorder.record();
        }
    }

    // The libcamera path has no flash control, so the LED is driven
    // directly: as a torch while a recording runs.
    Binding {
        target: FlashLed
        property: "on"
        value: overlay.prefs.videoLight
        when: overlay.recording && !overlay.useDroid
    }

    function takePicture() {
        var outputPath = StorageLocations.picturesLocation + "/" + outputBaseName();
        if (useDroid) {
            // Qt's QImageCapture never fires without a QCamera, so
            // full-resolution stills go through droidcamsrc directly. The
            // shutter sound plays when it actually fires (captureStarted),
            // which is after autofocus where that runs first.
            DroidCameraFactory.takePicture(outputPath + ".jpg");
        } else if (prefs.flashMode === "on" && FlashLed.available) {
            // Light the scene, give the exposure a few frames to
            // settle on it, then capture. CameraView switches the LED
            // off when the image is saved; the timer is the fallback.
            FlashLed.on = true;
            flashSettleTimer.outputPath = outputPath;
            flashSettleTimer.start();
        } else {
            playShutterSound();
            captureSession.imageCapture.captureToFile(outputPath);
        }
    }

    function shutterPressed() {
        if (videoMode) {
            toggleRecording();
            return;
        }
        if (selfTimer.running)
            return;
        selfTimer.startTimeout(prefs.selfTimerDelay, takePicture);
    }

    Connections {
        target: overlay.useDroid ? DroidCameraFactory : null
        function onCaptureStarted() { overlay.playShutterSound(); }
    }

    Timer {
        id: flashSettleTimer
        property string outputPath
        interval: 400
        onTriggered: {
            overlay.playShutterSound();
            captureSession.imageCapture.captureToFile(outputPath);
            flashOffTimer.start();
        }
    }

    Timer {
        id: flashOffTimer
        interval: 2000
        onTriggered: FlashLed.on = false
    }

    TimeoutTimerText {
        id: selfTimer
        anchors.centerIn: parent
    }

    /* How long the recording has run, for the timer on the bar. */
    property int recordingSeconds: 0
    onRecordingChanged: recordingSeconds = 0
    Timer {
        interval: 1000
        repeat: true
        running: overlay.recording
        onTriggered: overlay.recordingSeconds++
    }

    function formatDuration(seconds) {
        var m = Math.floor(seconds / 60);
        var s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    /* The flash modes the camera in use has, in the order the button steps
     * through them. */
    readonly property var flashModes: {
        var wanted = [ "auto", "on", "off" ];
        if (!useDroid)
            return FlashLed.available ? [ "on", "off" ] : [];
        if (!DroidCameraFactory.controlsReady)
            return [];
        return wanted.filter(function(m) {
            return DroidCameraFactory.supportedFlashModes.indexOf(m) >= 0;
        });
    }
    // The flash button: a choice of flash modes for photos, the light for videos.
    readonly property bool flashButtonShown: videoMode ? hasVideoLight : flashModes.length > 1
    readonly property bool hasVideoLight: useDroid ? flashModes.length > 0 : FlashLed.available

    function nextFlashMode() {
        var modes = flashModes;
        var i = modes.indexOf(prefs.flashMode);
        prefs.flashMode = modes[(i + 1) % modes.length];
    }

    /* The bar, laid out as for a tall window and turned a quarter to run down
     * a side edge; each button turns back, so its artwork stays upright. */
    Item {
        id: bar

        width: overlay.barUpright ? overlay.areaBottom - overlay.areaTop
                                  : overlay.areaRight - overlay.areaLeft
        height: overlay.barDepth
        rotation: overlay.barSide === "right" ? -90 : overlay.barSide === "left" ? 90 : 0
        x: overlay.barSide === "right" ? overlay.areaRight - height / 2 - width / 2
         : overlay.barSide === "left" ? overlay.areaLeft + height / 2 - width / 2 : overlay.areaLeft
        y: overlay.barUpright ? (overlay.areaTop + overlay.areaBottom) / 2 - height / 2
                              : overlay.areaBottom - height

        readonly property real upright: -rotation

        // The last capture, 70 px square in a frame of its own.
        Item {
            id: lastCapture

            property string path: ""

            x: Units.gu(2.25)
            anchors.verticalCenter: parent.verticalCenter
            width: Units.gu(10.5)
            height: width
            rotation: bar.upright
            visible: !overlay.recording

            ArtworkImage {
                anchors.centerIn: parent
                width: Units.gu(8.75)
                height: width
                svg: Qt.resolvedUrl("images/blank-thumbnail.svg")
            }
            Image {
                id: thumbnail
                anchors.centerIn: parent
                width: Units.gu(8.75)
                height: width
                fillMode: Image.PreserveAspectCrop
                // The JPEG is stored as the sensor sees it; its EXIF orientation turns it.
                autoTransform: true
                asynchronous: true
                sourceSize.width: Units.gu(16)
                // A recording has no picture to show.
                source: /\.jpe?g$/i.test(lastCapture.path) ? "file://" + lastCapture.path : ""
                visible: status === Image.Ready
            }
            SpriteButton {
                anchors.fill: parent
                image: "image-overlay"
                onClicked: overlay.galleryButtonClicked()
            }
        }

        // The bezel behind the shutter, widened to hold the flash button when there is one.
        // Without a flash (a camera with no flash modes, or video) it is the round one.
        ArtworkImage {
            id: bezel
            readonly property bool withFlash: !overlay.videoMode && overlay.flashButtonShown
            anchors.verticalCenter: parent.verticalCenter
            svg: Qt.resolvedUrl(withFlash ? "images/menu-bezel-camera.svg" : "images/bezel.svg")
            width: withFlash ? Units.gu(16.6) : Units.gu(10)
            height: withFlash ? Units.gu(9.5) : Units.gu(10)
            x: withFlash ? bar.width / 2 - Units.gu(4.6) : bar.width / 2 - width / 2
        }

        SpriteButton {
            id: shutter
            anchors.centerIn: parent
            width: Units.gu(10)
            height: width
            rotation: bar.upright
            image: !overlay.videoMode ? "shutter" : overlay.recording ? "stop" : "record"
            onClicked: overlay.shutterPressed()
        }

        // Flash for photos; the video light for videos.
        SpriteButton {
            anchors.verticalCenter: parent.verticalCenter
            x: bar.width / 2 + Units.gu(5.6)
            width: Units.gu(6.25)
            height: width
            rotation: bar.upright
            image: overlay.videoMode ? (prefs.videoLight ? "flash-on" : "flash-off")
                 : prefs.flashMode === "on" ? "flash-on" : prefs.flashMode === "auto" ? "flash-auto" : "flash-off"
            visible: overlay.flashButtonShown
            onClicked: {
                if (overlay.videoMode)
                    prefs.videoLight = !prefs.videoLight;
                else
                    overlay.nextFlashMode();
            }
        }

        // Photo / video.
        SpriteButton {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1.25)
            width: Units.gu(6.25)
            height: width
            rotation: bar.upright
            // Shows the mode a tap switches to.
            image: overlay.videoMode ? "mode-photo" : "mode-video"
            visible: !overlay.recording
            onClicked: prefs.captureMode = overlay.videoMode ? PreferencesModel.CaptureStillImage
                                                             : PreferencesModel.CaptureVideo
        }

        // How long the recording has run.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Units.gu(1.25)
            width: Units.gu(7.5)
            height: Units.gu(3.75)
            rotation: bar.upright
            visible: overlay.recording

            ArtworkImage {
                anchors.fill: parent
                svg: Qt.resolvedUrl("images/timer-background.svg")
            }
            Text {
                anchors.centerIn: parent
                color: "white"
                font.bold: true
                font.pixelSize: Units.gu(2.1)
                text: overlay.formatDuration(overlay.recordingSeconds)
            }
        }
    }

    // Preferences, in the top left corner, mirroring front / back; clear of a bar on the left.
    // Both corner buttons are the bar's black button with a white icon on it.
    SpriteButton {
        id: settingsButton
        x: overlay.areaLeft + (overlay.barSide === "left" ? overlay.barDepth : 0) + Units.gu(1.5)
        y: overlay.areaTop + Units.gu(1.5)
        width: Units.gu(6.25)
        height: width
        image: "round-button"
        visible: !overlay.recording
        onClicked: overlay.settingsButtonClicked()

        ArtworkImage {
            anchors.centerIn: parent
            width: Units.gu(3.25)
            height: width
            svg: Qt.resolvedUrl("images/settings.svg")
        }
    }

    // Front / back.
    SpriteButton {
        id: flipButton
        // Clear of the bar when it runs down the right edge.
        x: overlay.areaRight - (overlay.barSide === "right" ? overlay.barDepth : 0) - Units.gu(1.5) - width
        y: overlay.areaTop + Units.gu(1.5)
        width: Units.gu(6.25)
        height: width
        image: "round-button"
        visible: overlay.cameraCount > 1 && !overlay.recording
        onClicked: prefs.position = (prefs.position === CameraDevice.FrontFace)
                   ? CameraDevice.BackFace : CameraDevice.FrontFace

        ArtworkImage {
            anchors.centerIn: parent
            width: Units.gu(3.25)
            height: width
            // webOS's own circling arrows (the Pre3 email app's sync icon); the
            // legacy camera had no front / back switch to take them from.
            svg: Qt.resolvedUrl("images/icon-sync.svg")
        }
    }

    // Lens selector: switch between the cameras on the side currently shown
    // (e.g. the wide and the telephoto on the back). Only appears when this
    // side has more than one, below the Front/Back button. The badge shows
    // which of them is live (e.g. "1/2").
    SpriteButton {
        id: lensButton
        readonly property var sideCams: (overlay.cameraView && overlay.cameraView.sameSideDroidCameras)
                                        ? overlay.cameraView.sameSideDroidCameras : []
        readonly property int activeDevice: overlay.cameraView ? overlay.cameraView.droidCameraDevice : -1
        visible: sideCams.length > 1 && !overlay.recording
        x: flipButton.x
        y: flipButton.y + flipButton.height + Units.gu(1.5)
        width: Units.gu(6.25)
        height: width
        image: "round-button"
        onClicked: if (overlay.cameraView) overlay.cameraView.cycleDroidCamera()

        Text {
            anchors.centerIn: parent
            color: "white"
            font.bold: true
            font.pixelSize: Units.gu(2)
            // 1-based position of the active camera within this side's list.
            text: {
                var cams = lensButton.sideCams;
                for (var i = 0; i < cams.length; ++i) {
                    if (cams[i].index === lensButton.activeDevice)
                        return (i + 1) + "/" + cams.length;
                }
                return cams.length > 1 ? ("1/" + cams.length) : "";
            }
        }
    }

    // What is switched on that changes the picture, beside the settings button.
    // Tapping one switches it off again.
    Row {
        anchors {
            verticalCenter: settingsButton.verticalCenter
            left: settingsButton.right; leftMargin: Units.gu(1)
        }
        spacing: Units.gu(0.75)

        Repeater {
            model: {
                var badges = [];
                if (!overlay.videoMode && prefs.hdrEnabled && DroidCameraFactory.hdrSupported)
                    badges.push({ key: "hdr", text: "HDR" });
                if (prefs.gpsEnabled)
                    badges.push({ key: "gps", text: "GPS" });
                if (prefs.selfTimerDelay > 0 && !overlay.videoMode)
                    badges.push({ key: "timer", text: prefs.selfTimerDelay + "s" });
                if (cameraView && cameraView.zoomFactor > 1.001)
                    badges.push({ key: "zoom", text: cameraView.zoomFactor.toFixed(1) + "x" });
                return badges;
            }
            delegate: Rectangle {
                required property var modelData

                width: label.width + Units.gu(1.5)
                height: Units.gu(3)
                radius: height / 2
                color: badgeArea.pressed ? "#c0000000" : "#80000000"
                border.color: "#60ffffff"
                border.width: 1

                Text {
                    id: label
                    anchors.centerIn: parent
                    color: "white"
                    font.bold: true
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    text: modelData.text
                }

                MouseArea {
                    id: badgeArea
                    // A little beyond the badge, which is small to hit.
                    anchors { fill: parent; margins: -Units.gu(0.75) }
                    onClicked: overlay.switchOff(modelData.key)
                }
            }
        }
    }

    function switchOff(key) {
        if (key === "hdr")
            prefs.hdrEnabled = false;
        else if (key === "gps")
            prefs.gpsEnabled = false;
        else if (key === "timer")
            prefs.selfTimerDelay = 0;
        else if (key === "zoom" && cameraView)
            cameraView.setZoomFactor(1.0);
    }

    CodeBanner {
        id: codeBanner
        anchors.centerIn: parent
        width: Math.min(parent.width - Units.gu(3), Units.gu(40))
        onOpenRequested: (url) => overlay.codeOpenRequested(url)
    }
}
