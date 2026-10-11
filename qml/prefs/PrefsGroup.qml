import QtQuick 2.0

import LunaNext.Common 0.1

/*
 * A group of preference rows in the framework's own frame, captioned or not;
 * from the phone app's PrefsGroup.
 */
Item {
    id: prefsGroup

    default property alias content: rowsColumn.data

    property PrefsTheme theme
    property string title: ""

    readonly property bool labelled: title.length > 0

    /*
     * The artwork's own slices. A labelled group holds thirty-six pixels at
     * the top, of which the last eight are transparent -- so the caption band
     * reads as twenty-eight pixels tall while the rows start below all
     * thirty-six.
     */
    readonly property real artBand: 28
    readonly property real artTop: labelled ? 36 : 14
    readonly property real artSide: 14

    /*
     * The artwork is enyo's, in CSS pixels, where the grid unit is eight; it is
     * drawn at its own size and the whole frame scaled up by the grid unit, as
     * the app does with the rest of the legacy art. Unscaled, the caption band
     * stayed 28 pixels while the text grew with the screen: on the Pixel 3a
     * (25 px grid unit) the caption filled the band. Through Units.gridUnit
     * rather than Units.gu() so it follows if the grid unit changes.
     */
    readonly property real artScale: Units.gridUnit > 0 ? Units.gridUnit / 8 : 1
    readonly property real bandHeight: artBand * artScale
    readonly property real topInset: artTop * artScale
    readonly property real sideInset: artSide * artScale

    implicitHeight: rowsColumn.height + topInset + sideInset
    height: implicitHeight

    BorderImage {
        width: parent.width / prefsGroup.artScale
        height: parent.height / prefsGroup.artScale
        scale: prefsGroup.artScale
        transformOrigin: Item.TopLeft
        smooth: true

        source: prefsGroup.labelled ? "../images/legacy/group-labeled.png"
                                    : "../images/legacy/group-unlabeled.png"
        border {
            left: prefsGroup.artSide; right: prefsGroup.artSide; bottom: prefsGroup.artSide
            top: prefsGroup.artTop
        }
        horizontalTileMode: BorderImage.Repeat
        verticalTileMode: BorderImage.Repeat
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: Units.gu(1.1)
            top: parent.top
        }
        height: prefsGroup.bandHeight
        verticalAlignment: Text.AlignVCenter
        visible: prefsGroup.labelled
        color: prefsGroup.theme.groupLabelColor
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.pixelSize: FontUtils.sizeToPixels("small")
        text: prefsGroup.title
    }

    Column {
        id: rowsColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: prefsGroup.topInset
            leftMargin: Units.gu(0.8)
            rightMargin: Units.gu(0.8)
        }
    }

    /*
     * The rule between one row and the next: .enyo-row's bottom border, a grey
     * line with a lighter one under it. Drawn here rather than by the rows so
     * the last one in a group has none, as the group's own edge closes it off.
     */
    Repeater {
        model: rowsColumn.children.length

        delegate: Item {
            required property int index
            readonly property Item row: rowsColumn.children[index]

            readonly property bool drawable: !!row && row.visible && row.height > 0
            readonly property bool lastDrawable: {
                for (var i = index + 1; i < rowsColumn.children.length; ++i) {
                    var other = rowsColumn.children[i];
                    if (other && other.visible && other.height > 0)
                        return false;
                }
                return true;
            }

            x: rowsColumn.x
            width: rowsColumn.width
            y: rowsColumn.y + (row ? row.y + row.height : 0)
            height: 2
            visible: drawable && !lastDrawable

            Rectangle { width: parent.width; height: 1; color: '#acacac' }
            Rectangle { y: 1; width: parent.width; height: 1; color: '#eaeaea' }
        }
    }
}
