pragma Singleton
import QtQuick

// The view and the frame are taken to be the same, so a point in the view is
// the same point in the frame.
QtObject {
    function viewToFrame(p, viewSize, frameSize, rotation, mirrored, scale) {
        return Qt.point(p.x / viewSize.width, p.y / viewSize.height);
    }
}
