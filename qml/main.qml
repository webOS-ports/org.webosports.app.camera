import QtQuick
import QtQuick.Controls
import Eos.Window 0.1

import "components"

WebOSWindow {
    visible: true

    width: 600
    height: 800

    PreferencesModel {
        id: preferences
    }
    /* Model of the captured phots/videos during this session */
    ListModel {
        id: capturedFilesModel

        function addFileToGallery(iPath)
        {
            capturedFilesModel.append({filepath: iPath});
            console.log("file added: "+iPath);
        }
    }

    CameraView {
        id: cameraViewItem

        width: parent.width
        height: parent.height

        prefs: preferences

        //onImageCaptured: (preview) => { captureOverlayItem.setLastCapturedImage(preview); }
        onCaptureDone: (filepath) => {
                           captureOverlayItem.setLastCapturedImage(filepath);
                           capturedFilesModel.addFileToGallery(filepath);
                       }
    }

    SwipeView {
        id: switcherListView

        currentIndex: 0

        width: parent.width
        height: parent.height

        /* Nothing to drive while the camera is off, and a shutter button
         * showing through the notice just looks broken. */
        visible: !killSwitchNotice.blocked

        CaptureOverlay {
            id: captureOverlayItem

            captureSession: cameraViewItem.captureSessionItem
            cameraCount: cameraViewItem.cameraCount
            prefs: preferences

    //        onGalleryButtonClicked: switcherListView.currentIndex = 2
        }

        PreferencesView {
            id: preferencesOverlay

            prefs: preferences
        }
    }

    /* Last, so it covers the viewfinder and the capture controls alike. */
    /*
     * No attempt to re-open the camera when the switch is released. The app
     * cannot rebuild a live preview from a second source at all - the
     * front/back switcher freezes on the last frame in exactly the same way,
     * with the kill switch untouched - so anything here would be inheriting a
     * separate, pre-existing bug rather than fixing one. The camera returns on
     * the next launch; the notice disappearing is honest about the switch.
     */
    KillSwitchNotice {
        id: killSwitchNotice
    }
}
