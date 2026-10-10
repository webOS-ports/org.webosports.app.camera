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

    // Only a clearly wide window stands the bar up on the right. A square screen (the Q25's
    // 720x720, a little wider than tall once the status bar is off) keeps it at the bottom,
    // with the shutter in the middle, just above the keyboard.
    readonly property bool landscape: width > height * 1.2
    // The bar is 100 px deep.
    readonly property real barDepth: Units.gu(12.5)

    signal galleryButtonClicked()
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
    readonly property bool hasVideoLight: useDroid ? flashModes.length > 0 : FlashLed.available

    function nextFlashMode() {
        var modes = flashModes;
        var i = modes.indexOf(prefs.flashMode);
        prefs.flashMode = modes[(i + 1) % modes.length];
    }

    /* The bar, laid out as for a tall window and turned a quarter for a wide
     * one; each button turns back, so its artwork stays upright. */
    Item {
        id: bar

        width: overlay.landscape ? overlay.height : overlay.width
        height: overlay.barDepth
        rotation: overlay.landscape ? -90 : 0
        x: overlay.landscape ? overlay.width - height / 2 - width / 2 : 0
        y: overlay.landscape ? overlay.height / 2 - height / 2 : overlay.height - height

        readonly property real upright: overlay.landscape ? 90 : 0

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

        // The bezel behind the shutter (and, for photos, the flash).
        Image {
            id: bezel
            anchors.verticalCenter: parent.verticalCenter
            source: overlay.videoMode ? "images/legacy/menu-bezel-camcorder.png"
                                      : "images/legacy/menu-bezel-camera.png"
            width: overlay.videoMode ? Units.gu(10) : Units.gu(16.6)
            height: overlay.videoMode ? Units.gu(10) : Units.gu(9.5)
            x: overlay.videoMode ? bar.width / 2 - width / 2 : bar.width / 2 - Units.gu(4.6)
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
            visible: overlay.videoMode ? overlay.hasVideoLight : overlay.flashModes.length > 1
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

    // Front / back.
    Rectangle {
        id: flipButton
        // Clear of the bar, which runs down the right edge of a wide window.
        anchors {
            top: parent.top; right: parent.right; margins: Units.gu(1.5)
            rightMargin: overlay.landscape ? overlay.barDepth + Units.gu(1.5) : Units.gu(1.5)
        }
        width: Units.gu(6)
        height: width
        radius: width / 2
        color: flipArea.pressed ? "#c0000000" : "#80000000"
        border.color: "#80ffffff"
        border.width: 1
        visible: overlay.cameraCount > 1 && !overlay.recording

        Image {
            anchors.centerIn: parent
            width: Units.gu(3.5)
            height: width
            sourceSize.width: width
            source: "images/flipcamera.svg"
        }
        MouseArea {
            id: flipArea
            anchors.fill: parent
            onClicked: prefs.position = (prefs.position === CameraDevice.FrontFace)
                       ? CameraDevice.BackFace : CameraDevice.FrontFace
        }
    }

    // What is switched on that changes the picture.
    Row {
        anchors { top: parent.top; left: parent.left; margins: Units.gu(1.5) }
        spacing: Units.gu(0.75)

        Repeater {
            model: {
                var badges = [];
                if (!overlay.videoMode && prefs.hdrEnabled && DroidCameraFactory.hdrSupported)
                    badges.push("HDR");
                if (prefs.gpsEnabled)
                    badges.push("GPS");
                if (prefs.selfTimerDelay > 0 && !overlay.videoMode)
                    badges.push(prefs.selfTimerDelay + "s");
                if (cameraView && cameraView.zoomFactor > 1.001)
                    badges.push(cameraView.zoomFactor.toFixed(1) + "x");
                return badges;
            }
            delegate: Rectangle {
                width: label.width + Units.gu(1.5)
                height: Units.gu(3)
                radius: height / 2
                color: "#80000000"
                border.color: "#60ffffff"
                border.width: 1

                Text {
                    id: label
                    anchors.centerIn: parent
                    color: "white"
                    font.bold: true
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    text: modelData
                }
            }
        }
    }

    CodeBanner {
        id: codeBanner
        anchors.centerIn: parent
        width: Math.min(parent.width - Units.gu(3), Units.gu(40))
        onOpenRequested: (url) => overlay.codeOpenRequested(url)
    }
}
