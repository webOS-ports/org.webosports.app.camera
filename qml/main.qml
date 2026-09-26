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
    KillSwitchNotice {
        id: killSwitchNotice

        /* The HAL is stopped while the switch is on and the camera source does
         * not survive it, so ask for a fresh one once it is released. */
        onBlockedChanged: {
            if (!blocked)
                cameraViewItem.reopenCamera();
        }
    }
}
