import QtQuick
import QtMultimedia
import QtTest
import CameraApp 0.1

import "../../qml"

/*
 * Without the Android camera HAL the flash LED is the video light: it is on
 * for as long as a recording runs with the light switched on, follows the
 * light's button while recording, and is off once the recording stops.
 */
TestCase {
    name: "VideoLight"
    width: 720
    height: 1280
    when: windowShown

    PreferencesModel { id: prefs }

    // No camera on the build host: record the screen instead.
    CaptureSession {
        id: session
        screenCapture: ScreenCapture { active: true }
        recorder: MediaRecorder {}
    }

    CaptureOverlay {
        id: overlay
        anchors.fill: parent
        prefs: prefs
        captureSession: session
    }

    function init() {
        prefs.captureMode = PreferencesModel.CaptureVideo;
        prefs.videoLight = true;
        FlashLed.on = false;
    }

    function cleanup() {
        if (overlay.recording)
            overlay.toggleRecording();
        tryVerify(() => !overlay.recording, 5000);
        prefs.captureMode = PreferencesModel.CaptureStillImage;
        prefs.videoLight = false;
    }

    function startRecording() {
        overlay.toggleRecording();
        tryVerify(() => overlay.recording, 5000, "the recording did not start");
    }

    function stopRecording() {
        overlay.toggleRecording();
        tryVerify(() => !overlay.recording, 5000, "the recording did not stop");
    }

    function test_on_while_recording() {
        startRecording();
        verify(FlashLed.on);
        stopRecording();
        verify(!FlashLed.on);
    }

    function test_stays_off_without_the_light() {
        prefs.videoLight = false;
        startRecording();
        verify(!FlashLed.on);
    }

    function test_follows_the_button_while_recording() {
        startRecording();
        prefs.videoLight = false;
        verify(!FlashLed.on, "switching the light off left the LED on");
        prefs.videoLight = true;
        verify(FlashLed.on, "switching the light on left the LED off");
    }

    function test_off_when_the_recording_ends_by_itself() {
        startRecording();
        session.recorder.stop();
        tryVerify(() => !overlay.recording, 5000);
        verify(!FlashLed.on);
    }
}
