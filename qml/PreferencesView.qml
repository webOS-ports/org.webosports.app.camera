import QtQuick 2.0
import QtQml.Models 2.2
import QtMultimedia

import LunaNext.Common 0.1

import CameraApp 0.1

import "components"

Item {
    id: root

    property PreferencesModel prefs;
    property var prefsMapping: ({
        "flashMode": [ Camera.FlashAuto, Camera.FlashOff, Camera.FlashOn ],
        "selfTimerDelay": [ 0, 3, 10, 15 ],
        "position": [ Camera.FrontFace, Camera.BackFace ],
        "gridEnabled": [ false, true ],
        "captureMode": [ PreferencesModel.CaptureStillImage, PreferencesModel.CaptureVideo ],
        "photoResolutionIndex": [], // will be filled dynamically
        "videoResolutionIndex": [], // will be filled dynamically
        "effectMode": [ 0, 1, 2, 3 ]
    })

    function resetSelection() {
        exclusiveMainMenu.currentIndexInGroup = -1;
        exclusiveSubMenu.prefsKey = "";
        exclusiveSubMenu.currentIndexInGroup = -1;
        subMenuRepeater.model = null;
    }

    ListModel {
        id: prefsMenuModel
        ListElement { text: "" } // placeholder
        ListElement {
            text: "Flash"
            prefsKey: "flashMode"
            subMenuModel: [
                ListElement { text: "Auto" },
                ListElement { text: "Yes" },
                ListElement { text: "No" }
            ]
        }
        ListElement {
            text: "";
            imageUrl: "images/self_timer.svg"
            prefsKey: "selfTimerDelay"
            subMenuModel: [
                ListElement { text: "None" },
                ListElement { text: "3s"  },
                ListElement { text: "10s" },
                ListElement { text: "15s" }
            ]
        }
        ListElement {
            text: "";
            imageUrl: "images/grid_lines.svg"
            prefsKey: "gridEnabled"
            subMenuModel: [
                ListElement { text: "No" },
                ListElement { text: ""; imageUrl: "images/grid_lines.svg" }
            ]
        }
        ListElement {
            text: "Quality"
            prefsKey: "photoResolutionIndex"
            subMenuModel: [] // will be changed dynamically
        }
        ListElement {
            text: "Effect"
            prefsKey: "effectMode"
            subMenuModel: [
                ListElement { text: "Auto" },
                ListElement { text: "Cloudy" },
                ListElement { text: "B&W" },
                ListElement { text: "Sepia" }
            ]
        }
        ListElement { text: "" } // placeholder
    }

    function videoResolutionToLabel(resolution) {
        // takes in a resolution string (e.g. 1920x1080) and returns a nicer
        // form of it for display in the UI: "1080p"
        return resolution.height + "p";
    }
    function sizeToMegapixels(size) {
        var megapixels = (size.width * size.height) / 1000000;
        return parseFloat(megapixels.toFixed(1))
    }

    Connections {
        target: prefs.captureMode === PreferencesModel.CaptureMode.CaptureStillImage ? prefs.photoResolutionOptionsModel : null
        function onModelChanged() {
            var subMenuModel = []
            var nbPhotoResolutions = prefs.photoResolutionOptionsModel.count;
            var prefsMappingQuality = [];
            for (var i=0; i<nbPhotoResolutions; ++i) {
                subMenuModel.push({ "text": "%1MP".arg(sizeToMegapixels(prefs.photoResolutionOptionsModel.get(i))) });
                prefsMappingQuality.push(i);
            }
            prefsMenuModel.get(4).prefsKey = "photoResolutionIndex";
            prefsMenuModel.get(4).subMenuModel = subMenuModel;
            prefsMapping["photoResolutionIndex"] = prefsMappingQuality;
        }
    }
    Connections {
        target: prefs.captureMode === PreferencesModel.CaptureMode.CaptureVideo ? prefs.videoResolutionOptionsModel : null
        function onModelChanged() {
            var subMenuModel = []
            var nbVideoResolutions = prefs.videoResolutionOptionsModel.count;
            var prefsMappingQuality = [];
            for (var i=0; i<nbVideoResolutions; ++i) {
                subMenuModel.push({ "text": videoResolutionToLabel(prefs.videoResolutionOptionsModel.get(i)) });
                prefsMappingQuality.push(i);
            }
            prefsMenuModel.get(4).prefsKey = "videoResolutionIndex";
            prefsMenuModel.get(4).subMenuModel = subMenuModel;
            prefsMapping["videoResolutionIndex"] = prefsMappingQuality;
        }
    }

    ListView {
        id: subMenuListView
        visible: false
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: root.height*1.1 - root.height/2*1.3 // put it on the right of the carroussel
        width: root.width-x

        boundsBehavior: Flickable.OvershootBounds

        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        preferredHighlightBegin: 0.5 * height - 10
        preferredHighlightEnd: 0.5 * height + 10

        highlight: Rectangle {
            color: Qt.rgba(0,0,0.9,0.2)
        }

        delegate: Text {
                font.pixelSize: 50
                text: model.text
            }
    }


    Column {
        width: parent.width
        spacing: Units.gu(0.5)
        Text {
            text: "Preferences"
            font.pixelSize: Units.gu(4);
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            ExclusiveGroup {
                id: exclusiveGroupSide
                readonly property var prefsMapping: [ CameraDevice.FrontFace, CameraDevice.BackFace ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.position);
                onCurrentIndexInGroupChanged: prefs.position = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: [ "Front", "Back" ]
                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(6)
                    imageSource: ""; text: modelData
                    group: exclusiveGroupSide
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            ExclusiveGroup {
                id: exclusiveGroupTimer
                readonly property var prefsMapping: [ 0, 3, 10, 15 ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.selfTimerDelay);
                onCurrentIndexInGroupChanged: prefs.selfTimerDelay = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: [ "0s", "3s", "10s", "15s" ]
                delegate:  LuneOSButtonElement {
                    height: parent.height
                    width: height
                    imageSource: Qt.resolvedUrl("images/self_timer.svg");
                    group: exclusiveGroupTimer

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        text: modelData
                        font.bold: true
                        font.pixelSize: parent.height*0.3
                    }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            ExclusiveGroup {
                id: exclusiveGroupGrid
                readonly property var prefsMapping: [ false, true ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.gridEnabled);
                onCurrentIndexInGroupChanged: prefs.gridEnabled = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: [ "", Qt.resolvedUrl("images/grid_lines.svg") ]
                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(6)
                    imageSource: modelData; text: modelData === "" ? "None" : ""
                    group: exclusiveGroupGrid
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            ExclusiveGroup {
                id: exclusiveGroupPhotoVideo
                readonly property var prefsMapping: [ PreferencesModel.CaptureMode.CaptureStillImage, PreferencesModel.CaptureMode.CaptureVideo ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.captureMode);
                onCurrentIndexInGroupChanged: prefs.captureMode = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: [ Qt.resolvedUrl("images/shutter_stills@27.png"), Qt.resolvedUrl("images/record_video@27.png") ]
                delegate: LuneOSButtonElement {
                height: parent.height
                    width: parent.height
                    //width: Units.gu(6)
                    //imageSource: ""; text: "Photo"
                    imageSource: modelData
                    group: exclusiveGroupPhotoVideo
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            visible: prefs.captureMode === Camera.CaptureStillImage

            ExclusiveGroup {
                id: exclusiveGroupFlashPhoto
                readonly property var prefsMapping: [ Camera.FlashAuto, Camera.FlashOff, Camera.FlashOn ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.flashMode);
                onCurrentIndexInGroupChanged: prefs.flashMode = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: ListModel {
                    ListElement { width: 6; text: "Auto" }
                    ListElement { width: 9; text: "No Flash" }
                    ListElement { width: 6; text: "Flash" }
                }

                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(model.width)
                    imageSource: ""; text: model.text
                    group: exclusiveGroupFlashPhoto
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            visible: prefs.captureMode === PreferencesModel.CaptureMode.CaptureVideo

            ExclusiveGroup {
                id: exclusiveGroupFlashVideo
                readonly property var prefsMapping: [ Camera.FlashAuto, Camera.FlashOff, Camera.FlashOn ]
                currentIndexInGroup: prefsMapping.indexOf(prefs.videoFlashMode);
                onCurrentIndexInGroupChanged: prefs.videoFlashMode = prefsMapping[currentIndexInGroup]
            }
            Repeater {
                model: ListModel {
                    ListElement { width: 6; text: "Auto" }
                    ListElement { width: 9; text: "No Flash" }
                    ListElement { width: 6; text: "Flash" }
                }

                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(model.width)
                    imageSource: ""; text: model.text
                    group: exclusiveGroupFlashVideo
                }
            }
        }
        Row {
            id: photoOptionsRow
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            visible: prefs.captureMode === PreferencesModel.CaptureMode.CaptureStillImage && prefs.photoResolutionOptionsModel.count>0

            function sizeToMegapixels(size) {
                var megapixels = (size.width * size.height) / 1000000;
                return parseFloat(megapixels.toFixed(1))
            }

            function sizeToAspectRatio(size) {
                var ratio = Math.max(size.width, size.height) / Math.min(size.width, size.height);
                var maxDenominator = 12;
                var epsilon;
                var numerator;
                var denominator;
                var bestDenominator;
                var bestEpsilon = 10000;
                for (denominator = 2; denominator <= maxDenominator; denominator++) {
                    numerator = ratio * denominator;
                    epsilon = Math.abs(Math.round(numerator) - numerator);
                    if (epsilon < bestEpsilon) {
                        bestEpsilon = epsilon;
                        bestDenominator = denominator;
                    }
                }
                numerator = Math.round(ratio * bestDenominator);
                return "%1:%2".arg(numerator).arg(bestDenominator);
            }

            ExclusiveGroup {
                id: exclusiveGroupQuality
                readonly property ListModel prefsMapping: prefs.photoResolutionOptionsModel
                currentIndexInGroup: Math.max(prefsMapping.indexOf(prefs.photoResolution), 0);
                onCurrentIndexInGroupChanged: prefs.setPhotoResolution(prefsMapping.get(currentIndexInGroup).resolution)
            }
            Repeater {
                model: prefs.photoResolutionOptionsModel

                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(9)
                    imageSource: ""; text: "%1 (%2MP)".arg(photoOptionsRow.sizeToAspectRatio(model.resolution))
                                                      .arg(photoOptionsRow.sizeToMegapixels(model.resolution))
                    group: exclusiveGroupQuality
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(6)

            ExclusiveGroup {
                id: exclusiveGroupEffect
                currentIndexInGroup: prefs.effect
                onCurrentIndexInGroupChanged: prefs.effect = currentIndexInGroup
            }
            Repeater {
                model: ListModel {
                    ListElement { width: 6; text: "Auto" }
                    ListElement { width: 7; text: "Sepia" }
                    ListElement { width: 9; text: "Cloudy" }
                }

                delegate: LuneOSButtonElement {
                    height: parent.height
                    width: Units.gu(model.width)
                    imageSource: ""; text: model.text
                    group: exclusiveGroupEffect
                }
            }
        }
    }
}
