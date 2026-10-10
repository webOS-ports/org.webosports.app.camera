import QtQuick 2.6
import QtCore
import QtMultimedia

// Qualified: QtCore has a Settings type of its own, which this file is.
import LunaNext.Common 0.1 as Common

/*
 * The camera's preferences, kept across launches.
 *
 * Mode values (flash, focus, white balance, scene, colour effect, flicker) are
 * the names LuneOS.Camera's DroidCameraFactory uses - the Android camera
 * parameter values - so they bind to it as they are. A value the camera in use
 * does not support is kept and simply not applied; the preferences page only
 * offers what it supports.
 */
Settings {
    id: settings

    enum CaptureMode {
        CaptureStillImage,
        CaptureVideo
    }

    // Not a QSettings organisation/application pair: the QML runner is shared
    // by every QML app, so the file is named explicitly.
    location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
              + "/org.webosports.app.camera/preferences.ini"
    category: "camera"

    property int position: CameraDevice.BackFace
    /* Which HAL camera to use, for phones with more than one on a side
     * (ultra-wide, tele). -1: the HAL's first camera facing that way. */
    property int droidCameraIndex: -1
    property int captureMode: PreferencesModel.CaptureStillImage

    property string flashMode: "auto"
    property bool videoLight: false
    property string focusMode: "continuous"
    property string whiteBalanceMode: "auto"
    property string sceneMode: "auto"
    property string colorTone: "none"
    property string flickerMode: "auto"
    property int isoSpeed: 0
    property real exposureCompensation: 0
    property bool hdrEnabled: false
    property bool zslEnabled: true

    property int selfTimerDelay: 0
    property bool gridEnabled: false
    property bool playShutterSound: true
    property bool gpsEnabled: false
    property bool scanCodes: true

    // Fallback mounting rotation, in degrees relative to the screen's native
    // (primary) orientation, used ONLY when the device tree does not declare a
    // per-sensor "rotation". The real value now comes from the board itself:
    // CameraView reads LuneOS.Camera CameraInfo.rotation(cameraId), the same
    // device-tree property libcamera uses, so devices that declare it (e.g. the
    // PinePhone Pro: rear 270, front 90) are correct with no hardcoding here.
    // The PineTab 2's sensors do not yet carry a DT rotation; they are mounted
    // along the long edge for landscape use, a quarter turn away, hence 270
    // (90 showed the image upside down). Once measured and added to the PT2 DT
    // these fallbacks can go.
    readonly property int backSensorRotation: Common.Settings.tabletUi ? 270 : 0
    readonly property int frontSensorRotation: Common.Settings.tabletUi ? 270 : 0

    // The flash and the HAL's HDR merge do not go together: one flash cannot
    // light every frame of a merge, and HALs refuse the combination.
    onFlashModeChanged: if (flashMode === "on") hdrEnabled = false
    onHdrEnabledChanged: if (hdrEnabled && flashMode === "on") flashMode = "off"
}
