import QtQuick 2.6
import QtMultimedia

import LunaNext.Common 0.1

import CameraApp 0.1
import LuneOS.Camera 1.0
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

    // QVideoFrameFormat::PixelFormat is not reachable from QML in Qt 6.12 -
    // VideoFrameFormat, CameraFormat and QVideoFrameFormat are all undefined
    // here - so the values we need are spelled out. Best first. Format_Y8 (24)
    // and Format_Y16 (25) are greyscale and deliberately absent.
    // YUV420P (I420) first, and NV12 deliberately last.
    //
    // Measured on a PinePhone Pro: I420 negotiates and renders a correct,
    // full-colour viewfinder. NV12 does not - it fails negotiation and the
    // preview falls back to a greyscale image tiled two or three times across
    // the screen, which is what this same app did before any of this was
    // touched. The semi-planar layouts are therefore ranked below the planar
    // ones here, which is the opposite of what one would normally expect.
    // Ranking here is by how Qt's GStreamer backend IMPORTS the buffer, not by
    // anything the camera does. libcamerasrc hands Qt dmabuf memory, and Qt's
    // dmabuf import (qgstvideobuffer.cpp, mapFromDmaBuffer) handles the layouts
    // very differently. Measured on this device against a neutral scene that
    // libcamera itself renders as R=74.7 G=72.9 B=74.1:
    //
    //   GRAY8  1 plane   -> correct, but greyscale by definition
    //   I420   3 planes  -> converts, but green: R=67.0 G=115.2 B=60.9
    //   YUYV   1 packed  -> catastrophic: blue channel identically 0
    //
    // YUYV is the worst of the three and must never be picked: Qt maps it to
    // DRM_FORMAT_YUYV, which yields a YUV EGLImage that has to be sampled with
    // samplerExternalOES, yet Qt binds a plain sampler2D (externalOes: false in
    // its own log). The result is the raw planes painted straight into RGB.
    // I420 is the least broken of the colour layouts, so it leads.
    readonly property var preferredPixelFormats: [
        13, // Format_YUV420P (I420) - converts; still a green cast, see above
        15, // Format_YV12    - same planar layout, U/V swapped
        14, // Format_YUV422P
        19, // Format_NV21
        18, // Format_NV12
        17  // Format_YUYV    - LAST: packed YUV import is broken here
    ]

    // The viewfinder is 720x1440; there is nothing to gain from running the
    // ISP at the full 3264x2448 sensor just to fill it.
    readonly property size maxPreviewResolution: Qt.size(1280, 720)

    // Neither the app's old videoFormats[0] nor Qt's own findBestCameraFormat()
    // yields a colour format here. libcamerasrc reports maxFrameRate = 0 for
    // every format, which flattens Qt's 1st, 2nd and 5th ranking criteria to a
    // tie; cameraPixelFormatScore() is a virtual returning 0 that only the
    // Darwin backend overrides, so the 4th ties too; and every pixel format
    // reaches the same maximum resolution, so the 3rd ties as well. With all
    // criteria equal std::max returns the first element, and libcamera
    // enumerates Format_Y8 first - hence a greyscale viewfinder either way.
    function pickCameraFormat(device) {
        if (!device)
            return undefined;

        var formats = device.videoFormats;
        if (!formats || formats.length === 0)
            return undefined;

        var best = null;
        var bestRank = -1;
        var bestArea = -1;

        for (var i = 0; i < formats.length; ++i) {
            var format = formats[i];
            var rank = preferredPixelFormats.indexOf(format.pixelFormat);
            if (rank < 0)
                continue;

            var width = format.resolution.width;
            var height = format.resolution.height;
            if (width > maxPreviewResolution.width || height > maxPreviewResolution.height)
                continue;

            var area = width * height;
            if (area > bestArea || (area === bestArea && rank < bestRank)) {
                best = format;
                bestArea = area;
                bestRank = rank;
            }
        }

        return best;
    }

    // Qt's libcamera backend enumerates the ISP's own /dev/video nodes
    // alongside the real sensors - six inputs on the PinePhone Pro, four of
    // them "rkisp1" entries whose largest format is 32x16 - and marks none of
    // them default, so defaultVideoInput is no use for choosing a side. Skip
    // the ISP nodes and match on position.
    function pickCameraDevice(mediaDevices, position) {
        if (!mediaDevices)
            return undefined;

        var inputs = mediaDevices.videoInputs;
        if (!inputs || inputs.length === 0)
            return undefined;

        var cameras = [];
        for (var i = 0; i < inputs.length; ++i) {
            if (inputs[i].description.indexOf("rkisp1") !== 0)
                cameras.push(inputs[i]);
        }
        if (cameras.length === 0)
            cameras = inputs;

        // Use the backend's own answer whenever it gives one.
        for (var j = 0; j < cameras.length; ++j) {
            if (cameras[j].position === position)
                return cameras[j];
        }

        // Otherwise fall back to enumeration order. libcamera does know which
        // sensor is which - cam -l names them "Internal front camera" and
        // "Internal back camera" - but Qt 6.12 does not carry that through.
        // On the PinePhone Pro the order is front (camera@36) then back
        // (camera@1a).
        if (cameras.length > 1)
            return position === CameraDevice.FrontFace ? cameras[0] : cameras[1];

        return cameras[0];
    }

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
        function onVideoSaved(path) {
            cameraViewRoot.captureDone(path);
        }
        function onVideoCaptureError(message) {
            console.warn("droid recording failed: " + message);
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

            // Follow the Front/Back switcher. defaultVideoInput cannot do this:
            // it is a single fixed device, so the switcher had nothing to act
            // on. pickCameraDevice() matches on QCameraDevice::position, which
            // Qt now reports for libcamera devices (it maps the sensor's
            // api.libcamera.Location property), and falls back to enumeration
            // order if a backend ever leaves the position unspecified.
            cameraDevice: cameraViewRoot.pickCameraDevice(mediaDevicesLoader.item,
                                                          prefs.position)

            // Deliberately NOT a cameraFormat binding. Assigning the format
            // while the Camera is being constructed runs QGstreamerCamera's
            // updateCamera() before camerabin has been parented into a
            // GstPipeline, so its getPipeline() returns null:
            //
            //   QGstElement::getPipeline failed for element: videoConvert
            //
            // and the READY/PLAYING bracketing around the unlink - set caps -
            // relink dance is skipped. libcamerasrc then negotiates mid-change
            // and gives up with
            //
            //   gst_libcamera_src_task_enter(): streaming stopped,
            //   reason not-negotiated (-4)
            //
            // Greyscale survives that because it is a single plane; every
            // colour format does not. Applying the format once the camera is
            // active means the bin is in a pipeline and the state bracketing
            // actually happens.
            property bool cameraFormatApplied: false

            function applyPreferredFormat() {
                if (!active || cameraFormatApplied)
                    return;

                var format = cameraViewRoot.pickCameraFormat(cameraDevice);
                if (!format) {
                    console.warn("no colour camera format available; leaving Qt's default");
                    return;
                }

                cameraFormatApplied = true;
                console.warn("applying camera format pf=" + format.pixelFormat
                             + " " + format.resolution.width + "x" + format.resolution.height);
                camera.cameraFormat = format;
            }

            // Qt now ranks pixel formats itself and opens the camera in
            // colour, so the format only needs correcting if it somehow still
            // comes up monochrome. Re-assigning cameraFormat tears the camera
            // down and rebuilds it, and doing that on top of a sensor switch
            // reconfigures the pipeline three times in about a second, which
            // it does not survive - so only do it when it is actually needed.
            onActiveChanged: {
                if (active)
                    Qt.callLater(camera.applyPreferredFormatIfMono);
            }

            onCameraDeviceChanged: {
                cameraFormatApplied = false;
            }

            function applyPreferredFormatIfMono() {
                if (!active || cameraFormatApplied)
                    return;

                var current = camera.cameraFormat;
                if (current && current.pixelFormat !== 24 /* Y8 */
                            && current.pixelFormat !== 25 /* Y16 */) {
                    cameraFormatApplied = true; // already colour, leave it alone
                    return;
                }

                applyPreferredFormat();
            }

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
