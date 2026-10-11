import QtQuick 2.6
import QtMultimedia

import LunaNext.Common 0.1
import LuneOS.Service 1.0

import CameraApp 0.1
import LuneOS.Camera 1.0
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
            if (captureSession.recorder.recorderState === MediaRecorder.RecordingState) {
                captureSession.recorder.stop();
                FlashLed.on = false;
            } else {
                // The libcamera path has no flash control, so the LED is
                // driven directly: as a torch for the whole recording.
                FlashLed.on = prefs.videoLight;
                captureSession.recorder.record();
            }
        }
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

        width: overlay.barUpright ? overlay.height : overlay.width
        height: overlay.barDepth
        rotation: overlay.barSide === "right" ? -90 : overlay.barSide === "left" ? 90 : 0
        x: overlay.barSide === "right" ? overlay.width - height / 2 - width / 2
         : overlay.barSide === "left" ? height / 2 - width / 2 : 0
        y: overlay.barUpright ? overlay.height / 2 - height / 2 : overlay.height - height

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

            Image {
                anchors.centerIn: parent
                width: Units.gu(8.75)
                height: width
                source: "images/legacy/blank-thumbnail.png"
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
                source: Qt.resolvedUrl("images/legacy/image-overlay.png")
                frames: 2
                onClicked: overlay.galleryButtonClicked()
            }
        }

        // The bezel behind the shutter, widened to hold the flash button when there is one.
        // Without a flash (a camera with no flash modes, or video) it is the round one.
        Image {
            id: bezel
            readonly property bool withFlash: !overlay.videoMode && overlay.flashButtonShown
            anchors.verticalCenter: parent.verticalCenter
            source: withFlash ? "images/legacy/menu-bezel-camera.png"
                              : "images/legacy/menu-bezel-camcorder.png"
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
            source: Qt.resolvedUrl("images/legacy/capture-buttons.png")
            frames: 6
            frame: !overlay.videoMode ? 0 : overlay.recording ? 4 : 2
            onClicked: overlay.shutterPressed()
        }

        // Flash for photos; the video light for videos.
        SpriteButton {
            anchors.verticalCenter: parent.verticalCenter
            x: bar.width / 2 + Units.gu(5.6)
            width: Units.gu(6.25)
            height: width
            rotation: bar.upright
            source: Qt.resolvedUrl("images/legacy/flash-buttons.png")
            frames: 6
            visible: overlay.flashButtonShown
            frame: overlay.videoMode ? (prefs.videoLight ? 2 : 0)
                 : prefs.flashMode === "on" ? 2 : prefs.flashMode === "auto" ? 4 : 0
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
            source: Qt.resolvedUrl("images/legacy/toggle-buttons.png")
            frames: 4
            frame: overlay.videoMode ? 2 : 0
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

            Image {
                anchors.fill: parent
                source: "images/legacy/timer-background.png"
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
        anchors {
            top: parent.top; left: parent.left; margins: Units.gu(1.5)
            leftMargin: overlay.barSide === "left" ? overlay.barDepth + Units.gu(1.5) : Units.gu(1.5)
        }
        width: Units.gu(6.25)
        height: width
        source: Qt.resolvedUrl("images/legacy/blank-button.png")
        frames: 2
        visible: !overlay.recording
        onClicked: overlay.settingsButtonClicked()

        Image {
            anchors.centerIn: parent
            width: Units.gu(3.25)
            height: width
            sourceSize.width: width
            source: "images/settings.svg"
        }
    }

    // Front / back.
    SpriteButton {
        id: flipButton
        // Clear of the bar when it runs down the right edge.
        anchors {
            top: parent.top; right: parent.right; margins: Units.gu(1.5)
            rightMargin: overlay.barSide === "right" ? overlay.barDepth + Units.gu(1.5) : Units.gu(1.5)
        }
        width: Units.gu(6.25)
        height: width
        source: Qt.resolvedUrl("images/legacy/blank-button.png")
        frames: 2
        visible: overlay.cameraCount > 1 && !overlay.recording
        onClicked: prefs.position = (prefs.position === CameraDevice.FrontFace)
                   ? CameraDevice.BackFace : CameraDevice.FrontFace

        Image {
            anchors.centerIn: parent
            width: Units.gu(3.25)
            height: width
            sourceSize.width: width
            // webOS's own circling arrows (the Pre3 email app's sync icon); the
            // legacy camera had no front / back switch to take them from.
            source: "images/legacy/icon-sync.png"
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
