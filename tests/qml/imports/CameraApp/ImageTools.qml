import QtQuick

QtObject {
    id: tools
    signal finished(string path, bool ok, string error)
    // What the last photo was to be done with.
    property var lastOptions: null
    // Done at once, with nothing done to the file.
    function process(path, options) {
        lastOptions = options;
        Qt.callLater(function() { tools.finished(path, true, ""); });
    }
}
