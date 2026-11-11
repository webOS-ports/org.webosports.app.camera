import QtQuick
import QtTest
import LuneOS.Camera 1.0
import LuneOS.System 1.0

import "../../qml"

/*
 * The shell's rotationLock preference, which decides a square screen's turn:
 * the locked angle, or 400 when the screen follows the sensor. Anything else
 * in the store is no lock - an int took a false as 0, locked upright.
 */
TestCase {
    name: "RotationLock"
    width: 720
    height: 1280
    when: windowShown && writer.loaded

    PreferencesModel { id: preferences }
    SystemPreferences { id: writer; keys: ["rotationLock"] }

    // One view for the whole case: luneos-components' preference stub kept
    // talking to destroyed ones until "test/imports: preference
    // subscriptions end, rotationLock is an angle".
    CameraView {
        id: view
        width: 720
        height: 1280
        prefs: preferences
    }

    function store(value) {
        verify(writer.set("rotationLock", value));
    }

    function cleanup() {
        store(400);
    }

    function test_an_angle_is_the_lock() {
        store(90);
        tryCompare(view, "shellRotationLock", 90);
        store(0);
        tryCompare(view, "shellRotationLock", 0);
    }

    function test_free_is_no_lock() {
        store(90);
        tryCompare(view, "shellRotationLock", 90);
        store(400);
        tryCompare(view, "shellRotationLock", 400);
    }

    function test_not_a_number_is_no_lock() {
        store(90);
        tryCompare(view, "shellRotationLock", 90);
        store(false);
        tryCompare(view, "shellRotationLock", 400);
    }
}
