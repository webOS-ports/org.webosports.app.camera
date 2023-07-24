import QtQuick 2.6
import QtMultimedia

import LunaNext.Common 0.1

import CameraApp 0.1
import "components"

Item {
    id: cameraViewRoot

    signal imageCaptured(variant preview);
    signal captureDone(string filepath);
    signal galleryButtonClicked();

    property PreferencesModel prefs;
    property alias captureSessionItem: captureSession

    MediaDevices {
        id: mediaDevices
    }

    CaptureSession {
        id: captureSession
        camera: Camera {
            id: camera

            cameraDevice: mediaDevices.defaultVideoInput
            cameraFormat: cameraDevice.videoFormats[0]

            flashMode: camera.captureMode === PreferencesModel.CaptureStillImage ? prefs.flashMode :
                       camera.captureMode === PreferencesModel.CaptureVideo ? prefs.videoFlashMode :
                            Camera.FlashOff

            focusMode: Camera.FocusModeAuto
            whiteBalanceMode: Camera.WhiteBalanceAuto
            exposureMode: Camera.ExposureAuto

            property AdvancedCameraSettings advanced: AdvancedCameraSettings {
                captureSession: captureSession
                hdrEnabled: prefs.hdrEnabled
                encodingQuality: prefs.encodingQuality
                /*
                onVideoSupportedResolutionsChanged: prefs.updateVideoResolutionOptions(camera.advanced.videoSupportedResolutions);
                onFittingResolutionChanged: prefs.updatePhotoResolutionOptions(camera.advanced.maximumResolution, camera.advanced.fittingResolution);
                onMaximumResolutionChanged: prefs.updatePhotoResolutionOptions(camera.advanced.maximumResolution, camera.advanced.fittingResolution);
                */
            }

            function updateResolutionOptions() {
                prefs.updateVideoResolutionOptions(camera.advanced.videoSupportedResolutions);
                prefs.updatePhotoResolutionOptions(camera.advanced.maximumResolution, camera.advanced.fittingResolution);
                // FIXME: see workaround setting camera.viewfinder.resolution above
                camera.cameraFormat.resolution = camera.advanced.resolution;
            }


            Component.onCompleted: {
                //updateResolutionOptions();

                console.log("cameraDevice: " + JSON.stringify(camera.cameraDevice));
                console.log("camera format: " + JSON.stringify(camera.cameraFormat));
                start();
            }

            onErrorChanged: {
                if(camera.error === Camera.CameraError) {
                    console.warn("Camera ERROR: " + camera.errorString);
                }
            }

            /*
              // TODO
            captureMode: prefs.captureMode
            position: prefs.position

            imageProcessing {
                colorFilter: CameraImageProcessing.ColorFilterGrayscale
                contrast: 0.66
                saturation: -0.5
            }
            */
       }
        imageCapture: ImageCapture {
            id: imageCapture

            // resolution: prefs.photoResolutionOptionsModel.getAsSize(prefs.photoResolutionIndex)

            onResolutionChanged: {
                // FIXME: this is a necessary workaround because:
                // - Neither camera.viewfinder.resolution nor camera.advanced.resolution
                //   emit a changed signal when the underlying AalViewfinderSettingsControl's
                //   resolution changes
                // - we know that qtubuntu-camera changes the resolution of the
                //   viewfinder automatically when the capture resolution is set
                // - we need camera.viewfinder.resolution to hold the right
                //   value
                camera.viewfinder.resolution = camera.advanced.resolution;
            }

            onImageCaptured: (requestId, previewImage) => {
                cameraViewRoot.imageCaptured(previewImage)
            }
            onImageSaved: (requestId, path) => {
                cameraViewRoot.captureDone(path);
            }
        }

        recorder: MediaRecorder {
            id: recorder

            outputLocation: StorageLocations.videosLocation;

            /* TODO
            resolution: prefs.videoResolutionOptionsModel.getAsSize(prefs.videoResolutionIndex)

            onResolutionChanged: {
                // FIXME: see workaround setting camera.viewfinder.resolution above
                camera.viewfinder.resolution = camera.advanced.resolution;
            }
            */
        }
        videoOutput: videoOutputView
    }

    VideoOutput {
        id: videoOutputView
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop

        //orientation: camera.position === Camera.BackFace ? -camera.orientation : camera.orientation
    }
    GridLines {
        anchors.fill: parent
        visible: prefs.gridEnabled
    }
}
