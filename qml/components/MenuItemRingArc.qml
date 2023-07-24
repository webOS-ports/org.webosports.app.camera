import QtQuick 2.9
import Qt5Compat.GraphicalEffects

import LunaNext.Common 0.1

import CameraApp 0.1

Item {
    id: root
    property real arcOffset: 0
    property real arcLength: Math.PI/3;
    property real innerRadius: Units.gu(6);
    property real shadowRadius: Units.gu(0.5)

    property Item backgroundImage

    property color gradientMainColor: isSelected ? Qt.rgba(0.42, 0.63, 0.76, 1.0) : Qt.rgba(0.93, 0.93, 0.93, 0.67);

    property ExclusiveGroup group: ExclusiveGroup { currentIndexInGroup: -1 }
    property int indexInGroup: 0
    property bool isSelected: group.currentIndexInGroup === root.indexInGroup
    onIsSelectedChanged: pieSliceTexture.scheduleUpdate();

    property bool interactive: true

    property string text: ""
    property string menuImageUrl: ""

    signal selected
    signal clicked

    Item {
        // draws an arc of the desired arc-length
        id: canvasItem
        anchors.fill: parent

        // rotate the arc to be at the wanted offset
        rotation: root.arcOffset*180/Math.PI
        transformOrigin: Item.Center

        property real outterRadius: canvasItem.width/2-Units.gu(0.5)

        ShaderEffectSource {
            id: pieSliceTexture
            anchors.fill: parent
            sourceItem: backgroundImage
            live: false
        }

        Item {
            x: canvasItem.width/2 + Math.cos(root.arcLength)*root.innerRadius
            y: canvasItem.height/2
            width: canvasItem.outterRadius - Math.cos(root.arcLength)*root.innerRadius
            height: Math.tan(root.arcLength)*root.innerRadius
            rotation: -canvasItem.rotation

            Text {
                visible: root.text !== ""

                anchors.fill: parent
                text: root.text
                font.pixelSize: FontUtils.sizeToPixels("16pt")
                font.family: "Prelude"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Image {
                visible: menuImageUrl !== ""

                height: 0.75*Math.cos(root.arcLength)*Math.min(parent.width, parent.height);
                width: height
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                source: menuImageUrl
            }

            DropArea {
                anchors.fill: parent
                rotation: canvasItem.rotation
                onEntered: {
                    if(root.interactive)
                    {
                        group.currentIndexInGroup = root.indexInGroup;
                        root.selected()
                    }
                }
                onDropped: {
                    if(root.interactive)
                    {
                        root.clicked()
                    }
                }
            }
        }
    }
}
