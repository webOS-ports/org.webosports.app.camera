import QtQuick 2.6
import QtMultimedia

import "components"

// The goal of this object is to handle the storage of the settings, and
// keep them in sync with the camera state
QtObject {
    id: settings

    enum CaptureMode {
        CaptureStillImage,
        CaptureVideo
    }

    property int position: CameraDevice.BackFace
    property int captureMode: PreferencesModel.CaptureStillImage
    property int flashMode: Camera.FlashAuto
    property int videoFlashMode: Camera.FlashOff
    property bool gpsEnabled: false
    property bool hdrEnabled: false
    property int selfTimerDelay: 0
    property int photoResolutionIndex: 0
    property int videoResolutionIndex: 0
    property int encodingQuality: 2 // QMultimedia.NormalQuality
    property bool gridEnabled: false
    property bool preferRemovableStorage: false
    property bool playShutterSound: true

    property ResolutionsListModel photoResolutionOptionsModel: ResolutionsListModel {}
    property ResolutionsListModel videoResolutionOptionsModel: ResolutionsListModel {}

    onFlashModeChanged: if (flashMode != Camera.FlashOff) hdrEnabled = false;
    onHdrEnabledChanged: if (hdrEnabled) flashMode = Camera.FlashOff

    function getAutomaticResolutionIndex(fittingResolution, maximumResolution) {
        var fittingResolutionIndex = photoResolutionOptionsModel.indexOf(fittingResolution);
        if (fittingResolutionIndex >= 0) {
            return fittingResolutionIndex;
        } else {
            return photoResolutionOptionsModel.indexOf(maximumResolution);
        }
    }

    function isWellKnown(resolution) {
        // Try to only display well known resolutions: 1080p, 720p and 480p
        return ( resolution === Qt.size(1920,1080) ||
                 resolution === Qt.size(1280,720)  ||
                 resolution === Qt.size(640,480) );
    }

    function updateVideoResolutionOptions(videoSupportedResolutions) {
        // Remember what was the resolution before the update
        var previousVideoResolution = videoResolutionOptionsModel.get(settings.videoResolutionIndex);

        // Clear and refill videoResolutionOptionsModel with available resolutions
        videoResolutionOptionsModel.clear();
        var supported = videoSupportedResolutions;

        supported = supported.slice().sort(function(a, b) {
            return a.width - b.width;
        });

        var foundCurrentResolution = -1;
        for (var i=0; i<supported.length; i++) {
            if (isWellKnown(supported[i])) {
                videoResolutionOptionsModel.insertSize(0, supported[i]);
                if(previousVideoResolution === supported[i]) foundCurrentResolution = i;
            }
        }

        // If resolution setting chosen is not supported select the highest available resolution
        if (supported.length > 0 && foundCurrentResolution < 0) {
            settings.videoResolutionIndex = supported.count - 1;
        }

        videoResolutionOptionsModel.modelChanged();
    }

    function updatePhotoResolutionOptions(maximumResolution, fittingResolution) {
        // Remember what was the resolution before the update
        var previousPhotoResolution = photoResolutionOptionsModel.get(settings.photoResolutionIndex);

        // Clear and refill photoResolutionOptionsModel with available resolutions
        photoResolutionOptionsModel.clear();
/*
        var optionMaximum = {"icon": "",
                             "label": "%1 (%2MP)".arg(sizeToAspectRatio(maximumResolution))
                                                 .arg(sizeToMegapixels(maximumResolution)),
                             "value": sizeToString(maximumResolution)};

        var optionFitting = {"icon": "",
                             "label": "%1 (%2MP)".arg(sizeToAspectRatio(fittingResolution))
                                                 .arg(sizeToMegapixels(fittingResolution)),
                             "value": sizeToString(fittingResolution)};
*/
        photoResolutionOptionsModel.appendSize(maximumResolution);


        // Only show optionFitting if it's greater than 50% of the maximum available resolution
        var fittingSize = fittingResolution.width * fittingResolution.height;
        var maximumSize = maximumResolution.width * maximumResolution.height;
        if (fittingResolution !== maximumResolution &&
            fittingSize / maximumSize >= 0.5) {
            photoResolutionOptionsModel.appendSize(fittingResolution);
        }

        // If resolution setting is not supported select the resolution automatically
        settings.photoResolutionIndex = photoResolutionOptionsModel.indexOf(previousPhotoResolution);
        if (settings.photoResolutionIndex < 0) {
            settings.photoResolutionIndex = getAutomaticResolutionIndex(maximumResolution, fittingResolution);
        }

        photoResolutionOptionsModel.modelChanged();
    }

}
