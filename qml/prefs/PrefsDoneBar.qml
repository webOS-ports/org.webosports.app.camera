import QtQuick 2.0

import LunaNext.Common 0.1

/* The bar with the button that closes a preferences scene. */
Rectangle {
    id: doneBar

    property PrefsTheme theme
    property string text: qsTr("Done")

    signal clicked()

    height: Units.gu(6)
    color: theme.footerColor

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: doneBar.theme.rowDividerColor
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Units.gu(4), Units.gu(32))
        height: Units.gu(4)
        radius: Units.gu(0.5)
        color: doneArea.pressed ? Qt.darker(doneBar.theme.doneColor, 1.2) : doneBar.theme.doneColor

        Text {
            anchors.centerIn: parent
            color: 'white'
            /* Through Units.gridUnit: FontUtils scales by the grid unit Units
             * reads when it is first created, and before that it assumes 8 px.
             * Nothing else in this file touches Units before this line, so the
             * label came out at half the size of the rows on the Q25 (14 px
             * against 28). Naming the property creates Units first, and
             * re-evaluates should it change. */
            font.pixelSize: Units.gridUnit > 0 ? FontUtils.sizeToPixels("medium") : 0
            text: doneBar.text
        }

        MouseArea {
            id: doneArea
            anchors.fill: parent
            onClicked: doneBar.clicked()
        }
    }
}
