import QtQuick 2.9

import LunaNext.Common 0.1

Item {
    property alias prefs: preferencesView.prefs
    property bool menuActive: mouseArea.drag.active

    PreferencesView {
        id: preferencesView
        height: parent.height; width: parent.width

        prefs: preferences

        readonly property real dragDeltaY: touchArea.y - (preferencesView.height/2 - touchArea.height/2)
        arcScroll: (dragDeltaY / (preferencesView.height/2)) * Math.PI/6

        visible: opacity>0 ? true : false
        opacity: 1.0
        scale: 0
        transformOrigin: Item.Left

        state: "hidden"
        states: [
            State {
                name: "hidden"
                PropertyChanges { target: preferencesView; opacity: 0; scale: 0 }
                StateChangeScript { script: preferencesView.resetSelection(); }
            },
            State {
                when: mouseArea.drag.active
                name: "visible"
                PropertyChanges { target: preferencesView; opacity: 1; scale: 1 }
            }
        ]

        Behavior on scale { NumberAnimation { duration: 300 } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    Rectangle {
        id: touchArea
        x: preferencesView.menuXOffset/1.5
        y: parent.height/2 - height/2
        width: preferencesView.menuInnerRadius*2
        height: width
        radius: width/2
        color: "grey"
        opacity: mouseArea.drag.active ? 0 : 0.2
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Drag.active: mouseArea.drag.active
        Drag.hotSpot.x: mouseArea.lastPressedX
        Drag.hotSpot.y: mouseArea.lastPressedY

        MouseArea {
            id: mouseArea
            property real lastPressedX: 0
            property real lastPressedY: 0
            anchors.fill: parent
            drag.target: parent
            onPressed: (mouse) => {
                lastPressedX = mouse.x;
                lastPressedY = mouse.y;
            }
            onReleased: {
                touchArea.Drag.drop();
                touchArea.x = preferencesView.menuXOffset/1.5;
                touchArea.y = preferencesView.height/2 - touchArea.height/2
            }
        }
    }
}
