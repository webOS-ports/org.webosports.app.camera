import QtQuick

QtObject {
    // What was deleted, newest last; nothing on the disk is touched.
    property var removed: []
    function remove(fileName) {
        removed = removed.concat([fileName]);
        return true;
    }
}
