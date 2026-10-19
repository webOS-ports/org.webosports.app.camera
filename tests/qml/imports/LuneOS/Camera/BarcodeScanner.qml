import QtQuick

QtObject {
    property var videoSink
    property bool active
    signal decoded(string text, string format)
}
