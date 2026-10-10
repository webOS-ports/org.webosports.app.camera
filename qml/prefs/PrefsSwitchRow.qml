import QtQuick 2.0
import QtQuick.Controls 2.0
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

/* A labelled on/off row. */
Item {
    id: row

    property PrefsTheme theme
    property string label: ""
    property bool checked: false

    signal toggled(bool on)

    width: parent ? parent.width : 0
    height: Units.gu(5)

    Text {
        anchors { left: parent.left; right: control.left; rightMargin: Units.gu(1); verticalCenter: parent.verticalCenter }
        color: row.theme.textColor
        font.pixelSize: FontUtils.sizeToPixels("medium")
        elide: Text.ElideRight
        text: row.label
    }

    Switch {
        id: control
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: row.checked
        onToggled: row.toggled(control.checked)
    }
}
