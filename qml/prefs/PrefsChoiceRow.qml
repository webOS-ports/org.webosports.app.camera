import QtQuick 2.0
import QtQuick.Controls 2.0
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

/*
 * A labelled row choosing one of several values, with a list selector.
 * `values` are what is stored, `labels` what is shown for them.
 */
Item {
    id: row

    property PrefsTheme theme
    property string label: ""
    property var values: []
    property var labels: []
    property var value

    signal chosen(var value)

    width: parent ? parent.width : 0
    height: Units.gu(5)
    // A choice of one is no choice.
    visible: values.length > 1

    Text {
        anchors { left: parent.left; right: selector.left; rightMargin: Units.gu(1); verticalCenter: parent.verticalCenter }
        color: row.theme.textColor
        font.pixelSize: FontUtils.sizeToPixels("medium")
        elide: Text.ElideRight
        text: row.label
    }

    ComboBox {
        id: selector
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(Units.gu(22), row.width / 2)
        model: row.labels
        currentIndex: row.values.indexOf(row.value)
        onActivated: (index) => row.chosen(row.values[index])
    }
}
