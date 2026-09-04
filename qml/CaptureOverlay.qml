import QtQuick 2.6
import QtMultimedia

import LunaNext.Common 0.1

import CameraApp 0.1
import LuneOS.Camera 1.0
import "components"

Item {
    property CaptureSession captureSession

    property QtObject prefs;
    property int captureTimeout: prefs.selfTimerDelay

    signal galleryButtonClicked();

    function setLastCapturedImage(preview) {
        lastCaptureImage.source = preview
    }

    function startCapture() {
        var outputPath =  StorageLocations.picturesLocation;
        var dateAsString = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd-hh-mm-ss");
        outputPath += "/" + dateAsString;

        console.log("image storage : " + outputPath);

        if (prefs.captureMode === PreferencesModel.CaptureVideo) {
            var videoPath = StorageLocations.videosLocation + "/" + dateAsString + ".mp4";
            if (DroidCameraFactory.available) {
                if (DroidCameraFactory.recording)
                    DroidCameraFactory.stopRecording();
                else
                    DroidCameraFactory.startRecording(videoPath);
            } else if (captureSession.recorder) {
                if (captureSession.recorder.recorderState === MediaRecorder.RecordingState)
                    captureSession.recorder.stop();
                else
                    captureSession.recorder.record();
            }
            return;
        }

        // start he capture !capture the image!
        timeOutTimer.startTimeout(captureTimeout, function() {
                if (DroidCameraFactory.available) {
                    // Qt's QImageCapture never fires without a QCamera, so
                    // full-resolution stills go through droidcamsrc directly.
                    DroidCameraFactory.takePicture(outputPath + ".jpg");
                } else {
                    captureSession.imageCapture.captureToFile(outputPath);
                }
            }
        );
    }

    TimeoutTimerText {
        id: timeOutTimer
        anchors.centerIn: parent
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        height: Units.gu(6)

        ExclusiveGroup {
            id: exclusiveGroupPhotoVideo
            readonly property var prefsMapping: [ PreferencesModel.CaptureStillImage, PreferencesModel.CaptureVideo ]
            currentIndexInGroup: prefsMapping.indexOf(prefs.captureMode);
            onCurrentIndexInGroupChanged: prefs.captureMode = prefsMapping[currentIndexInGroup]
        }
        Repeater {
            model: [ Qt.resolvedUrl("images/shutter_stills@27.png"), Qt.resolvedUrl("images/record_video@27.png") ]
            delegate: LuneOSButtonElement {
            height: parent.height
                width: parent.height
                imageSource: modelData
                group: exclusiveGroupPhotoVideo
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        Item {
            height: Units.gu(8);
            width: Units.gu(8);
            Image {
                id: lastCaptureImage
                anchors.fill: parent
                visible: false
            }
            CornerShader {
                id: cornerShader
                z: 2 // above image
                anchors.fill: lastCaptureImage
                sourceItem: lastCaptureImage
                radius: 5*lastCaptureImage.height/90
            }
            MouseArea {
                anchors.fill: parent
                onClicked: galleryButtonClicked();
            }
        }

        // take a photo / toggle recording
        Image {
            source: "images/shutter.svg"
            height: Units.gu(8);
            width: Units.gu(8);
            Rectangle {
                // recording indicator: the shutter pulses red while rolling
                anchors.centerIn: parent
                width: parent.width * 0.5; height: width; radius: width / 2
                color: "#e0342f"
                visible: DroidCameraFactory.recording
                SequentialAnimation on opacity {
                    running: DroidCameraFactory.recording
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.4; duration: 600 }
                    NumberAnimation { from: 0.4; to: 1.0; duration: 600 }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    startCapture();
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        height: Units.gu(6)

        ExclusiveGroup {
            id: exclusiveGroupSide
            readonly property var prefsMapping: [ CameraDevice.FrontFace, CameraDevice.BackFace ]
            currentIndexInGroup: prefsMapping.indexOf(prefs.position);
            onCurrentIndexInGroupChanged: prefs.position = prefsMapping[currentIndexInGroup]
        }
        Repeater {
            model: [ "Front", "Back" ]
            delegate: LuneOSButtonElement {
                height: parent.height
                width: Units.gu(6)
                imageSource: ""; text: modelData
                group: exclusiveGroupSide
            }
        }
    }
}
