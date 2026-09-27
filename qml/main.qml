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

        /* Keep covering the viewfinder until frames are actually flowing, so
         * the notice hands straight over to "starting" instead of uncovering a
         * black rectangle. Covers the wait for the hardware too, which is the
         * longer half of it. */
        preparing: hardwarePending || cameraViewItem.previewStarting

        /* The HAL is stopped while the switch is on and the camera source does
         * not survive it, so ask for a fresh one once it is released - but only
         * once the service says the hardware is actually ready. Attaching while
         * it is not blocks inside the HAL and freezes the UI, so waiting is
         * what keeps the "starting" spinner moving. */
        onBlockedChanged: reopenWhenReady()
        onHardwarePendingChanged: reopenWhenReady()

        function reopenWhenReady() {
            if (!blocked && !hardwarePending)
                cameraViewItem.reopenCamera();
        }
    }
}
