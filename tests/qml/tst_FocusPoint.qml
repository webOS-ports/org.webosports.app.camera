import QtQuick
import QtTest
import LuneOS.Camera 1.0

import "../../qml"

/*
 * Tap-to-focus: the reticle rests in the middle of the view, and follows it
 * when it changes size, until the user taps somewhere; a reset puts it back.
 */
TestCase {
    name: "FocusPoint"
    width: 720
    height: 1280
    when: windowShown

    PreferencesModel { id: preferences }

    Component {
        id: viewComponent
        CameraView {
            width: 720
            height: 1280
            prefs: preferences
        }
    }

    function init() {
        DroidCameraFactory.available = true;
        DroidCameraFactory.controlsReady = true;
        DroidCameraFactory.focusAreasSupported = true;
    }

    function cleanup() {
        DroidCameraFactory.available = false;
        DroidCameraFactory.controlsReady = false;
        DroidCameraFactory.focusAreasSupported = false;
    }

    function test_rests_in_the_middle() {
        var view = createTemporaryObject(viewComponent, this);
        compare(view.focusPoint, Qt.point(360, 640));
        view.width = 1280;
        view.height = 720;
        compare(view.focusPoint, Qt.point(640, 360));
    }

    function test_stays_where_the_user_tapped() {
        var view = createTemporaryObject(viewComponent, this);
        view.focusAt(100, 200);
        compare(view.focusPoint, Qt.point(100, 200));
        compare(DroidCameraFactory.lastFocusAt, Qt.point(100 / 720, 200 / 1280));
        view.width = 1280;
        view.height = 720;
        compare(view.focusPoint, Qt.point(100, 200));
    }

    function test_a_reset_puts_it_back_in_the_middle() {
        var view = createTemporaryObject(viewComponent, this);
        view.focusAt(100, 200);
        view.resetFocus();
        compare(view.focusPoint, Qt.point(360, 640));
        view.width = 1280;
        view.height = 720;
        compare(view.focusPoint, Qt.point(640, 360));
    }
}
