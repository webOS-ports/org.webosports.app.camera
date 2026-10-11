import QtQuick 2.0
import QtQuick.Controls 2.0
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

/* A labelled slider, with its value shown as the slider moves. */
Item {
    id: row

    property PrefsTheme theme
    property string label: ""
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property var format: function(v) { return v.toFixed(1); }

    signal moved(real value)

    width: parent ? parent.width : 0
    height: Units.gu(8)

    Text {
        id: caption
        anchors { left: parent.left; top: parent.top; topMargin: Units.gu(0.8) }
        color: row.theme.textColor
        font.pixelSize: FontUtils.sizeToPixels("medium")
        text: row.label
    }
    Text {
        anchors { right: parent.right; baseline: caption.baseline }
        color: row.theme.secondaryTextColor
        font.pixelSize: FontUtils.sizeToPixels("medium")
        text: row.format(slider.value)
    }

    Slider {
        id: slider
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Units.gu(0.5) }
        from: row.from
        to: row.to
        stepSize: row.stepSize
        value: row.value
        snapMode: Slider.SnapAlways
        onMoved: row.moved(slider.value)
    }
}
