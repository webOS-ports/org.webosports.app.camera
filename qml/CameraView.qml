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

    // On Halium devices the cameras sit behind the Android HAL and are not
    // enumerable through MediaDevices; gst-droid's droidcamsrc is the way in.
    property bool useDroidCamera: DroidCameraFactory.available
    // Android convention: device 0 = back camera, 1 = front. The Front/Back
    // switcher writes prefs.position, so follow it here; the
    // onDroidCameraDeviceChanged handler below recreates the source.
    property int droidCameraDevice: prefs && prefs.position === CameraDevice.FrontFace ? 1 : 0

    function attachDroidCamera() {
        // Release the previous camera before opening the other sensor:
        // some HALs will not run both simultaneously.
        if (captureSession.nativeVideoSource)
            captureSession.nativeVideoSource.stop();
        var source = DroidCameraFactory.createVideoSource(droidCameraDevice);
        if (source) {
            captureSession.camera = null;
            captureSession.nativeVideoSource = source;
            source.start();
        }
    }

    Component.onCompleted: {
        if (useDroidCamera)
            attachDroidCamera();
    }

    Connections {
        target: DroidCameraFactory
        enabled: cameraViewRoot.useDroidCamera
        function onImageSaved(path) {
            cameraViewRoot.captureDone(path);
        }
        function onImageCaptureError(message) {
            console.warn("droid capture failed: " + message);
        }
    }

    onDroidCameraDeviceChanged: {
        if (useDroidCamera)
            attachDroidCamera();
    }

    // Only instantiated off the droid path: enumerating video inputs makes
    // Qt's GStreamer backend start a v4l2 device monitor that probes every
    // /dev/video node in-process. On QCOM those are the camera HAL's own
    // CSL kernel nodes, and probing them corrupts the vendor HAL's session
    // - CamX then fails startPreview with a kernel-level sensor-acquire
    // error. droidcamsrc is not enumerable anyway.
    Loader {
        id: mediaDevicesLoader
        active: !cameraViewRoot.useDroidCamera
        sourceComponent: MediaDevices {}
    }

    // The V4L2 camera is only instantiated off the droid path: even
    // constructing a QCamera makes the backend enumerate video devices,
    // which starts the v4l2 monitor (see mediaDevicesLoader above).
    Loader {
        id: cameraLoader
        active: !cameraViewRoot.useDroidCamera
        sourceComponent: Camera {
            id: camera

            cameraDevice: mediaDevicesLoader.item ? mediaDevicesLoader.item.defaultVideoInput : undefined
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

                // The droid video source replaces this camera entirely.
                if (cameraViewRoot.useDroidCamera)
                    return;

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
    }

    CaptureSession {
        id: captureSession
        camera: cameraLoader.item
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
