pragma Singleton
import QtQuick
import QtCore

// Recordings go to the temporary directory run-tests.sh sets up.
QtObject {
    readonly property string picturesLocation: StandardPaths.writableLocation(StandardPaths.TempLocation).toString().replace("file://", "")
    readonly property string videosLocation: picturesLocation
}
