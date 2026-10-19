pragma Singleton
import QtQuick

// What the camera QML reads of the droidmedia camera. Unavailable unless a
// test switches it on; focusAt() and resetFocus() are recorded.
QtObject {
    enum FocusStatus { FocusIdle, FocusRunning, FocusSucceeded, FocusFailed }

    property bool available: false
    property bool recording: false
    property bool controlsReady: false
    property bool focusAreasSupported: false
    property int focusStatus: 0
    property int cameraCount: 0
    property real maximumZoom: 1.0
    property real zoom: 1.0
    property bool hdrSupported: false
    property bool zslSupported: false
    property real exposureCompensationStep: 0
    property real minimumExposureCompensation: 0
    property real maximumExposureCompensation: 0
    property real appliedExposureCompensation: 0
    property var supportedFlashModes: []
    property var supportedFocusModes: []
    property var supportedWhiteBalanceModes: []
    property var supportedSceneModes: []
    property var supportedColorTones: []
    property var supportedFlickerModes: []
    property var supportedIsoSpeeds: []
    property string flashMode
    property bool torch: false
    property string focusMode
    property string whiteBalanceMode
    property string sceneMode
    property string colorTone
    property string flickerMode
    property string isoSpeed
    property real exposureCompensation: 0
    property int jpegQuality: 0
    property bool hdrEnabled: false
    property bool zslEnabled: false

    property var lastFocusAt: null
    property int resetFocusCount: 0

    signal captureStarted()
    signal controlsChanged()
    signal imageSaved(string path)
    signal imageCaptureError(string message)
    signal videoSaved(string path)
    signal videoCaptureError(string message)

    function cameras() { return []; }
    function createVideoSource(device) { return null; }
    function focusAt(x, y) { lastFocusAt = Qt.point(x, y); }
    function resetFocus() { resetFocusCount++; }
    function startRecording(path, rotation) { recording = true; }
    function stopRecording() { recording = false; }
    function takePicture(path) {}
}
