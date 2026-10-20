import QtQuick

QtObject {
    property bool active
    property var reading: ({ orientation: 0 })
    property string identifier
    property bool connectedToBackend: false
    property int error: 0
}
